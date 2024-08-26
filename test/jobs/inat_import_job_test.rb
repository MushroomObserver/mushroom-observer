# frozen_string_literal: true

require "test_helper"

# Some classes with enough attributes to stub calls to InatPhotoImporter
#   (which wraps calls to the MO Image API)
# and get an image back like this
#  api = InatPhotoImporter.new(params).api
#  image = Image.find(api.results.first.id)
class MockImageAPI
  attr_reader :errors, :results

  def initialize(errors: [], results: [])
    @errors = errors
    @results = results
  end
end

class MockPhotoImporter
  attr_reader :api

  def initialize(api:)
    @api = api
  end
end

class InatImportJobTest < ActiveJob::TestCase
  SITE = Observations::InatImportsController::SITE
  REDIRECT_URI = Observations::InatImportsController::REDIRECT_URI
  API_BASE = Observations::InatImportsController::API_BASE
  PHOTO_BASE = "https://inaturalist-open-data.s3.amazonaws.com/photos"

  ICONIC_TAXA = InatImportJob::ICONIC_TAXA

  # Had 1 identification, 0 photos, 0 observation_fields
  def test_import_job_basic_obs
    file_name = "calostoma_lutescens"
    mock_inat_response = File.read("test/inat/#{file_name}.txt")
    user = users(:rolf)
    inat_import = create_inat_import(inat_response: mock_inat_response)

    # Add objects which are not included in fixtures
    name = Name.create(
      text_name: "Calostoma lutescens",
      author: "(Schweinitz) Burnap",
      display_name: "**__Calostoma lutescens__** (Schweinitz) Burnap",
      rank: "Species",
      user: user
    )
    loc = Location.create(user: user,
                          name: "Sevier Co., Tennessee, USA",
                          north: 36.043571, south: 35.561849,
                          east: -83.253046, west: -83.794123)

    stub_inat_interactions(inat_import: inat_import,
                           mock_inat_response: mock_inat_response)

    InatPhotoImporter.stub(:new, stub_mo_photo_importer(mock_inat_response)) do
      InatImportJob.perform_now(inat_import)
    end

    obs = Observation.order(created_at: :asc).last
    assert_standard_assertions(obs: obs, name: name, loc: loc)
    assert_equal(0, obs.images.length, "Obs should not have images")
  end

  # Had 1 photo, 1 identification, 0 observation_fields
  def test_import_job_obs_with_one_photo
    file_name = "evernia"
    mock_inat_response = File.read("test/inat/#{file_name}.txt")
    user = users(:rolf)
    inat_import = create_inat_import(inat_response: mock_inat_response)

    # Add objects which are not included in fixtures
    name = Name.create(
      text_name: "Evernia", author: "Ach.", display_name: "Evernia",
      rank: "Genus", user: user
    )
    loc = Location.create(
      user: user,
      name: "Troutdale, Multnomah Co., Oregon, USA",
      north: 45.5609, south: 45.5064,
      east: -122.367, west: -122.431
    )

    stub_inat_interactions(inat_import: inat_import,
                           mock_inat_response: mock_inat_response)

    InatPhotoImporter.stub(:new, stub_mo_photo_importer(mock_inat_response)) do
      InatImportJob.perform_now(inat_import)
    end

    obs = Observation.order(created_at: :asc).last
    assert_standard_assertions(obs: obs, name: name, loc: loc)
    assert_equal(1, obs.images.length, "Obs should have 1 image")
    assert(obs.sequences.none?)
  end

  # Had many identifications, 1 photo
  def test_import_job_obs_with_many_namings
    file_name = "tremella_mesenterica"
    mock_inat_response = File.read("test/inat/#{file_name}.txt")
    user = users(:rolf)
    inat_import = create_inat_import(inat_response: mock_inat_response)

    # Add objects which are not included in fixtures
    # This iNat obs has two identifications:
    # Tremella mesenterica, which in is fixtures
    t_mesenterica = Name.find_by(text_name: "Tremella mesenterica")
    # "Naematelia aurantia, which is not
    n_aurantia = Name.create(text_name: "Naematelia aurantia",
                             author: "(Schwein.) Burt",
                             display_name: "Naematelia aurantia",
                             rank: "Species",
                             user: user)
    # and the iNat Community Taxon (not an identification for this iNat obs)
    tremellales = Name.create(text_name: "Tremellales",
                              author: "Fr.",
                              display_name: "Tremellales",
                              rank: "Order",
                              user: user)
    name = tremellales

    stub_inat_interactions(inat_import: inat_import,
                           mock_inat_response: mock_inat_response)

    InatPhotoImporter.stub(:new, stub_mo_photo_importer(mock_inat_response)) do
      InatImportJob.perform_now(inat_import)
    end

    obs = Observation.order(created_at: :asc).last
    assert_standard_assertions(obs: obs, name: name)

    namings = obs.namings
    naming = namings.find_by(name: t_mesenterica)
    assert(naming.present?,
           "Missing Naming for iNat identification by MO User")
    assert_equal(inat_manager, naming.user, "Naming has wrong User")
    vote = Vote.find_by(naming: naming, user: naming.user)
    assert(vote.present?, "Naming is missing a Vote")
    assert_equal(Vote::MAXIMUM_VOTE, vote.value,
                 "Vote for non-consensus name should be highest possible")

    naming = namings.find_by(name: n_aurantia)
    assert(naming.present?,
           "Missing Naming for iNat identification by random iNat user")
    assert_equal(inat_manager, naming.user, "Naming has wrong User")
    vote = Vote.find_by(naming: naming, user: naming.user)
    assert_equal(Vote::MAXIMUM_VOTE, vote.value,
                 "Vote for non-consensus name should be highest possible")

    assert(obs.images.any?, "Obs should have images")
    assert(obs.sequences.none?)
  end

  # Had 2 photos, 6 identifications of 3 taxa, a different taxon,
  # 9 obs fields, including "DNA Barcode ITS", "Collection number", "Collector"
  def test_import_job_obs_with_sequence
    file_name = "lycoperdon"
    mock_inat_response = File.read("test/inat/#{file_name}.txt")
    user = users(:rolf)
    inat_import = create_inat_import(inat_response: mock_inat_response)

    name = Name.create(
      text_name: "Lycoperdon", author: "Pers.", rank: "Genus",
      display_name: "**__Lycoperdon__** Pers.", user: user
    )

    stub_inat_interactions(inat_import: inat_import,
                           mock_inat_response: mock_inat_response)

    InatPhotoImporter.stub(:new, stub_mo_photo_importer(mock_inat_response)) do
      InatImportJob.perform_now(inat_import)
    end

    obs = Observation.order(created_at: :asc).last
    assert_standard_assertions(obs: obs, name: name)

    assert(obs.images.any?, "Obs should have images")
    assert(obs.sequences.one?, "Obs should have a sequence")
  end

  # Prove that Namings, Votes, Identification are correct
  # When iNat obs has provisional name that's already in MO
  # `johnplischke` NEMF, DNA, notes, 2 identifications with same id;
  # 3 comments, everyone has MO account;
  # obs fields(include("Voucher Number(s)", "Voucher Specimen Taken"))
  def test_import_job_prov_name
    file_name = "arrhenia_sp_NY02"
    mock_inat_response = File.read("test/inat/#{file_name}.txt")
    inat_import = create_inat_import(inat_response: mock_inat_response)
    name = Name.create(
      text_name: 'Arrhenia "sp-NY02"',
      author: "S.D. Russell crypt. temp.",
      display_name: '**__Arrhenia "sp-NY02"__** S.D. Russell crypt. temp.',
      rank: "Species",
      user: inat_manager
    )

    stub_inat_interactions(inat_import: inat_import,
                           mock_inat_response: mock_inat_response)

    InatPhotoImporter.stub(:new,
                           stub_mo_photo_importer(mock_inat_response)) do
      InatImportJob.perform_now(inat_import)
    end

    obs = Observation.order(created_at: :asc).last
    assert_standard_assertions(obs: obs, name: name)

    assert(obs.images.any?, "Obs should have images")
    assert(obs.sequences.one?, "Obs should have a sequence")
  end

  # Prove that Namings, Votes, Identification are correct
  # when iNat obs has provisional name that wasn't in MO
  # see test above for iNat obs details
  def test_import_job_create_prov_name
    assert_nil(Name.find_by(text_name: 'Arrhenia "sp-NY02"'),
               "Test requires that MO not yet have provisional name")

    file_name = "arrhenia_sp_NY02"
    mock_inat_response = File.read("test/inat/#{file_name}.txt")
    inat_import = create_inat_import(inat_response: mock_inat_response)

    stub_inat_interactions(inat_import: inat_import,
                           mock_inat_response: mock_inat_response)

    InatPhotoImporter.stub(:new,
                           stub_mo_photo_importer(mock_inat_response)) do
      InatImportJob.perform_now(inat_import)
    end

    obs = Observation.order(created_at: :asc).last
    name = Name.find_by(text_name: 'Arrhenia "sp-NY02"')
    assert(name.present?, "Failed to create provisional name")
    assert(name.rss_log_id.present?,
           "Failed to log creation of provisional name")

    assert_standard_assertions(obs: obs, name: Name.last)

    assert(obs.images.any?, "Obs should have images")
    assert(obs.sequences.one?, "Obs should have a sequence")
  end

  def test_import_plant
    file_name = "ceanothus_cordulatus"
    mock_inat_response = File.read("test/inat/#{file_name}.txt")
    inat_import = create_inat_import(inat_response: mock_inat_response)
    stub_inat_interactions(inat_import: inat_import,
                           mock_inat_response: mock_inat_response)

    InatPhotoImporter.stub(
      :new, stub_mo_photo_importer(mock_inat_response)
    ) do
      assert_no_difference(
        "Observation.count", "Should not import iNat Plant observations"
      ) do
        InatImportJob.perform_now(inat_import)
      end
    end
  end

  def test_import_zero_results
    file_name = "zero_results"
    mock_inat_response = File.read("test/inat/#{file_name}.txt")
    inat_import = InatImport.create(inat_ids: "123", token: "MockCode",
                                    inat_username: "anything")
    stub_inat_interactions(inat_import: inat_import,
                           mock_inat_response: mock_inat_response)

    InatPhotoImporter.stub(
      :new, stub_mo_photo_importer(mock_inat_response)
    ) do
      assert_no_difference(
        "Observation.count",
        "Should import nothing if no iNat obss match the id's typed by the user"
      ) do
        InatImportJob.perform_now(inat_import)
      end
    end
  end

  def test_import_multiple
    # NOTE: using obss without photos to avoid stubbing photo import
    # amanita_flavorubens, calostoma lutescens
    file_name = "listed_ids"
    mock_inat_response = File.read("test/inat/#{file_name}.txt")
    inat_import = InatImport.create(user: users(:rolf),
                                    inat_ids: "231104466,195434438",
                                    token: "MockCode",
                                    inat_username: "anything")

    # prove that mock was constructed properly
    json = JSON.parse(mock_inat_response)
    assert_equal(2, json["total_results"])
    assert_equal(1, json["page"])
    assert_equal(30, json["per_page"])
    # mock is sorted by id, asc
    assert_equal(195_434_438, json["results"].first["id"])
    assert_equal(231_104_466, json["results"].second["id"])

    stub_inat_interactions(inat_import: inat_import,
                           mock_inat_response: mock_inat_response)

    InatPhotoImporter.stub(
      :new, stub_mo_photo_importer(mock_inat_response)
    ) do
      assert_difference(
        "Observation.count", 2, "Failed to create multiple observations"
      ) do
        InatImportJob.perform_now(inat_import)
      end
    end
  end

  # Prove that "Import all my iNat observations imports" multiple obsservations
  # NOTE: It would be complicated to prove that it imports multiple pages.
  def test_import_all
    file_name = "import_all"
    mock_inat_response = File.read("test/inat/#{file_name}.txt")
    inat_import = InatImport.create(user: users(:rolf),
                                    inat_ids: "",
                                    import_all: true,
                                    token: "MockCode",
                                    inat_username: "anything")
    # limit it to one page to avoid complications of stubbing multiple
    # inat api requests with multiple files
    mock_inat_response = limited_to_first_page(mock_inat_response)

    stub_inat_interactions(inat_import: inat_import,
                           mock_inat_response: mock_inat_response)

    InatPhotoImporter.stub(
      :new, stub_mo_photo_importer(mock_inat_response)
    ) do
      assert_difference(
        "Observation.count", 2, "Failed to create multiple observations"
      ) do
        InatImportJob.perform_now(inat_import)
      end
    end
  end

  ########## Utilities

  # The InatImport object which is created in InatImportController#create
  # and recovered in InatImportController#authorization_response
  def create_inat_import(user: users(:rolf),
                         inat_response: mock_inat_response)
    InatImport.create(
      user: user, token: "MockCode",
      inat_ids: JSON.parse(inat_response)["results"].first["id"],
      inat_username: JSON.
        parse(inat_response)["results"].first["user"]["login"]
    )
  end

  # -------- Test doubles

  def stub_inat_interactions(inat_import:, mock_inat_response:, id_above: 0)
    stub_token_requests
    stub_inat_api_request(inat_import: inat_import,
                          mock_inat_response: mock_inat_response,
                          id_above: id_above)
    stub_inat_photo_requests(mock_inat_response)
  end

  def stub_token_requests
    stub_oauth_token_request
    # must trade oauth access token for a JWT in order to use iNat API v1
    stub_jwt_request
  end

  # stub exchanging iNat code for oauth token
  # https://www.inaturalist.org/pages/api+reference#authorization_code_flow
  def stub_oauth_token_request
    stub_request(:post, "#{SITE}/oauth/token").
      with(
        body: { "client_id" => Rails.application.credentials.inat.id,
                "client_secret" => Rails.application.credentials.inat.secret,
                "code" => "MockCode",
                "grant_type" => "authorization_code",
                "redirect_uri" => REDIRECT_URI }
      ).
      to_return(status: 200,
                body: { access_token: "MockAccessToken" }.to_json,
                headers: {})
  end

  def stub_jwt_request
    stub_request(:get, "#{SITE}/users/api_token").
      with(
        headers: {
          "Accept" => "application/json",
          "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
          "Authorization" => "Bearer MockAccessToken",
          "Host" => "www.inaturalist.org"
        }
      ).
      to_return(status: 200,
                body: { access_token: "MockJWT" }.to_json,
                headers: {})
  end

  def stub_inat_api_request(inat_import:, mock_inat_response:, id_above: 0)
    # params must be in same order as in the controller
    # omit trailing "=" since the controller omits it (via `merge`)
    params = <<~PARAMS.delete("\n").chomp("=")
      ?iconic_taxa=#{ICONIC_TAXA}
      &id=#{inat_import.inat_ids}
      &id_above=#{id_above}
      &per_page=200
      &only_id=false
      &order=asc&order_by=id
      &user_login=#{inat_import.inat_username}
    PARAMS
    stub_request(:get, "#{API_BASE}/observations#{params}").
      with(headers:
    { "Accept" => "application/json",
      "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
      "Authorization" => "Bearer",
      "Host" => "api.inaturalist.org" }).
      to_return(body: mock_inat_response)
  end

  def stub_inat_photo_requests(mock_inat_response)
    JSON.parse(mock_inat_response)["results"].each do |result|
      result["observation_photos"].each do |photo|
        stub_request(
          :get,
          "#{PHOTO_BASE}/#{photo["photo_id"]}/original.jpg"
        ).
          with(
            headers: {
              "Accept" => "image/*",
              "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
              "Host" => "inaturalist-open-data.s3.amazonaws.com",
              "User-Agent" => "Ruby"
            }
          ).
          to_return(status: 200, body: "", headers: {})
      end
    end
  end

  def stub_mo_photo_importer(mock_inat_response)
    # Suggested by CoPilot:
    # I wanted to directly stub InatPhotoImporter.new,
    # but that class doesn’t have a stub method by default. Therefore:
    # Create a mock photo importer
    mock_photo_importer = Minitest::Mock.new
    mock_photo_importer.expect(
      :new, nil,
      [{ api: MockImageAPI.new(errors: [], results: [Image.first]) }]
    )
    results = JSON.parse(mock_inat_response)["results"]
    # NOTE: This simply insures that ImageAPI is called the right # of times.
    # It does NOT attach the right # of photos or even the correct photo.
    results.each do |observation|
      observation["observation_photos"].each do
        mock_photo_importer.expect(
          :api, # nil,
          MockImageAPI.new(errors: [], results: [Image.first])
        )
      end
    end
    mock_photo_importer
  end

  # -------- Standard Test assertions

  def assert_standard_assertions(obs:, name: nil, loc: nil)
    assert_not_nil(obs.rss_log, "Failed to log Observation")
    assert_equal("mo_inat_import", obs.source)
    assert_equal(loc, obs.location) if loc

    if name
      assert_equal(name, obs.name, "Wrong consensus id")

      assert_equal(name, obs.name)
      namings = obs.namings
      naming = namings.find_by(name: name)
      assert(naming.present?, "Missing Naming for MO consensus ID")
      assert_equal(inat_manager, naming.user,
                   "Namings should belong to inat_manager")
      vote = Vote.find_by(naming: naming, user: naming.user)
      assert(vote.present?, "Naming is missing a Vote")
      assert_equal(Vote::MAXIMUM_VOTE, vote.value,
                   "Vote for MO consensus should be highest possible vote")
    end

    assert(obs.comments.any?, "Imported iNat should have >= 1 Comment")
    obs_comments =
      Comment.where(target_type: "Observation", target_id: obs.id)
    assert(obs_comments.one?)
    assert(obs_comments.where(Comment[:summary] =~ /^iNat Data/).present?,
           "Missing Initial Commment (#{:inat_data_comment.l})")
    assert_equal(
      inat_manager, obs_comments.first.user,
      "Comment user should be webmaster (vs user who imported iNat Obs)"
    )
    inat_data_comment = obs_comments.first.comment
    [
      :USER.l, :OBSERVED.l, :LAT_LON.l, :PLACE.l, :ID.l, :DQA.l,
      :ANNOTATIONS.l, :PROJECTS.l, :SEQUENCES.l, :OBSERVATION_FIELDS.l,
      :TAGS.l
    ].each do |caption|
      assert_match(
        /#{caption}/, inat_data_comment,
        "Initial Commment (#{:inat_data_comment.l}) is missing #{caption}"
      )
    end
  end

  # -------- Other

  def inat_manager
    User.find_by(login: "MO Webmaster")
  end

  # ---------------------------------------------------------------------------
  # Everything above here is live code.
  # TODO: Remove this comment and everything below it.
  # Everything below is potentially dead.

  # Turn results with many pages into results with one page
  # By ignoring all pages but the first
  def limited_to_first_page(mock_search_result)
    ms_hash = JSON.parse(mock_search_result)
    ms_hash["total_results"] = ms_hash["results"].length
    JSON.generate(ms_hash)
  end
end
