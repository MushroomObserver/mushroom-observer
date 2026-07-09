# frozen_string_literal: true

require("test_helper")
require_relative("inat_import_job_test_doubles")

class InatImportJobTest < ActiveJob::TestCase
  include GeneralExtensions
  include InatImportJobTestDoubles
  include Inat::Constants

  def setup
    super
    @user = users(:inat_importer)
    # Use worker-specific image directories for parallel testing
    setup_image_dirs
    @external_link_base_url = ExternalSite.find_by(name: "iNaturalist").base_url
    return unless job_log_file.exist?

    job_log_file.write("")
  end

  def job_log_file
    # Use worker-specific log file for parallel testing
    if (worker_num = database_worker_number)
      Rails.root.join("log/job-#{worker_num}.log")
    else
      Rails.root.join("log/job.log")
    end
  end

  # Had 1 identification, 0 photos, 0 observation_fields
  def test_import_job_basic_obs
    create_ivars_from_filename("calostoma_lutescens")
    # You can import only your own observations.
    # So adjust importing user's inat_username to be the Inat login
    # of the iNat user who made the iNat observation
    @user.update(inat_username: @inat_import.inat_username)

    # Add objects which are not included in fixtures
    loc = Location.create(user: @user,
                          name: "Sevier Co., Tennessee, USA",
                          north: 36.043571, south: 35.561849,
                          east: -83.253046, west: -83.794123)
    before_total_imported_count = @inat_import.total_imported_count.to_i

    stub_inat_interactions
    assert_difference("Observation.count", 1,
                      "Failed to create observation") do
      InatImportJob.perform_now(@inat_import)
    end

    obs = Observation.last
    name = Name.find_by(text_name: "Calostoma lutescens", rank: "Species")
    assert_equal(loc, obs.location)
    # casual grade, no sequence, no provisional name -> Could Be
    standard_assertions(obs: obs, name: name,
                        expected_vote: Vote::MIN_POS_VOTE)

    # This iNat obs has only 1 suggested ID.
    # The suggester is the person who made the iNat observation.
    proposed_name = obs.namings.first
    used_references = 2
    assert(
      proposed_name.reasons.key?(used_references),
      "Proposed consensus Name reason should be #{:naming_reason_label_2.l}"
    )
    proposed_name_notes = proposed_name[:reasons][used_references]
    suggesting_inat_user = @parsed_results.
                           first[:identifications].first[:user][:login]
    assert_match(:naming_reason_suggested_on_inat.l(user: suggesting_inat_user),
                 proposed_name_notes)
    suggestion_date = @parsed_results.
                      first[:identifications].first[:created_at]
    assert_match(suggestion_date, proposed_name_notes)

    assert_not(obs.specimen, "Obs should not have a specimen")
    assert(obs.notes.to_s.include?("Observation Fields: none"),
           "Notes should indicate if there were no iNat 'Observation Fields'")

    assert(obs.collector.present?, "Import should populate the collector")
    assert_not(obs.notes.key?(:Collector),
               "Collector lives in the column, not notes (#4211)")
    # The iNat collector (here the iNat login) matches the importing user's
    # inat_username, so the collector links to that MO user rather than
    # staying plaintext (#4452 / Joe).
    assert_equal(@user.unique_text_name, obs.collector)
    assert_equal(@user.id, obs.collector_user_id)

    assert_equal(before_total_imported_count + 1,
                 @inat_import.reload.total_imported_count,
                 "Failed to update user's inat_import count")
    assert(@inat_import.total_seconds.to_i.positive?,
           "Failed to update user's inat_import total_seconds")
    assert_equal(
      0, @inat_import.reload.estimated_remaining_time,
      "Estimated remaining time should be 0 when InatImportJob is Done"
    )
  end

  # Regression: a first-time importer has no persisted inat_username when
  # the job starts. The job must persist it BEFORE building observations —
  # collector resolution (match_inat) matches User#inat_username, so a
  # too-late persist left every obs of a first import with an unlinked
  # free-text collector.
  def test_import_first_import_links_collector
    create_ivars_from_filename("calostoma_lutescens")
    assert_nil(@user.inat_username,
               "Test needs a user without a persisted inat_username")

    Location.create(user: @user,
                    name: "Sevier Co., Tennessee, USA",
                    north: 36.043571, south: 35.561849,
                    east: -83.253046, west: -83.794123)

    stub_inat_interactions
    assert_difference("Observation.count", 1,
                      "Failed to create observation") do
      InatImportJob.perform_now(@inat_import)
    end

    assert_equal(@inat_import.inat_username, @user.reload.inat_username,
                 "Username should be persisted during the import")
    link = ExternalLink.find_by(external_id: @parsed_results.first[:id],
                                relationship: "import")
    assert_not_nil(link, "Cannot find import ExternalLink for the new obs")
    obs = link.target
    assert_equal(@user.id, obs.collector_user_id,
                 "A first import should link the collector to the importer")
    assert_equal(@user.unique_text_name, obs.collector)
  end

  # The duplicate gate is any-relationship (#4565): an iNat obs already
  # linked to an MO obs via a non-import link (mirror/copy/etc.) must be
  # skipped, not re-imported as a duplicate.
  def test_import_skips_inat_obs_with_non_import_link
    create_ivars_from_filename("calostoma_lutescens")
    @user.update(inat_username: @inat_import.inat_username)
    ExternalLink.create!(
      user: @user, target: observations(:minimal_unknown_obs),
      external_site: ExternalSite.inaturalist,
      external_id: @parsed_results.first[:id].to_s, relationship: :mirror
    )

    stub_inat_interactions
    assert_no_difference(
      "Observation.count",
      "A mirror-linked iNat obs must not be re-imported"
    ) do
      InatImportJob.perform_now(@inat_import)
    end
    assert_equal(1, @inat_import.reload.ignored_already_imported_count)
  end

  # When the self-heal link fails validation, the obs is still skipped
  # (it IS cross-referenced to a live MO obs) but the job log must report
  # the failure instead of claiming the link was recorded.
  def test_import_crosslink_creation_failure_logged_and_still_skipped
    create_ivars_from_filename("calostoma_lutescens")
    @user.update(inat_username: @inat_import.inat_username)
    mo_obs = observations(:minimal_unknown_obs)
    inject_mo_url_field("https://mushroomobserver.org/#{mo_obs.id}")

    stub_inat_interactions
    raiser = ->(*) { raise(ActiveRecord::RecordInvalid.new(ExternalLink.new)) }
    ExternalLink.stub(:create!, raiser) do
      assert_no_difference(
        "Observation.count",
        "A cross-referenced iNat obs is skipped even when the " \
        "self-heal link fails"
      ) do
        InatImportJob.perform_now(@inat_import)
      end
    end

    assert_nil(
      ExternalLink.find_by(external_id: @parsed_results.first[:id].to_s,
                           relationship: :remote_manual),
      "No link should exist after the stubbed validation failure"
    )
    assert_equal(1, @inat_import.reload.ignored_already_imported_count)
    assert_match(/failed to record the link/, job_log_file.read,
                 "Job log must report the link-creation failure")
  end

  # Self-heal (#4565): an iNat obs whose MO URL field points at a LIVE MO
  # obs that has no link yet gets the missing remote_manual link
  # materialized, and is skipped rather than imported as a duplicate.
  def test_import_materializes_crosslink_to_live_mo_obs
    create_ivars_from_filename("calostoma_lutescens")
    @user.update(inat_username: @inat_import.inat_username)
    mo_obs = observations(:minimal_unknown_obs)
    inject_mo_url_field("https://mushroomobserver.org/#{mo_obs.id}")

    stub_inat_interactions
    assert_no_difference(
      "Observation.count",
      "An iNat obs cross-referenced to a live MO obs must not be imported"
    ) do
      InatImportJob.perform_now(@inat_import)
    end

    link = ExternalLink.find_by(
      external_id: @parsed_results.first[:id].to_s, relationship: :remote_manual
    )
    assert_not_nil(link, "Cannot find the self-healed remote_manual link")
    assert_equal(mo_obs, link.target)
    assert_equal(1, @inat_import.reload.ignored_already_imported_count)
  end

  # A dead MO URL field value (the MO obs was deleted) blocks nothing:
  # the obs is importable again (#4565 orphan reimport). Pins the
  # "DEAD LINK:" annotation form used by the iNat-side cleanup sweep.
  def test_import_imports_inat_obs_with_dead_mo_url_field
    create_ivars_from_filename("calostoma_lutescens")
    @user.update(inat_username: @inat_import.inat_username)
    dead_id = Observation.maximum(:id).to_i + 1_000_000
    inject_mo_url_field("DEAD LINK: https://mushroomobserver.org/#{dead_id}")

    Location.create(user: @user,
                    name: "Sevier Co., Tennessee, USA",
                    north: 36.043571, south: 35.561849,
                    east: -83.253046, west: -83.794123)

    stub_inat_interactions
    assert_difference(
      "Observation.count", 1,
      "An iNat obs whose MO URL points at a deleted MO obs is importable"
    ) do
      InatImportJob.perform_now(@inat_import)
    end
  end

  # Prove (inter alia) that the MO Naming.user differs from the importing user
  # when the iNat user who made the 1st iNat id is another MO user
  def test_import_job_inat_id_suggested_by_another_by_mo_user
    create_ivars_from_filename("calostoma_lutescens")

    user = users(:mary)
    assert(user.inat_username.present?,
           "Test needs user fixture with an inat_username")

    # re-do the ivars to make mary the iNat user who made the 1st iNat id
    parsed_response = JSON.parse(@mock_inat_response, symbolize_names: true)
    parsed_response[:results].first[:identifications].first[:user][:login] =
      user.inat_username
    @mock_inat_response = JSON.generate(parsed_response)
    @parsed_results = parsed_response[:results]
    @inat_import = create_inat_import

    # Add objects which are not included in fixtures
    Location.create(user: user,
                    name: "Sevier Co., Tennessee, USA",
                    north: 36.043571, south: 35.561849,
                    east: -83.253046, west: -83.794123)

    stub_inat_interactions

    assert_difference("Observation.count", 1,
                      "Failed to create observation") do
      InatImportJob.perform_now(@inat_import)
    end

    obs = Observation.last
    proposed_name = obs.namings.first
    assert_equal(user, proposed_name.user,
                 "Name should be proposed by #{user.login}")
    used_references = 2
    assert(
      proposed_name.reasons.key?(used_references),
      "Proposed Name reason should be #{:naming_reason_label_2.l}"
    )
    proposed_name_notes = proposed_name[:reasons][used_references]
    suggesting_inat_user = @parsed_results.
                           first[:identifications].first[:user][:login]
    assert_match(:naming_reason_suggested_on_inat.l(user: suggesting_inat_user),
                 proposed_name_notes)
    suggestion_date = @parsed_results.
                      first[:identifications].first[:created_at]
    assert_match(suggestion_date, proposed_name_notes)
  end

  # Had 1 photo, 1 identification, 0 observation_fields; 0 sequences
  def test_import_job_obs_with_one_photo
    create_ivars_from_filename("evernia")

    # Add objects which are not included in fixtures
    loc = Location.create(
      user: @user,
      name: "Troutdale, Multnomah Co., Oregon, USA",
      north: 45.5609, south: 45.5064,
      east: -122.367, west: -122.431
    )

    stub_inat_interactions

    assert_difference("Observation.count", 1,
                      "Failed to create observation") do
      InatImportJob.perform_now(@inat_import)
    end

    obs = Observation.last
    name = Name.find_by(text_name: "Evernia", rank: "Genus")
    assert_equal(loc, obs.location)
    # needs_id grade, no sequence, no provisional name -> Could Be
    standard_assertions(obs: obs, name: name,
                        expected_vote: Vote::MIN_POS_VOTE)

    inat_photo = @parsed_results.
                 first[:observation_photos].first
    imported_img = obs.images.first
    assert_equal(@user, imported_img.user,
                 "Image should belong to importing user")
    # Structured provenance (#4529/#4299): an import ExternalLink on the
    # image records its source site + the iNat photo id (external_id).
    img_link = imported_img.import_link
    assert_not_nil(img_link, "Imported image should have an import link")
    assert_equal(ExternalSite.inaturalist, img_link.external_site,
                 "Imported image link should record its source site")
    assert_equal(inat_photo[:photo_id].to_s, img_link.external_id,
                 "Imported image link should record the iNat photo id")

    assert(obs.sequences.none?)
  end

  # Had 1 photo; 2 identifications, 1 not by user.
  def test_import_job_obs_with_many_namings
    create_ivars_from_filename("tremella_mesenterica")
    stub_inat_interactions

    assert_difference("Observation.count", 1,
                      "Failed to create observation") do
      InatImportJob.perform_now(@inat_import)
    end

    obs = Observation.last
    name = Name.find_by(text_name: "Tremellales", rank: "Order")
    # needs_id grade, no sequence, no provisional name -> Could Be
    standard_assertions(obs: obs, name: name,
                        expected_vote: Vote::MIN_POS_VOTE)
    assert(obs.sequences.none?)
  end

  def test_import_job_blank_line_in_description
    create_ivars_from_filename("tremella_mesenterica")

    # modify iNat observation description to include multiple blank lines
    parsed_response = JSON.parse(@mock_inat_response, symbolize_names: true)
    description = "before blank lines\r\n\r\n\r\n\r\nafter blank lines"
    parsed_response[:results].first[:description] = description
    @mock_inat_response = parsed_response.to_json

    stub_inat_interactions

    assert_difference("Observation.count", 1,
                      "Failed to create observation") do
      InatImportJob.perform_now(@inat_import)
    end

    obs = Observation.last
    assert_equal(
      "before blank lines\n\nafter blank lines",
      obs.notes[:Other],
      "Failed to collapse multiple blank lines to a single blank line"
    )
  end

  # In development the importer skips the iNat write-back by default, so a
  # local import never annotates a real iNat observation.
  def test_import_skips_inat_writeback_by_default_in_development
    create_ivars_from_filename("tremella_mesenterica")
    stub_inat_interactions

    # Count only this import's requests (see reset_inat_request_log).
    reset_inat_request_log
    Rails.env.stub(:development?, true) do
      InatImportJob.perform_now(@inat_import)
    end

    assert_not_requested(:post, "#{API_BASE}/observation_field_values")
  end

  # Outside development (production, and the WebMock-isolated test env) the
  # importer stamps the MO URL back onto the iNat observation by default.
  def test_import_writes_mo_url_back_to_inat_by_default
    create_ivars_from_filename("tremella_mesenterica")
    stub_inat_interactions

    reset_inat_request_log
    InatImportJob.perform_now(@inat_import)

    assert_requested(:post, "#{API_BASE}/observation_field_values", times: 1)
  end

  # An admin's per-import writeback: :skip forces the write-back off
  # everywhere, overriding the environment default.
  def test_import_writeback_forced_off_by_import_setting
    create_ivars_from_filename("tremella_mesenterica", writeback: :skip)
    stub_inat_interactions

    reset_inat_request_log
    InatImportJob.perform_now(@inat_import)

    assert_not_requested(:post, "#{API_BASE}/observation_field_values")
  end

  # An admin's per-import writeback: :force turns the write-back on,
  # overriding the development default (e.g. to exercise it locally).
  def test_import_writeback_forced_on_overrides_development_default
    create_ivars_from_filename("tremella_mesenterica", writeback: :force)
    stub_inat_interactions

    reset_inat_request_log
    Rails.env.stub(:development?, true) do
      InatImportJob.perform_now(@inat_import)
    end

    assert_requested(:post, "#{API_BASE}/observation_field_values", times: 1)
  end

  # webmock/minitest's per-test reset does not clear the request log between
  # these write-back tests, and assert_(not_)requested reads the cumulative
  # log; clear just the request counter (not the stubs) so each assertion
  # counts only its own import's requests.
  def reset_inat_request_log
    WebMock::RequestRegistry.instance.reset!
  end

  # Had 2 photos, 6 identifications of 3 taxa, a different taxon,
  # 9 obs fields, including "DNA Barcode ITS", "Collection number", "Collector"
  def test_import_job_obs_with_sequence_and_multiple_ids
    create_ivars_from_filename("lycoperdon")
    stub_inat_interactions

    assert_difference("Observation.count", 1,
                      "Failed to create observation") do
      InatImportJob.perform_now(@inat_import)
    end

    obs = Observation.last
    name = Name.find_by(text_name: "Lycoperdon", rank: "Genus")
    standard_assertions(obs: obs, name: name)
    assert_snapshot_suggested_ids(obs)
    assert(obs.sequences.one?, "Obs should have a sequence")
    assert_equal(@user, obs.sequences.first.user,
                 "Sequences should belong to the user who imported the obs")
  end

  # iNat Observation ID is an infrageneric name which was suggested by a user
  def test_import_job_suggested_infrageneric_name
    create_ivars_from_filename("distantes")
    stub_inat_interactions
    # stub the Observation taxon genus lookup
    ancestor_ids = @parsed_results.first[:taxon][:ancestor_ids].join(",")
    stub_genus_lookup(
      ancestor_ids: ancestor_ids,
      body: { results: [{ name: "Morchella" }] }
    )
    # stub the identification taxon genus lookup
    ident = @parsed_results.first[:identifications].first
    ancestor_ids = ident[:taxon][:ancestor_ids].join(",")
    stub_genus_lookup(
      ancestor_ids: ancestor_ids,
      body: { results: [{ name: "Morchella" }] }
    )

    assert_difference("Observation.count", 1,
                      "Failed to create observation") do
      InatImportJob.perform_now(@inat_import)
    end

    obs = Observation.last
    name = Name.find_by(text_name: "Morchella sect. Distantes", rank: "Section")
    # needs_id grade, no sequence, no provisional name -> Could Be
    standard_assertions(obs: obs, name: name,
                        expected_vote: Vote::MIN_POS_VOTE)
    assert_snapshot_suggested_ids(obs)
  end

  # iNat Observation ID is an infrageneric name not suggested by any user
  def test_import_job_unsuggested_infrageneric_name
    create_ivars_from_filename("validae")
    stub_inat_interactions
    ancestor_ids = @parsed_results.first[:taxon][:ancestor_ids].join(",")
    stub_genus_lookup(
      ancestor_ids: ancestor_ids,
      body: { results: [{ name: "Amanita" }] }
    )

    assert_difference("Observation.count", 1,
                      "Failed to create observation") do
      InatImportJob.perform_now(@inat_import)
    end

    obs = Observation.last
    name = Name.find_by(text_name: "Amanita sect. Validae", rank: "Section")
    # needs_id grade, no sequence, no provisional name -> Could Be
    standard_assertions(obs: obs, name: name,
                        expected_vote: Vote::MIN_POS_VOTE)
  end

  def test_import_job_infra_specific_name
    create_ivars_from_filename("i_obliquus_f_sterilis")
    stub_inat_interactions

    assert_difference("Observation.count", 1,
                      "Failed to create observation") do
      InatImportJob.perform_now(@inat_import)
    end

    obs = Observation.last
    name = Name.find_by(text_name: "Inonotus obliquus f. sterilis",
                        rank: "Form")
    # research grade, no sequence, no provisional name -> Promising
    standard_assertions(obs: obs, name: name,
                        expected_vote: Vote::NEXT_BEST_VOTE)
    assert(obs.sequences.none?)
  end

  def test_import_job_complex
    create_ivars_from_filename("xeromphalina_campanella_complex")
    stub_inat_interactions

    assert_difference("Observation.count", 1,
                      "Failed to create observation") do
      InatImportJob.perform_now(@inat_import)
    end

    obs = Observation.last
    name = Name.find_by(text_name: "Xeromphalina campanella complex",
                        rank: "Group")
    # needs_id grade, no sequence, no provisional name -> Could Be
    standard_assertions(obs: obs, name: name,
                        expected_vote: Vote::MIN_POS_VOTE)
    assert(obs.sequences.none?)
  end

  # Prove that Namings, Votes, Identification are correct
  # when iNat obs has provisional name that wasn't in MO
  # `johnplischke` NEMF, DNA, notes, 2 identifications with same id;
  # 3 comments, everyone has MO account;
  # obs fields(include("Voucher Number(s)", "Voucher Specimen Taken"))
  def test_import_job_create_prov_name
    # Guard the iNat input format and the MO output format separately:
    # the input format is what iNat stores; the output is what MO creates.
    # Both guards are needed to prove the job created the name, not fixtures.
    assert_not(Name.exists?(text_name: 'Arrhenia "sp-NY02"'),
               "Test requires that MO not yet have provisional name")
    assert_not(Name.exists?(text_name: "Arrhenia sp. 'NY02'"),
               "Test requires MO not yet have the target provisional name")
    create_ivars_from_filename("arrhenia_sp_NY02")
    stub_inat_interactions

    assert_difference("Observation.count", 1,
                      "Failed to create observation") do
      InatImportJob.perform_now(@inat_import)
    end

    obs = Observation.last
    name = Name.find_by(text_name: "Arrhenia sp. 'NY02'")
    assert(name.present?, "Failed to create provisional name")
    assert(name.rss_log_id.present?,
           "Failed to log creation of provisional name")

    # iNat Community ID + the provisional name (lead) -> two namings.
    standard_assertions(obs: obs, name: name, naming_count: 2)

    proposed_name = obs.namings.first
    assert_equal(@user,
                 proposed_name.user,
                 "Name should be proposed by importing user")
    used_references = 2
    assert(
      proposed_name.reasons.key?(used_references),
      "Proposed Name reason should be #{:naming_reason_label_2.l}"
    )
    proposed_name_notes = proposed_name[:reasons][used_references]
    provisional_field =
      @parsed_results.first[:ofvs].
      find { |field| field[:name] == "Provisional Species Name" }
    adding_inat_user = provisional_field[:user][:login]
    assert_match(:naming_inat_provisional.l(user: adding_inat_user),
                 proposed_name_notes)

    assert(obs.sequences.one?, "Obs should have one sequence")

    expected_subject =
      "#{@user.login} created #{name.real_text_name(@user)}"
    assert_enqueued_with(
      job: ActionMailer::MailDeliveryJob,
      args: lambda { |args|
        args[0] == "WebmasterMailer" && args[1] == "build" &&
          args[3][:args].last[:subject] == expected_subject
      }
    )
  end

  # Prove that a name creation API failure skips the observation and logs the
  # error (rather than crashing on nil.id as it did before this fix).
  def test_import_job_prov_name_creation_failure_skips_observation
    assert_not(Name.exists?(text_name: 'Arrhenia "sp-NY02"'),
               "Test requires that MO not yet have provisional name")
    create_ivars_from_filename("arrhenia_sp_NY02")
    stub_inat_interactions

    # Simulate API2.execute returning errors when creating a Name
    original_execute = API2.method(:execute)
    API2.singleton_class.define_method(:execute) do |params|
      if params[:action] == :name && params[:method] == :post
        api = API2.new(params)
        api.errors << API2::MissingParameter.new(:name)
        api
      else
        original_execute.call(params)
      end
    end

    assert_no_difference("Observation.count",
                         "Should skip observation when name creation fails") do
      InatImportJob.perform_now(@inat_import)
    end

    @inat_import.reload
    assert_match(/Failed to create name/,
                 @inat_import.response_errors,
                 "Should log name creation failure in response_errors")
  ensure
    API2.singleton_class.define_method(:execute, original_execute)
  end

  # Prove that an image upload API failure skips the observation and logs a
  # message identifying both the iNat observation and the failing image
  # (rather than the "undefined method 'paginate' for nil" message that
  # leaked out before this fix, from an unguarded `api.results.first`).
  def test_import_job_image_upload_failure_skips_observation
    create_ivars_from_filename("donadinia_PNW01")
    stub_inat_interactions

    # Simulate API2.execute returning errors when uploading an image.
    original_execute = API2.method(:execute)
    API2.singleton_class.define_method(:execute) do |params|
      if params[:action] == :image && params[:method] == :post
        api = API2.new(params)
        api.errors << API2::MissingParameter.new(:upload_url)
        api
      else
        original_execute.call(params)
      end
    end

    assert_no_difference("Observation.count",
                         "Should skip observation when image upload fails") do
      InatImportJob.perform_now(@inat_import)
    end

    @inat_import.reload
    assert_match(/Failed to import iNat \d+/,
                 @inat_import.response_errors,
                 "Should log which iNat observation failed to import")
    assert_match(/Failed to import image \d+/,
                 @inat_import.response_errors,
                 "Should log which iNat image failed to upload")
  ensure
    API2.singleton_class.define_method(:execute, original_execute)
  end

  # Inat Provisional Species Name "Donadina PNW01" (no: quotes, sp. dash)
  def test_import_job_prov_name_pnw_style
    # NOTE: This observation has no iNat license (all rights reserved).
    # For own-obs imports (default), unlicensed obs are still imported and
    # their unlicensed photos are imported using the user's default MO license.
    assert_not(Name.exists?(Name[:text_name] =~ /Donadinia/),
               "Test requires that MO not yet have `Donadinia` Names")

    create_ivars_from_filename("donadinia_PNW01")
    stub_inat_interactions

    assert_difference("Observation.count", 1,
                      "Failed to create observation") do
      InatImportJob.perform_now(@inat_import)
    end

    obs = Observation.last
    expected_consensus = Name.find_by(text_name: "Donadinia sp. 'PNW01'",
                                      rank: "Species",
                                      user: @user)
    new_names = Name.where(Name[:text_name] =~ /Donadinia/)
    assert(new_names.include?(expected_consensus),
           "Failed to create MO provisional name corresponding to " \
           "iNat `Provisional Species Name` Observation Field")
    assert(new_names.include?(Name.find_by(text_name: "Donadinia",
                                           rank: "Genus",
                                           user: @user)),
           "Failed to create MO genus for new provisional species name")
    assert(new_names.include?(Name.find_by(text_name: "Donadinia nigrella",
                                           rank: "Species",
                                           user: @user)),
           "Failed to create MO species corresponding to iNat suggested ID")
    assert_equal(
      3, new_names.count,
      "It should create only 3 names: provisional, its genus, suggested ID"
    )

    # iNat Community ID + the provisional name (lead) -> two namings.
    standard_assertions(obs: obs, name: expected_consensus, naming_count: 2)

    assert(obs.sequences.one?, "Obs should have one sequence")
  end

  # Own-obs import: unlicensed obs (no iNat license) are still imported, and
  # response_errors includes a summary message counting unlicensed obs.
  def test_job_logs_unlicensed_obs_summary
    create_ivars_from_filename("donadinia_PNW01")
    stub_inat_interactions

    InatImportJob.perform_now(@inat_import)

    @inat_import.reload
    assert_match(
      :inat_unlicensed_obs_summary.t(count: 1),
      @inat_import.response_errors,
      "Should log unlicensed obs summary when import_others=false"
    )
  end

  # Not-own superimporter import: an obs with no iNat license is skipped
  # entirely, not just its images — see ObservationImporter#unlicensed_other?
  def test_job_skips_unlicensed_obs_for_not_own_import
    @user = users(:dick) # Dick is a superimporter
    assert(InatImport.super_importer?(@user),
           "Test requires user to be a super_importer")

    create_ivars_from_filename("donadinia_PNW01")
    @inat_import.update(import_others: true)

    stub_inat_interactions

    assert_no_difference(
      "Observation.count",
      "Unlicensed obs must not be imported for not-own imports"
    ) do
      InatImportJob.perform_now(@inat_import)
    end

    assert_equal(1, @inat_import.reload.ignored_unlicensed_count,
                 "Should count the unlicensed obs as ignored")
  end

  # Not-own superimporter import: a *licensed* obs still imports even when
  # one of its photos individually lacks a license — only that image is
  # skipped (see MoObservationBuilder::ImageHandling), since
  # ObservationImporter#unlicensed_other? only gates on the obs's own
  # license_code, not its photos'.
  def test_job_imports_licensed_obs_skips_unlicensed_image_for_not_own_import
    @user = users(:dick) # Dick is a superimporter
    assert(InatImport.super_importer?(@user),
           "Test requires user to be a super_importer")

    create_ivars_from_filename("agrocybe_arvalis")
    parsed_response = JSON.parse(@mock_inat_response, symbolize_names: true)
    photos = parsed_response[:results].first[:observation_photos]
    assert_operator(photos.length, :>=, 2,
                    "Fixture needs at least 2 photos for this test")
    photos.second[:photo][:license_code] = nil
    @mock_inat_response = JSON.generate(parsed_response)
    @parsed_results = parsed_response[:results]
    @inat_import = create_inat_import(import_others: true)

    stub_inat_interactions

    assert_difference(
      "Observation.count", 1,
      "A licensed obs should still import even with an unlicensed photo"
    ) do
      InatImportJob.perform_now(@inat_import)
    end

    obs = Observation.last
    assert_equal(photos.length - 1, obs.images.length,
                 "Only the licensed photos should be imported")
    assert_equal(0, @inat_import.reload.ignored_unlicensed_count,
                 "A licensed obs must not count as an ignored/unlicensed obs")
    assert_match(
      :inat_skipped_images_summary.t(count: 1),
      @inat_import.response_errors,
      "Should log a summary of the 1 skipped unlicensed image"
    )
  end

  # Inat Prov Species Name "Hygrocybe sp. 'conica-CA06'" (epithet single-quoted)
  def test_import_job_prov_name_ncbi_style
    create_ivars_from_filename("hygrocybe_sp_conica-CA06_ncbi_style")
    stub_inat_interactions
    # stub the identification taxon genus lookup (Subgenus Hygrocybe)
    ident = @parsed_results.first[:identifications].second
    ancestor_ids = ident[:taxon][:ancestor_ids].join(",")
    stub_genus_lookup(
      ancestor_ids: ancestor_ids,
      body: { results: [{ name: "Hygrocybe" }] }
    )

    assert_difference("Observation.count", 1,
                      "Failed to create observation") do
      InatImportJob.perform_now(@inat_import)
    end

    obs = Observation.last

    assert_match(/Hygrocybe sp. 'conica-CA06'/, obs.name.text_name,
                 "Incorrect Name")
  end

  def test_import_plant
    create_ivars_from_filename("ceanothus_cordulatus")

    stub_inat_interactions

    assert_no_difference("Observation.count", "Should not import Plantae") do
      InatImportJob.perform_now(@inat_import)
    end
  end

  def test_unimportable_identification_taxon_not_created
    create_ivars_from_filename("calostoma_lutescens")
    @user.update(inat_username: @inat_import.inat_username)

    # Replace the fungi identification taxon with a plant one
    parsed_response = JSON.parse(@mock_inat_response, symbolize_names: true)
    ident_taxon =
      parsed_response[:results].first[:identifications].first[:taxon]
    ident_taxon[:name] = "Quercus alba"
    # disable cop to facilitate comparing numbers to iNat ids
    ident_taxon[:ancestor_ids] = [48460, 47126, 211194, 47125, 47124, 47132] # rubocop:disable Style/NumericLiterals
    @mock_inat_response = JSON.generate(parsed_response)

    assert_not(Name.exists?(text_name: "Quercus alba"),
               "Test requires 'Quercus alba' to not exist in MO before import")
    stub_inat_interactions

    assert_no_difference(
      "Name.where(text_name: \"Quercus alba\").count",
      "Should not create MO Name for non-fungi identification taxon"
    ) do
      InatImportJob.perform_now(@inat_import)
    end
  end

  def test_import_zero_results
    create_ivars_from_filename("zero_results")
    @inat_import.update(inat_ids: "123", token: "MockCode")
    stub_inat_interactions

    assert_no_difference(
      "Observation.count",
      "Should import nothing if no iNat obss match the user's list of id's"
    ) do
      InatImportJob.perform_now(@inat_import)
    end
  end

  # Prove (inter alia) that the MO Naming.user differs from the importing user
  # when the iNat user who made the 1st iNat id is another MO user
  def test_import_observed_date_missing
    create_ivars_from_filename("calostoma_lutescens")

    user = users(:mary)
    assert(user.inat_username.present?,
           "Test needs user fixture with an inat_username")

    # re-do the ivars to make mary the iNat user who made the 1st iNat id
    parsed_response = JSON.parse(@mock_inat_response, symbolize_names: true)
    parsed_response[:results].first[:identifications].
      first[:user][:login] = user.inat_username
    # Remove all observed_on... key/values to simulate Observed date missing
    parsed_response[:results].first.
      keys.select { |k| k.start_with?("observed_on") }.
      each { |k| parsed_response[:results].first.delete(k) }
    @mock_inat_response = JSON.generate(parsed_response)
    @parsed_results = parsed_response[:results]
    @inat_import = create_inat_import

    stub_inat_interactions

    assert_difference(
      "Observation.count", 0,
      "It should not create an Observation if iNat Observed Date Missing"
    ) do
      InatImportJob.perform_now(@inat_import)
    end
    assert_match(:inat_observed_missing_date.l, @inat_import.response_errors,
                 "It should warn if the iNat Observed Date is missing")
  end

  # When the back-link write to iNat fails (the field that the iNat-side
  # `without_field` filter relies on to dedup future imports), the MO obs
  # must be destroyed — otherwise the next import has no protection and
  # creates a duplicate. Regression coverage for Gap A in #4221.
  def test_import_destroys_mo_obs_when_inat_back_link_write_fails
    create_ivars_from_filename("calostoma_lutescens")
    @user.update(inat_username: @inat_import.inat_username)

    Location.create(user: @user,
                    name: "Sevier Co., Tennessee, USA",
                    north: 36.043571, south: 35.561849,
                    east: -83.253046, west: -83.794123)

    stub_inat_interactions
    # Override the back-link write stub to return 500.
    stub_request(:post, "#{API_BASE}/observation_field_values").
      to_return(status: 500,
                body: { error: "iNat is down" }.to_json,
                headers: { "Content-Type" => "application/json" })

    assert_no_difference(
      "Observation.count",
      "MO obs must not survive a failed iNat back-link write"
    ) do
      InatImportJob.perform_now(@inat_import)
    end
  end

  # Belt-and-suspenders dedup against the four import-flow gaps in #4221:
  # iNat-side `without_field` filter only excludes obs that already had a
  # back-link write succeed; the controller-side `clean_inat_ids` is bypassed
  # on import-all; and races between simultaneous jobs slip past both. The
  # in-job `already_imported?` check catches all of these before the insert.
  def test_import_skips_already_imported_inat_obs
    create_ivars_from_filename("calostoma_lutescens")
    @user.update(inat_username: @inat_import.inat_username)

    inat_id = @parsed_results.first[:id]
    site = ExternalSite.inaturalist
    obs = Observation.create!(
      user: @user, when: Time.zone.today, where: "Earth",
      name: Name.unknown
    )
    ExternalLink.create!(
      user: @user, observation: obs, external_site: site,
      relationship: :import, external_id: inat_id.to_s,
      url: "#{site.base_url}#{inat_id}"
    )

    stub_inat_interactions

    assert_no_difference(
      "Observation.count",
      "Should skip iNat obs already present in MO"
    ) do
      InatImportJob.perform_now(@inat_import)
    end

    assert_match(/Skipped #{inat_id} already linked/, job_log_file.read,
                 "Should log a skip message when the obs is already imported")
  end

  # If a simultaneous import job inserts the same iNat obs between
  # already_imported? and Observation.create, RecordNotUnique is raised
  # (the import ExternalLink's unique index). The importer should swallow
  # it and log a "race" skip — same effect as the already_imported?
  # pre-check.
  def test_import_handles_record_not_unique_race
    create_ivars_from_filename("calostoma_lutescens")
    @user.update(inat_username: @inat_import.inat_username)
    Location.create(user: @user,
                    name: "Sevier Co., Tennessee, USA",
                    north: 36.043571, south: 35.561849,
                    east: -83.253046, west: -83.794123)

    stub_inat_interactions

    inat_id = @parsed_results.first[:id]
    Observation.stub(:create, ->(*) { raise(ActiveRecord::RecordNotUnique) }) do
      assert_no_difference(
        "Observation.count",
        "RecordNotUnique race must not leak a partial obs"
      ) do
        InatImportJob.perform_now(@inat_import)
      end
    end

    assert_match(/Skipped #{inat_id} already imported \(race\)/,
                 job_log_file.read,
                 "Should log a race-skip when RecordNotUnique fires")
  end

  def test_import_update_inat_username_if_job_succeeds
    updated_inat_username = "updatedInatUsername"

    create_ivars_from_filename(
      "zero_results",
      # simulate entering new inat_username in iNat import form
      inat_username: updated_inat_username,
      # Supply an iNat id so that the Job runs. But it's an id
      # which doesn't belong to the user, and therefore won't be imported.
      inat_ids: "123"
    )

    stub_inat_interactions
    InatImportJob.perform_now(@inat_import)

    assert_equal(
      updated_inat_username, @user.reload.inat_username,
      "Failed to update User's inat_username after successful import"
    )
  end

  def test_import_multiple
    create_ivars_from_filename("listed_ids")

    first_id = @parsed_results.first[:id]
    last_id = @parsed_results.last[:id]

    # override ivar because this test wants to import multiple observations
    @inat_import = InatImport.create(user: @user,
                                     inat_ids: "#{last_id},#{first_id}",
                                     token: "MockCode",
                                     inat_username: "anything")
    # update the tracker's inat_import accordingly
    stub_inat_interactions

    assert_difference("Observation.count", 2,
                      "Failed to create multiple observations") do
      InatImportJob.perform_now(@inat_import)
    end
    # Assert that the job logged the parsed page with iNat observation IDs
    log_content = job_log_file.read
    assert_match(
      /Got parsed page with iNat #{first_id}-#{last_id}/, log_content,
      "Log missing parsed page message with iNat 1st and last observation IDs"
    )
    assert_match(/Imported iNat #{first_id} as MO \d+/, log_content,
                 "Failed to log importing of iNat #{first_id}")
    assert_match(/Imported iNat #{last_id} as MO \d+/, log_content,
                 "Failed to log importing of iNat #{last_id}")
  end

  # Prove that import continues with subsequent observations
  # when an error occurs during import of one observation
  def test_import_multiple_continues_after_error
    create_ivars_from_filename("listed_ids")

    first_id = @parsed_results.first[:id]
    last_id = @parsed_results.last[:id]

    # override ivar because this test wants to import multiple observations
    @inat_import = create_inat_import(inat_ids: "#{first_id},#{last_id}",
                                      inat_username: "anything")
    # update the tracker's inat_import accordingly

    stub_inat_interactions
    # Claude's suggestion for stubbing a method to raise an error during the
    # first import but not the second
    # Stub Inat::Obs#notes to raise an error for the first observation only
    # This method is called during MoObservationBuilder,
    # which has error handling
    original_notes_method = Inat::Obs.instance_method(:notes)
    Inat::Obs.class_eval do
      define_method(:notes) do
        if self[:id] == first_id
          raise(StandardError.new("Simulated error in Inat::Obs#notes"))
        end

        original_notes_method.bind_call(self)
      end
    end

    # The import should create only the second observation (last_id)
    # because the first one (first_id) will fail
    assert_difference("Observation.count", 1,
                      "Should still create the second observation") do
      InatImportJob.perform_now(@inat_import)
    end

    # Assert that the job logged the error for the first observation
    @inat_import.reload
    assert_match(/Simulated error in Inat::Obs#notes/,
                 @inat_import.response_errors,
                 "Failed to log error for first observation")

    # Assert that the second observation was still imported
    log_content = job_log_file.read
    assert_match(/Imported iNat #{last_id} as MO \d+/, log_content,
                 "Failed to import second observation after error in first")

    # Clean up the stubbed method - restore original
    Inat::Obs.class_eval do
      define_method(:notes, original_notes_method)
    end
  end

  # Prove that "Import all my iNat observations imports" multiple obsservations
  # NOTE: It would be complicated to prove that it imports multiple pages.
  def test_import_all
    file_name = "import_all"
    mock_inat_response = File.read("test/inat/#{file_name}.txt")
    @inat_import = InatImport.create(user: @user,
                                     inat_ids: "",
                                     import_all: true,
                                     token: "MockCode",
                                     inat_username: "anything")
    # limit it to one page to avoid complications of stubbing multiple
    # inat api requests with multiple files
    @mock_inat_response = limited_to_first_page(mock_inat_response)
    @parsed_results =
      JSON.parse(@mock_inat_response, symbolize_names: true)[:results]

    stub_inat_interactions

    assert_difference("Observation.count", 2,
                      "Failed to create multiple observations") do
      InatImportJob.perform_now(@inat_import)
    end
  end

  # With id_above cursor pagination, iNat's total_results is the count of
  # observations remaining from the current cursor position forward — it
  # shrinks with each page. importables must be set once from the first
  # page so the tracker always shows the full job total, not the tail.
  def test_importables_set_from_first_page_only
    raw = File.read("test/inat/import_all.txt")
    page1 = JSON.parse(raw)
    last_first_page_id = page1["results"].last["id"]

    first_page_total = 250
    page1["total_results"] = first_page_total
    @mock_inat_response = page1.to_json
    @parsed_results =
      JSON.parse(@mock_inat_response, symbolize_names: true)[:results]

    @inat_import = InatImport.create(
      user: @user, inat_ids: "", import_all: true,
      token: "MockCode", inat_username: "anything", imported_count: 0
    )

    stub_token_requests
    stub_check_username_match(@inat_import.inat_username)
    # Page 1: total_results = 250, per_page = 2 → more_pages? is true
    stub_inat_observation_request(id_above: 0)
    # Page 2: total_results = 2 ≤ per_page → more_pages? is false (stop)
    second_page_query = {
      taxon_id: IMPORTABLE_TAXON_IDS_ARG,
      id: @inat_import.inat_ids,
      id_above: last_first_page_id,
      per_page: InatImportJob::BATCH_SIZE,
      only_id: false,
      order: "asc",
      order_by: "id",
      **BASE_FILTER_PARAMS,
      user_login: @inat_import.inat_username
    }
    stub_request(:get,
                 "#{API_BASE}/observations?#{second_page_query.to_query}").
      to_return(body: page1.merge("total_results" => 2).to_json)
    stub_inat_photo_requests
    stub_modify_inat_observations

    InatImportJob.perform_now(@inat_import)

    assert_equal(
      first_page_total, @inat_import.reload.importables,
      "importables should be set from the first page total_results " \
      "(#{first_page_total}) and not overwritten by subsequent pages"
    )
  end

  def test_import_anothers_observation
    create_ivars_from_filename("calostoma_lutescens")

    inat_logged_in_user = "WrongUser"
    stub_inat_interactions(login: inat_logged_in_user)

    assert_difference("Observation.count", 0,
                      "It should not import another user's observation") do
      InatImportJob.perform_now(@inat_import)
    end

    expect = :inat_wrong_user.l(inat_username: @inat_import.inat_username,
                                inat_logged_in_user: inat_logged_in_user)
    assert_includes(
      @inat_import.response_errors, expect,
      "It should warn if a user tries to import another's iNat obs"
    )
    assert_nil(@user.reload.inat_username,
               "A username that failed the own-obs verification " \
               "must not be persisted")
  end

  def test_super_importer_anothers_observation
    @user = users(:dick)
    inat_username = @user.inat_username
    assert(InatImport.super_importers.include?(@user),
           "Test needs User fixture that's SuperImporter")

    create_ivars_from_filename("calostoma_lutescens")
    stub_inat_interactions

    assert_difference(
      "Observation.count", 1,
      "'super_importer' failed to import another user's observation"
    ) do
      InatImportJob.perform_now(@inat_import)
    end

    assert_empty(@inat_import.response_errors, "There should be no errors")
    assert_equal(inat_username, @user.reload.inat_username,
                 "SuperImporter's inat_username should not change")
  end

  def test_super_importer_all_inat_fungal_observations
    @user = users(:dick)

    file_name = "import_all"
    mock_inat_response = File.read("test/inat/#{file_name}.txt")
    @inat_import = InatImport.create(user: @user,
                                     inat_ids: "",
                                     import_all: true,
                                     token: "MockCode",
                                     inat_username: @user.inat_username)
    # limit it to one page to avoid complications of stubbing multiple
    # inat api requests with multiple files
    @mock_inat_response = limited_to_first_page(mock_inat_response)
    @parsed_results =
      JSON.parse(@mock_inat_response, symbolize_names: true)[:results]

    stub_inat_interactions
    stub_inat_observation_request(id_above: 0, body_nil: true)

    assert_difference(
      "Observation.count", 0,
      "Superimporter should not import all iNat fungal observations " \
      "by all users"
    ) do
      InatImportJob.perform_now(@inat_import)
    end
  end

  def test_url_mode_reaches_page_parser
    # Regression: the guard `blank? && inat_ids.blank?` used to bail before
    # the PageParser in URL mode, since URL imports have neither import_all
    # nor inat_ids set.
    @user = users(:dick)
    inat_import = InatImport.find_or_create_by(user: @user)
    inat_import.update(
      state: "Authorizing",
      inat_url: "place_id=1",
      inat_ids: "",
      import_all: false,
      import_others: true,
      inat_username: @user.inat_username,
      token: "MockCode",
      importables: nil,
      imported_count: 0,
      avg_import_time: InatImport::BASE_AVG_IMPORT_SECONDS,
      response_errors: "",
      log: [],
      last_obs_start: Time.now.utc,
      ended_at: nil
    )

    stub_token_requests
    stub_check_username_match(@user.inat_username)
    obs_stub = stub_request(:get, %r{api\.inaturalist\.org/v1/observations}).
               to_return(status: 200,
                         body: { total_results: 0, results: [] }.to_json)

    WebMock.reset_executed_requests!
    InatImportJob.perform_now(inat_import)

    assert_requested(obs_stub)
  end

  def test_import_canceled
    create_ivars_from_filename("listed_ids") # importing multiple observations
    # override ivar because this test wants to import multiple observations
    @inat_import = InatImport.create(user: @user,
                                     inat_ids: "231104466,195434438",
                                     token: "MockCode",
                                     inat_username: "anything")
    # update the tracker's inat_import accordingly
    @inat_import.update(canceled: true) # simulate cancellation
    stub_inat_interactions

    assert_no_difference(
      "Observation.count",
      "It should not import observations after cancellation"
    ) do
      InatImportJob.perform_now(@inat_import)
    end

    assert_equal("Done", @inat_import.state,
                 "Import should be Done")
    assert(@inat_import.canceled?,
           "Import should remain canceled")
  end

  def test_oauth_failure
    create_ivars_from_filename("calostoma_lutescens")

    oauth_return = { status: 401, body: "Unauthorized",
                     headers: { "Content-Type" => "application/json" } }
    stub_oauth_token_request(oauth_return: oauth_return)

    InatImportJob.perform_now(@inat_import)

    assert_match(/401 Unauthorized/, @inat_import.response_errors,
                 "Failed to report OAuth failure")
  end

  def test_jwt_failure
    create_ivars_from_filename("calostoma_lutescens")

    stub_oauth_token_request
    jwt_return = { status: 401, body: "Unauthorized",
                   headers: { "Content-Type" => "application/json" } }
    stub_jwt_request(jwt_return: jwt_return)

    InatImportJob.perform_now(@inat_import)

    assert_match(/401 Unauthorized/, @inat_import.response_errors,
                 "Failed to report OAuth failure")
  end

  def test_inat_api_request_user_failure
    create_ivars_from_filename("calostoma_lutescens")

    stub_token_requests
    stub_request(:get, "#{API_BASE}/users/me").
      with(
        headers: {
          "Accept" => "application/json",
          "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
          "Authorization" => "Bearer MockJWT",
          "Content-Type" => "application/json",
          "Host" => "api.inaturalist.org"
        }
      ).
      to_return(status: 401,
                body: JSON.generate({ error: "Unauthorized", status: 401 }),
                headers: {})

    InatImportJob.perform_now(@inat_import)

    assert_match(/401 Unauthorized/, @inat_import.response_errors,
                 "Failed to report iNat API request failure")
  end

  def test_inat_api_request_observation_response_error
    create_ivars_from_filename("calostoma_lutescens")

    stub_inat_interactions
    # override the normal iNat API observation request to return an error
    query_args = {
      taxon_id: IMPORTABLE_TAXON_IDS_ARG,
      id: @inat_import.inat_ids,
      id_above: 0,
      per_page: InatImportJob::BATCH_SIZE,
      only_id: false,
      order: "asc",
      order_by: "id",
      # no without_field: id-list imports always re-check (#4565)
      user_login: @inat_import.inat_username
    }
    error = "Unauthorized"
    status = 401
    stub_request(:get, "#{API_BASE}/observations?#{query_args.to_query}").
      with(headers:
    { "Accept" => "application/json",
      "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
      "Authorization" => "Bearer MockJWT",
      "Host" => "api.inaturalist.org" }).
      to_return(status: status,
                body: JSON.generate({ error: error, status: status }),
                headers: {})

    InatImportJob.perform_now(@inat_import)

    errors = JSON.parse(@inat_import.response_errors, symbolize_names: true)
    assert_equal(status, errors[:error], "Incorrect error status")
    query = JSON.parse(errors[:query], symbolize_names: true)
    assert_equal(query_args, query, "Incorrect error query")
  end

  def test_inat_api_request_post_observation_field_response_error
    create_ivars_from_filename("calostoma_lutescens")

    stub_inat_interactions
    # override the normal post of the iNat Observation Field to return an error
    error = "Unauthorized"
    status = 401
    stub_request(:post, "#{API_BASE}/observation_field_values").
      with(headers: { "Content-Type" => "application/json" }).
      to_return(status: status,
                body: JSON.generate({ error: error, status: status }),
                headers: {})

    # Save the observation count before the job runs
    obs_count_before = Observation.count

    InatImportJob.perform_now(@inat_import)

    # The observation should have been destroyed after the error
    assert_equal(obs_count_before, Observation.count,
                 "MO Observation should be destroyed after iNat API error")

    http_error_line = @inat_import.response_errors.lines.first
    errors = JSON.parse(http_error_line, symbolize_names: true)
    assert_equal(status, errors[:error], "Incorrect error status")
    assert_match(/Failed to finalize import of iNat/,
                 @inat_import.response_errors,
                 "Should also log finalize failure context")

    # The payload should contain the observation_field_value details
    payload = errors[:payload]
    assert_kind_of(Hash, payload, "Error payload should be a hash")
    assert_equal(@inat_import.inat_ids.to_i,
                 payload[:observation_field_value][:observation_id],
                 "Incorrect observation_id in error payload")
    assert_equal(MO_URL_OBSERVATION_FIELD_ID,
                 payload[:observation_field_value][:observation_field_id],
                 "Incorrect observation_field_id in error payload")

    log_content = job_log_file.read
    assert_no_match(/Imported iNat #{@parsed_results.first[:id]}/,
                    log_content,
                    "Should not log import success when error occurs")
  end

  # Prove that the import continues (observation created, warning logged)
  # when ExternalLink creation fails with RecordInvalid.
  # Covers MoObservationBuilder#add_external_link rescue block.
  def test_import_job_external_link_creation_failure
    create_ivars_from_filename("calostoma_lutescens")
    @user.update(inat_username: @inat_import.inat_username)
    Location.create(user: @user, name: "Sevier Co., Tennessee, USA",
                    north: 36.043571, south: 35.561849,
                    east: -83.253046, west: -83.794123)
    stub_inat_interactions

    warnings = []
    stubbed_error = lambda do |*|
      link = ExternalLink.new
      link.errors.add(:base, "stubbed failure")
      raise(ActiveRecord::RecordInvalid.new(link))
    end
    Rails.logger.stub(:warn, ->(msg) { warnings << msg }) do
      ExternalLink.stub(:create!, stubbed_error) do
        assert_difference("Observation.count", 1,
                          "Observation should be created even if " \
                          "ExternalLink.create! fails") do
          InatImportJob.perform_now(@inat_import)
        end
      end
    end

    inat_id = @parsed_results.first[:id]
    name = Name.find_by(text_name: "Calostoma lutescens", rank: "Species")
    obs = Observation.find_by(user: @user, name: name)
    assert_not_nil(obs, "Cannot find imported Observation")
    assert(obs.external_links.none?,
           "Observation should have no ExternalLink when creation fails")
    assert(
      warnings.any? do |w|
        w.include?("InatImport: failed to create ExternalLink") &&
          w.include?(inat_id.to_s)
      end,
      "Should log a warning including the iNat obs ID when ExternalLink fails"
    )
  end

  ########## Utilities

  ########## Utilities

  def create_ivars_from_filename(filename, **attrs)
    @mock_inat_response = File.read("test/inat/#{filename}.txt")
    @parsed_results =
      JSON.parse(@mock_inat_response, symbolize_names: true)[:results]

    @inat_import = create_inat_import(**attrs)
  end

  # Add a "Mushroom Observer URL" observation field (5005) to the mocked
  # iNat response. Call after create_ivars_from_filename, before stubbing.
  def inject_mo_url_field(value)
    parsed = JSON.parse(@mock_inat_response, symbolize_names: true)
    parsed[:results].first[:ofvs] << {
      field_id: MO_URL_OBSERVATION_FIELD_ID,
      name: "Mushroom Observer URL",
      value: value
    }
    @mock_inat_response = JSON.generate(parsed)
    @parsed_results = parsed[:results]
  end

  # On the app side, the Job is created by InatImportsController#create,
  # which first finds or creates an InatImport instance.
  # Because this test is not run in the context of a controller,
  # we need to create the InatImport instance manually.
  def create_inat_import(**attrs)
    import = InatImport.find_or_create_by(user: @user)
    default_attrs = {
      state: "Authorizing",
      inat_ids: @parsed_results.first&.dig(:id),
      inat_username: @parsed_results.first&.dig(:user, :login),
      importables: @parsed_results.length,
      imported_count: 0,
      avg_import_time: InatImport::BASE_AVG_IMPORT_SECONDS,
      response_errors: "",
      token: "MockCode",
      log: [],
      last_obs_start: Time.now.utc,
      ended_at: nil
    }
    import.update(default_attrs.merge(attrs))
    import
  end

  # -------- Standard Test assertions

  def standard_assertions(obs:, user: @user, name: nil,
                          expected_vote: Vote::MAXIMUM_VOTE, naming_count: 1)
    assert_not_nil(obs.rss_log, "Failed to log Observation")
    assert_nil(obs.source, "Imported obs should have no entry-agent source")
    import_link = obs.import_link
    assert_not_nil(import_link,
                   "Imported obs should have an import ExternalLink")
    assert_equal(ExternalSite.inaturalist, import_link.external_site,
                 "Import link should point to the iNaturalist site")

    expected_photo_count = expected_imported_photo_count
    assert_equal(expected_photo_count, obs.images.length,
                 "Observation should have #{expected_photo_count} image(s)")

    assert_equal(naming_count, obs.namings.length,
                 "iNatImport created the wrong number of Namings")
    obs.namings.each do |naming|
      assert_not(
        naming.vote_cache.zero?,
        "VoteCache for Proposed Name '#{naming.name.text_name}' incorrect"
      )
    end

    assert_equal(name, obs.name, "Wrong consensus id")

    namings = obs.namings
    naming = namings.find_by(name: name)
    assert(naming.present?, "Missing Naming for MO consensus ID")
    assert_equal(
      user, naming.user,
      "Consensus Naming for this MO obs should be by #{user.login}"
    )
    vote = Vote.find_by(naming: naming, user: naming.user)
    assert(vote.present?, "Naming is missing a Vote")
    assert_equal(expected_vote, vote.value,
                 "Vote for MO consensus has the wrong confidence weight")

    view = ObservationView.
           find_by(observation_id: obs.id, user_id: user.id)
    assert(view.present?, "Failed to create ObservationView")

    assert_equal(
      "#{@external_link_base_url}#{@parsed_results.first[:id]}",
      import_link.link_url,
      "MO Observation should have ExternalLink to iNat observation"
    )
    assert_equal(@parsed_results.first[:id].to_s, import_link.external_id,
                 "Import link should carry the iNat observation id")

    snapshot_key = Observation.notes_normalized_key(:inat_snapshot_caption.l)
    assert_empty(
      obs.comments.where(Comment[:summary] =~ snapshot_key.to_s),
      "Observation should not have a (#{:inat_snapshot_caption.l}) comment"
    )

    ### Observation Notes
    assert(obs.notes.key?(snapshot_key),
           "Observation Notes missing #{snapshot_key}")
    [
      :USER.l, :OBSERVED.l, :show_observation_inat_lat_lng.l, :PLACE.l,
      :ID.l, :DQA.l, :show_observation_inat_suggested_ids.l,
      :OBSERVATION_FIELDS.l
    ].each do |caption|
      assert_match(
        /#{caption}/, obs.notes.to_s,
        "Observation notes are missing #{caption}"
      )
    end
  end

  # For own-obs imports (default), all photos are imported (unlicensed ones
  # use the user's default license). For not-own superimporter imports, only
  # licensed photos are imported.
  def expected_imported_photo_count
    obs_photos = @parsed_results.first[:observation_photos]
    return obs_photos.length unless @inat_import.import_others

    obs_photos.count { |p| p[:photo][:license_code].present? }
  end

  def assert_naming(obs:, name:, user:)
    namings = obs.namings
    naming = namings.find_by(name: name)
    assert(naming.present?, "Naming for MO consensus ID")
    assert_equal(user, naming.user,
                 "Naming should belong to #{user.login}")
  end

  def assert_snapshot_suggested_ids(obs)
    idents = @parsed_results.first[:identifications]
    # Get the display name for each suggested iNat id.
    # Matches what obs.rb uses in the snapshot: MO text_name if found, else
    # the raw iNat taxon name.
    suggested_display_names = idents.each_with_object([]) do |ident, ary|
      ident_taxon = ::Inat::Taxon.new(ident[:taxon])
      ary << (ident_taxon.name&.text_name || ident[:taxon][:name])
    end
    suggested_display_names.each do |name_text|
      assert_match(name_text, obs.notes.to_s,
                   "Notes Snapshot missing suggested name #{name_text}")
    end
  end

  # -------- rescue Exception / non_rescuable? tests

  def test_perform_records_unexpected_non_standard_exception
    create_ivars_from_filename("calostoma_lutescens")
    stub_token_requests
    stub_check_username_match(@inat_import.inat_username)

    job = InatImportJob.new
    job.define_singleton_method(:import_requested_observations) do |**|
      raise(Exception.new("unexpected bare exception")) # rubocop:disable Lint/RaiseException
    end

    job.perform(@inat_import)

    @inat_import.reload
    assert_match(/unexpected bare exception/, @inat_import.response_errors,
                 "Non-fatal Exception should be recorded in response_errors")
    assert_equal("Done", @inat_import.state,
                 "Import should be marked Done after unexpected exception")
  end

  def test_non_rescuable_true_for_remaining_fatal_types
    job = InatImportJob.new

    [NoMemoryError.new, SystemStackError.new, LoadError.new].each do |error|
      assert(job.send(:non_rescuable?, error),
             "#{error.class} should be non_rescuable")
    end
  end

  # -------- safe_done tests

  def test_safe_done_marks_import_done_normally
    create_ivars_from_filename("calostoma_lutescens")
    @user.update(inat_username: @inat_import.inat_username)
    stub_inat_interactions

    InatImportJob.perform_now(@inat_import)

    assert_equal("Done", @inat_import.reload.state,
                 "Import should be Done after successful job")
    assert_not_nil(@inat_import.ended_at,
                   "ended_at should be set after successful job")
  end

  def test_safe_done_reraises_when_done_fails_on_happy_path
    job = InatImportJob.new
    job.instance_variable_set(:@inat_import, @inat_import)
    job.define_singleton_method(:done) do
      raise(StandardError.new("done failed"))
    end

    exception = nil
    Rails.logger.stub(:error, nil) do
      job.send(:safe_done)
    rescue StandardError => e
      exception = e
    end
    assert_not_nil(exception,
                   "safe_done should re-raise when done fails with no " \
                   "original exception in flight")
  end

  def test_safe_done_swallows_done_failure_when_handling_error
    job = InatImportJob.new
    job.instance_variable_set(:@inat_import, @inat_import)
    job.define_singleton_method(:done) do
      raise(StandardError.new("done failed"))
    end

    swallowed = true
    Rails.logger.stub(:error, nil) do
      raise(StandardError.new("original error"))
    rescue StandardError
      begin
        job.send(:safe_done)
      rescue StandardError
        swallowed = false
      end
    end
    assert(swallowed,
           "safe_done should swallow done's exception when an error " \
           "is already in flight")
  end

  # -------- Batch job tests
  # Continuation jobs skip authenticate and ensure_not_importing_others.
  # token: "MockJWT" represents the state after the first job already ran
  # authenticate (OAuth code → JWT). The JWT is what continuation jobs use.
  # Auth stubs (OAuth exchange, JWT request, users/me) are NOT registered here;
  # WebMock raises on any unregistered request, proving no auth occurs.
  # Continuation jobs skip authenticate and ensure_not_importing_others.
  # WebMock raises UnregisteredRequestError if any auth endpoint is reached.
  def test_continuation_job_skips_authentication
    create_ivars_from_filename("calostoma_lutescens", token: "MockJWT")
    @user.update(inat_username: @inat_import.inat_username)
    stub_inat_observation_request
    stub_inat_photo_requests
    stub_modify_inat_observations

    assert_difference("Observation.count", 1,
                      "Continuation job should still import observations") do
      InatImportJob.perform_now(@inat_import, id_above: 0, continuation: true)
    end
  end

  # Continuation jobs forward the id_above cursor to PageParser so iNat
  # returns obs AFTER the last one imported in the previous batch.
  # token: "MockJWT" — same as above: continuation jobs start with the JWT
  # the first job already obtained; they never re-authenticate.
  # The observation stub is registered only for specific_id_above.
  # A request with id_above: 0 (the default) would hit an unregistered
  # WebMock stub and raise, proving the cursor is forwarded correctly.
  # returns obs AFTER the last one imported in the previous batch.
  # WebMock is set up only for the specific id_above, so any request
  # with id_above: 0 would raise, proving the cursor is forwarded.
  def test_continuation_job_resumes_from_id_above
    create_ivars_from_filename("calostoma_lutescens", token: "MockJWT")
    @user.update(inat_username: @inat_import.inat_username)
    specific_id_above = 999_999
    stub_inat_observation_request(id_above: specific_id_above)
    stub_inat_photo_requests
    stub_modify_inat_observations

    assert_difference("Observation.count", 1) do
      InatImportJob.perform_now(@inat_import,
                                id_above: specific_id_above,
                                continuation: true)
    end
  end

  # When a batch fills (obs count >= BATCH_SIZE), the job enqueues a
  # continuation and leaves the import in Importing state (not Done).
  # Uses import_all.txt (2 obs, total_results=5, per_page=2) with
  # BATCH_SIZE temporarily lowered to 2.
  def test_batch_full_enqueues_continuation
    raw = File.read("test/inat/import_all.txt")
    @mock_inat_response = raw
    @parsed_results =
      JSON.parse(@mock_inat_response, symbolize_names: true)[:results]
    @inat_import = InatImport.create(user: @user, inat_ids: "",
                                     import_all: true,
                                     token: "MockCode",
                                     inat_username: "anything")

    saved_batch_size = InatImportJob.const_get(:BATCH_SIZE)
    InatImportJob.send(:remove_const, :BATCH_SIZE)
    InatImportJob.const_set(:BATCH_SIZE, 2)

    begin
      stub_inat_interactions
      last_id = @parsed_results.last[:id]

      assert_enqueued_with(
        job: InatImportJob,
        args: [@inat_import, { id_above: last_id, continuation: true }]
      ) do
        InatImportJob.perform_now(@inat_import)
      end
      assert_equal(
        "Importing", @inat_import.reload.state,
        "State must stay Importing while continuation job is pending"
      )
    ensure
      InatImportJob.send(:remove_const, :BATCH_SIZE)
      InatImportJob.const_set(:BATCH_SIZE, saved_batch_size)
    end
  end

  # -------- Other Utilities

  # Hack to turn results with many pages into results with one page
  # By ignoring all pages but the first
  def limited_to_first_page(mock_search_result)
    ms_hash = JSON.parse(mock_search_result)
    ms_hash["total_results"] = ms_hash["results"].length
    JSON.generate(ms_hash)
  end
end
