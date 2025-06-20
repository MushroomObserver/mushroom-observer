# frozen_string_literal: true

require("test_helper")
require_relative("inat_import_job_test_doubles")

class InatImportJobTest < ActiveJob::TestCase
  include InatImportJobTestDoubles

  def setup
    @user = users(:inat_importer)
    directory_path = Rails.public_path.join("test_images/orig")
    FileUtils.mkdir_p(directory_path) unless Dir.exist?(directory_path)
    @external_link_base_url = ExternalSite.find_by(name: "iNaturalist").base_url
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
    QueuedEmail.queue = true
    before_emails_to_user = QueuedEmail.where(to_user: @user).count
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
    assert_match(/Observation Fields: none/, obs.comments.first.comment,
                 "Missing 'none' for Observation Fields")

    assert_equal(
      before_emails_to_user, QueuedEmail.where(to_user: @user).count,
      "Should not have sent any emails to importing user for this obs"
    )
    QueuedEmail.queue = false

    assert_equal(before_total_imported_count + 1,
                 @inat_import.reload.total_imported_count,
                 "Failed to update user's inat_import count")
    assert(@inat_import.total_time.to_i.positive?,
           "Failed to update user's inat_import total_time")
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

  # Had 2 photos, 6 identifications of 3 taxa, a different taxon,
  # 9 obs fields, including "DNA Barcode ITS", "Collection number", "Collector"
  def test_import_job_obs_with_sequence_and_multiple_ids
    create_ivars_from_filename("lycoperdon")

    name = Name.create(
      text_name: "Lycoperdon", author: "Pers.",
      search_name: "Lycoperdon Pers.",
      display_name: "**__Lycoperdon__** Pers.",
      rank: "Genus",
      user: @user
    )

    stub_inat_interactions

    assert_difference("Observation.count", 1,
                      "Failed to create observation") do
      InatImportJob.perform_now(@inat_import)
    end

    obs = Observation.last
    standard_assertions(obs: obs, name: name)

    assert(obs.sequences.one?, "Obs should have a sequence")
    assert_equal(@user, obs.sequences.first.user,
                 "Sequences should belong to the user who imported the obs")

    ids = @parsed_results.first[:identifications]
    unique_suggested_taxon_names = ids.each_with_object([]) do |id, ary|
      ary << id[:taxon][:name]
    end
    unique_suggested_taxon_names.each do |taxon_name|
      assert_match(taxon_name, obs.comments.first.comment,
                   "Snapshot comment missing suggested name #{taxon_name}")
    end
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

  def test_import_update_inat_username_if_job_succeeds
    create_ivars_from_filename("zero_results")
    # simulate user entering new inat_username in iNat import form
    @inat_import.update(inat_username: "updatedInatUsername",
                        inat_ids: "123", token: "MockCode")
    stub_inat_interactions

    assert_changes("@user.inat_username", to: "updatedInatUsername") do
      InatImportJob.perform_now(@inat_import)
    end
  end

  def test_import_multiple
    create_ivars_from_filename("listed_ids")

    # override ivar because this test wants to import multiple observations
    @inat_import = InatImport.create(user: @user,
                                     inat_ids: "231104466,195434438",
                                     token: "MockCode",
                                     inat_username: "anything")
    # update the tracker's inat_import accordingly
    InatImportJobTracker.update(inat_import: @inat_import.id)
    stub_inat_interactions

    assert_difference("Observation.count", 2,
                      "Failed to create multiple observations") do
      InatImportJob.perform_now(@inat_import)
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

    stub_inat_interactions(login: "another user")

    assert_difference("Observation.count", 0,
                      "It should not import another user's observation") do
      InatImportJob.perform_now(@inat_import)
    end

    assert_match(
      :inat_wrong_user.l, @inat_import.response_errors,
      "It should warn if a user tries to import another's iNat obs"
    )
  end

  def test_super_importer_anothers_observation
    @user = users(:dick)
    assert(InatImport.super_importers.include?(@user),
           "Test needs User fixture that's SuperImporter")

    create_ivars_from_filename("calostoma_lutescens")
    stub_inat_interactions(superimporter: true)

    assert_difference(
      "Observation.count", 1,
      "'super_importer' failed to import another user's observation"
    ) do
      InatImportJob.perform_now(@inat_import)
    end

    assert_empty(@inat_import.response_errors, "There should be no errors")
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

  ########## Utilities

  def create_ivars_from_filename(filename)
    @mock_inat_response = File.read("test/inat/#{filename}.txt")
    @parsed_results =
      JSON.parse(@mock_inat_response, symbolize_names: true)[:results]
    @inat_import = create_inat_import
    InatImportJobTracker.create(inat_import: @inat_import.id)
  end

  # The InatImport object which is created in InatImportController#create
  # and recovered in InatImportController#authorization_response
  def create_inat_import(user: @user)
    InatImport.create(
      user: user, token: "MockCode",
      inat_ids: @parsed_results.first&.dig(:id),
      inat_username: @parsed_results.first&.dig(:user, :login),
      response_errors: ""
    )
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

    assert(obs.comments.any?, "Imported iNat should have >= 1 Comment")
    obs_comments =
      Comment.where(target_type: "Observation", target_id: obs.id)
    assert(obs_comments.one?)
    assert(obs_comments.where(Comment[:summary] =~ /iNat Data/).present?,
           "Missing Initial Commment (#{:inat_data_comment.l})")
    assert_equal(
      user, obs_comments.first.user,
      "Comment user should be user who creates the MO Observation"
    )
    inat_data_comment = obs_comments.first.comment
    [
      :USER.l, :OBSERVED.l, :show_observation_inat_lat_lng.l, :PLACE.l,
      :ID.l, :DQA.l, :show_observation_inat_suggested_ids.l,
      :OBSERVATION_FIELDS.l,
      :ANNOTATIONS.l, :PROJECTS.l, :TAGS.l
    ].each do |caption|
      assert_match(
        /#{caption}/, inat_data_comment,
        "Initial Commment (#{:inat_data_comment.l}) is missing #{caption}"
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

  # -------- Other Utilities

  # Hack to turn results with many pages into results with one page
  # By ignoring all pages but the first
  def limited_to_first_page(mock_search_result)
    ms_hash = JSON.parse(mock_search_result)
    ms_hash["total_results"] = ms_hash["results"].length
    JSON.generate(ms_hash)
  end
end
