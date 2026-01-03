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
    name = Name.create(
      text_name: "Calostoma lutescens", author: "(Schweinitz) Burnap",
      search_name: "Calostoma lutescens (Schweinitz) Burnap",
      display_name: "**__Calostoma lutescens__** (Schweinitz) Burnap",
      rank: "Species",
      user: @user
    )
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
    standard_assertions(obs: obs, name: name, loc: loc)

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

    assert_equal(before_total_imported_count + 1,
                 @inat_import.reload.total_imported_count,
                 "Failed to update user's inat_import count")
    assert(@inat_import.total_seconds.to_i.positive?,
           "Failed to update user's inat_import total_seconds")
    assert_equal(
      0, @tracker.reload.estimated_remaining_time,
      "Estimated remaining time should be 0 when InatImportJob is Done"
    )
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
    InatImportJobTracker.create(inat_import: @inat_import.id)

    # Add objects which are not included in fixtures
    Name.create(
      text_name: "Calostoma lutescens", author: "(Schweinitz) Burnap",
      search_name: "Calostoma lutescens (Schweinitz) Burnap",
      display_name: "**__Calostoma lutescens__** (Schweinitz) Burnap",
      rank: "Species",
      user: user
    )
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
    name = Name.create(
      text_name: "Evernia", author: "Ach.", search_name: "Evernia Ach.",
      display_name: "**__Evernia__** Ach.",
      rank: "Genus", user: @user
    )
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
    standard_assertions(obs: obs, name: name, loc: loc)

    inat_photo = @parsed_results.
                 first[:observation_photos].first
    imported_img = obs.images.first
    assert_equal(@user, imported_img.user,
                 "Image should belong to importing user")
    assert_equal(
      "iNat photo_id: #{inat_photo[:photo_id]}, uuid: #{inat_photo[:uuid]}",
      imported_img.original_name,
      "Image original_name should be iNat photo_id and uuid"
    )

    assert(obs.sequences.none?)
  end

  # Had 1 photo; 2 identifications, 1 not by user.
  def test_import_job_obs_with_many_namings
    create_ivars_from_filename("tremella_mesenterica")

    name = Name.find_or_create_by(text_name: "Tremellales",
                                  author: "Fr.",
                                  search_name: "Tremellales Fr.",
                                  display_name: "Tremellales",
                                  rank: "Order",
                                  user: @user)

    stub_inat_interactions

    assert_difference("Observation.count", 1,
                      "Failed to create observation") do
      InatImportJob.perform_now(@inat_import)
    end

    obs = Observation.last
    standard_assertions(obs: obs, name: name)
    assert(obs.sequences.none?)
  end

  def test_import_job_blank_line_in_description
    create_ivars_from_filename("tremella_mesenterica")

    # modify iNat observation description to include blank line
    parsed_response = JSON.parse(@mock_inat_response, symbolize_names: true)
    description = "before blank line\r\n\r\nafter blank line"
    parsed_response[:results].first[:description] = description
    @mock_inat_response = parsed_response.to_json

    stub_inat_interactions

    assert_difference("Observation.count", 1,
                      "Failed to create observation") do
      InatImportJob.perform_now(@inat_import)
    end

    obs = Observation.last
    assert_equal(
      "before blank line<!--- blank line(s) removed --->\n" \
      "after blank line",
      obs.notes[:Other],
      "Failed to compress consecutive newlines/returns in Notes[:Other]"
    )
  end

  # Had 2 photos, 6 identifications of 3 taxa, a different taxon,
  # 9 obs fields, including "DNA Barcode ITS", "Collection number", "Collector"
  def test_import_job_obs_with_sequence_and_multiple_ids
    create_ivars_from_filename("lycoperdon")

    # create objects which are not included in fixtures:
    # the iNat observation name
    name = Name.create(
      text_name: "Lycoperdon", author: "Pers.",
      search_name: "Lycoperdon Pers.",
      display_name: "**__Lycoperdon__** Pers.",
      rank: "Genus",
      user: @user
    )
    # add suggested IDs so that we can test Notes snapshot
    Name.create(
      text_name: "Calvatia", author: "Fr.",
      search_name: "Calvatia Fr.",
      display_name: "**__Calvatia__** Fr.",
      rank: "Genus",
      user: @user
    )
    Name.create(
      text_name: "Lycoperdon subumbrinum", author: "Jeppson & E. Larsson",
      search_name: "Lycoperdon subumbrinum Jeppson & E. Larsson",
      display_name: "**__Lycoperdon subumbrinum__** Jeppson & E. Larsson",
      rank: "Species",
      user: @user
    )
    Name.create(
      text_name: "Lycoperdon umbrinum", author: "Pers.",
      search_name: "Lycoperdon umbrinum Pers.",
      display_name: "**__Lycoperdon umbrinum__** Pers.",
      rank: "Species",
      user: @user
    )

    stub_inat_interactions

    assert_difference("Observation.count", 1,
                      "Failed to create observation") do
      InatImportJob.perform_now(@inat_import)
    end

    obs = Observation.last
    standard_assertions(obs: obs, name: name)
    assert_snapshot_suggested_ids(obs)
    assert(obs.sequences.one?, "Obs should have a sequence")
    assert_equal(@user, obs.sequences.first.user,
                 "Sequences should belong to the user who imported the obs")
  end

  # iNat Observation ID is an infrageneric name which was suggested by a user
  def test_import_job_suggested_infrageneric_name
    create_ivars_from_filename("distantes")
    # Add objects which are not included in fixtures
    name = Name.create(
      text_name: "Morchella sect. Distantes",
      author: "Boud.",
      search_name: "Morchella sect. Distantes Boud.",
      display_name: "**__Morchella__** sect. **__Distantes__** Boud.",
      rank: "Section",
      user: @user
    )
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
    standard_assertions(obs: obs, name: name)
    assert_snapshot_suggested_ids(obs)
  end

  # iNat Observation ID is an infrageneric name not suggested by any user
  def test_import_job_unsuggested_infrageneric_name
    create_ivars_from_filename("validae")

    # Add objects which are not included in fixtures
    name = Name.create(
      text_name: "Amanita sect. Validae",
      author: "((Fr.) Quél.",
      search_name: "Amanita sect. Validae ((Fr.) Quél.",
      display_name: "**__Amanita__** sect. **__Validae__** ((Fr.) Quél.",
      rank: "Section",
      user: @user
    )

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
    standard_assertions(obs: obs, name: name)
  end

  def test_import_job_infra_specific_name
    create_ivars_from_filename("i_obliquus_f_sterilis")

    # Add objects which are not included in fixtures
    name = Name.create(
      text_name: "Inonotus obliquus f. sterilis",
      author: "(Vanin) Balandaykin & Zmitr",
      search_name: "Inonotus obliquus f. sterilis (Vanin) Balandaykin & Zmitr",
      display_name: "**__Inonotus obliquus__** f. **__sterilis__** " \
                    "(Vanin) Balandaykin & Zmitr.",
      rank: "Form",
      user: @user
    )

    stub_inat_interactions

    assert_difference("Observation.count", 1,
                      "Failed to create observation") do
      InatImportJob.perform_now(@inat_import)
    end

    obs = Observation.last
    standard_assertions(obs: obs, name: name)
    assert(obs.sequences.none?)
  end

  def test_import_job_complex
    create_ivars_from_filename("xeromphalina_campanella_complex")

    # Add objects which are not included in fixtures
    name = Name.create(
      text_name: "Xeromphalina campanella group", author: "",
      search_name: "Xeromphalina campanella group",
      display_name: "**__Xeromphalina campanella__** group",
      rank: "Group",
      user: @user
    )

    stub_inat_interactions

    assert_difference("Observation.count", 1,
                      "Failed to create observation") do
      InatImportJob.perform_now(@inat_import)
    end

    obs = Observation.last
    standard_assertions(obs: obs, name: name)
    assert(obs.sequences.none?)
  end

  # Prove that Namings, Votes, Identification are correct
  # When iNat obs has provisional name that's already in MO
  # `johnplischke` NEMF, DNA, notes, 2 identifications with same id;
  # 3 comments, everyone has MO account;
  # obs fields(include("Voucher Number(s)", "Voucher Specimen Taken"))
  def test_import_job_nemf_plischke
    create_ivars_from_filename("arrhenia_sp_NY02")

    parsed_inat_prov = Name.parse_name('Arrhenia "sp-NY02"')
    name = Name.create(
      text_name: parsed_inat_prov.text_name,
      search_name: parsed_inat_prov.search_name,
      display_name: parsed_inat_prov.display_name,
      rank: parsed_inat_prov.rank,
      user: @user
    )

    stub_inat_interactions

    assert_difference("Observation.count", 1,
                      "Failed to create observation") do
      InatImportJob.perform_now(@inat_import)
    end

    obs = Observation.last
    standard_assertions(obs: obs, name: name)

    assert(obs.sequences.one?, "Obs should have one Sequence")
    assert(obs.specimen, "Obs should show that a Specimen is available")
  end

  # Prove that Namings, Votes, Identification are correct
  # when iNat obs has provisional name that wasn't in MO
  # see test above for iNat obs details
  def test_import_job_create_prov_name
    assert_nil(Name.find_by(text_name: 'Arrhenia "sp-NY02"'),
               "Test requires that MO not yet have provisional name")
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

    standard_assertions(obs: obs, name: name)

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
      "#{@user.login} created #{name.user_real_text_name(@user)}"
    assert_enqueued_with(
      job: ActionMailer::MailDeliveryJob,
      args: lambda { |args|
        args[0] == "WebmasterMailer" && args[1] == "build" &&
          args[3][:args].last[:subject] == expected_subject
      }
    )
  end

  # Inat Provisional Species Name "Donadina PNW01" (no: quotes, sp. dash)
  def test_import_job_prov_name_pnw_style
    assert(Name.where(Name[:text_name] =~ /Donadinia/).none?,
           "Test requires that MO not yet have `Donadinia` Names")

    create_ivars_from_filename("donadinia_PNW01")
    stub_inat_interactions

    assert_difference("Observation.count", 1,
                      "Failed to create observation") do
      InatImportJob.perform_now(@inat_import)
    end

    obs = Observation.last

    new_names = Name.where(Name[:text_name] =~ /Donadinia/)
    assert_equal(2, new_names.count,
                 "Failed to create new sp. (nom. prov.) and its genus")
    new_names.each do |new_name|
      assert_equal(
        @user, new_name.user,
        "#{new_name.text_name} owner should be #{@user.login}"
      )
    end
    name = new_names.find_by(rank: "Species")

    standard_assertions(obs: obs, name: name)

    assert(obs.sequences.one?, "Obs should have one sequence")
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
    InatImportJobTracker.create(inat_import: @inat_import.id)

    # Add objects which are not included in fixtures
    Name.create(
      text_name: "Calostoma lutescens", author: "(Schweinitz) Burnap",
      search_name: "Calostoma lutescens (Schweinitz) Burnap",
      display_name: "**__Calostoma lutescens__** (Schweinitz) Burnap",
      rank: "Species",
      user: user
    )
    Location.create(user: user,
                    name: "Sevier Co., Tennessee, USA",
                    north: 36.043571, south: 35.561849,
                    east: -83.253046, west: -83.794123)

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
    InatImportJobTracker.update(inat_import: @inat_import.id)
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
    InatImportJobTracker.update(inat_import: @inat_import.id)

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
    InatImportJobTracker.create(inat_import: @inat_import.id)
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
  end

  def test_super_importer_anothers_observation
    @user = users(:dick)
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
    assert_nil(@user.reload.inat_username,
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
                                     inat_username: "anything")
    InatImportJobTracker.create(inat_import: @inat_import.id)
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

  def test_import_canceled
    create_ivars_from_filename("listed_ids") # importing multiple observations
    # override ivar because this test wants to import multiple observations
    @inat_import = InatImport.create(user: @user,
                                     inat_ids: "231104466,195434438",
                                     token: "MockCode",
                                     inat_username: "anything")
    # update the tracker's inat_import accordingly
    InatImportJobTracker.update(inat_import: @inat_import.id)
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
      iconic_taxa: ICONIC_TAXA,
      id: @inat_import.inat_ids,
      id_above: 0,
      per_page: 200,
      only_id: false,
      order: "asc",
      order_by: "id",
      without_field: "Mushroom Observer URL",
      verifiable: "any",
      user_id: @inat_import.inat_username
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
                 "Observation should be destroyed after error")

    errors = JSON.parse(@inat_import.response_errors, symbolize_names: true)
    assert_equal(status, errors[:error], "Incorrect error status")

    # The payload should contain the observation_field_value details
    payload = errors[:payload]
    assert(payload.is_a?(Hash), "Error payload should be a hash")
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

  ########## Utilities

  ########## Utilities

  def create_ivars_from_filename(filename, **attrs)
    @mock_inat_response = File.read("test/inat/#{filename}.txt")
    @parsed_results =
      JSON.parse(@mock_inat_response, symbolize_names: true)[:results]

    @inat_import = create_inat_import(**attrs)
    @tracker = InatImportJobTracker.create(inat_import: @inat_import.id)
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

  def standard_assertions(obs:, user: @user, name: nil, loc: nil)
    assert_not_nil(obs.rss_log, "Failed to log Observation")
    assert_equal("mo_inat_import", obs.source)
    assert_equal(loc, obs.location) if loc

    photo_count = @parsed_results.first[:observation_photos].length
    assert_equal(photo_count, obs.images.length,
                 "Observation should have #{photo_count} image(s)")

    assert_equal(1, obs.namings.length,
                 "iNatImport should create exactly one Naming")
    obs.namings.each do |naming|
      assert_not(
        naming.vote_cache.zero?,
        "VoteCache for Proposed Name '#{naming.name.text_name}' incorrect"
      )
    end

    if name
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
      assert_equal(Vote::MAXIMUM_VOTE, vote.value,
                   "Vote for MO consensus should be highest possible vote")
    end

    view = ObservationView.
           find_by(observation_id: obs.id, user_id: user.id)
    assert(view.present?, "Failed to create ObservationView")

    external_link = obs.external_links.first
    assert_equal(
      "#{@external_link_base_url}#{@parsed_results.first[:id]}",
      external_link&.url,
      "MO Observation should have ExternalLink to iNat observation"
    )

    assert(obs.inat_id.present?, "Failed to set Observation inat_id")

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

  def assert_naming(obs:, name:, user:)
    namings = obs.namings
    naming = namings.find_by(name: name)
    assert(naming.present?, "Naming for MO consensus ID")
    assert_equal(user, naming.user,
                 "Naming should belong to #{user.login}")
  end

  def assert_snapshot_suggested_ids(obs)
    idents = @parsed_results.first[:identifications]
    # Get the MO Names corresponding to the iNat suggested taxon names
    # Because iNat names may not be ICN-compliant, e.g. infrageneric names
    unique_suggested_taxon_names = idents.each_with_object([]) do |ident, ary|
      ident_taxon = ::Inat::Taxon.new(ident[:taxon])
      ary << ident_taxon.name
    end
    unique_suggested_taxon_names.each do |name|
      assert_match(name.text_name, obs.notes.to_s,
                   "Notes Snapshot missing suggested name #{name.text_name}")
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
