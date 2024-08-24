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
  PHOTO_BASE = "https://inaturalist-open-data.s3.amazonaws.com/photos".freeze

  ICONIC_TAXA = InatImportJob::ICONIC_TAXA

  def test_import_job_basic_obs
    # This obs has 1 identification, 0 photos, 0 observation_fields
    file_name = "calostoma_lutescens"
    user = users(:rolf)
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

    inat_import = InatImport.create(user: user, token: "MockCode",
                                    inat_ids: "195434438",
                                    inat_username: "mycoprimus")
    stub_token_requests
    mock_inat_response = File.read("test/inat/#{file_name}.txt")
    stub_inat_api_request(inat_import: inat_import,
                          mock_inat_response: mock_inat_response)

    InatImportJob.perform_now(inat_import)

    obs = Observation.order(created_at: :asc).last
    assert_not_nil(obs.rss_log)

    assert_equal(name, obs.name)
    namings = obs.namings
    naming = namings.find_by(name: name)
    assert(naming.present?, "Missing Naming for MO consensus ID")
    assert_equal(inat_manager, naming.user,
                 "Namings should belong to inat_manager")
    vote = Vote.find_by(naming: naming, user: naming.user)
    assert(vote.present?, "Naming is missing a Vote")
    assert(vote.value.positive?, "Vote for MO consensus should be positive")

    assert_equal("mo_inat_import", obs.source)
    assert_equal(0, obs.images.length, "Obs should not have images")
    assert_equal(loc, obs.location)
    assert(obs.comments.any?, "Imported iNat should have >= 1 Comment")
    obs_comments =
      Comment.where(target_type: "Observation", target_id: obs.id)
    assert(obs_comments.one?)
    assert(obs_comments.where(Comment[:summary] =~ /^iNat Data/).present?,
           "Missing Initial Commment (#{:inat_data_comment.l})")
  end

  def test_import_job_obs_with_one_photo
    # This obs has 1 identification, 1 photo, 0 observation_fields
    file_name = "evernia"
    mock_inat_response = File.read("test/inat/#{file_name}.txt")
    user = users(:rolf)
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
    inat_import = InatImport.create(
      user: user, token: "MockCode",
      inat_ids: JSON.parse(mock_inat_response)["results"].first["id"],
      inat_username: JSON.
        parse(mock_inat_response)["results"].first["user"]["login"]
    )

    stub_token_requests
    stub_inat_api_request(inat_import: inat_import,
                          mock_inat_response: mock_inat_response)
    stub_inat_photo_requests(mock_inat_response)

    # Suggested by CoPilot:
    # I wnat to stub InatPhotoImporter.new,
    # but that class doesn’t have a stub method by default. Therefore:
    # Create a mock photo importer
    mock_photo_importer = Minitest::Mock.new
    mock_photo_importer.expect(
      :new, nil,
      [{ api: MockImageAPI.new(errors: [], results: [Image.first]) }]
    )
    mock_photo_importer.expect(
      :api, # nil,
      MockImageAPI.new(errors: [], results: [Image.first])
    )
    # Stub the InatPhotoImporter class to return the mock_photo_importer
    InatPhotoImporter.stub(:new, mock_photo_importer) do
      InatImportJob.perform_now(inat_import)
    end

    obs = Observation.order(created_at: :asc).last
    assert_not_nil(obs.rss_log)
    assert_equal("mo_inat_import", obs.source)

    assert_equal(name, obs.name)

    namings = obs.namings
    naming = namings.find_by(name: name)
    assert(naming.present?, "Missing Naming for MO consensus ID")
    assert_equal(inat_manager, naming.user,
                 "Namings should belong to inat_manager")
    vote = Vote.find_by(naming: naming, user: naming.user)
    assert(vote.present?, "Naming is missing a Vote")
    assert(vote.value.positive?, "Vote for MO consensus should be positive")

    assert_equal(loc, obs.location)
    assert(obs.comments.any?, "Imported iNat should have >= 1 Comment")
    obs_comments =
      Comment.where(target_type: "Observation", target_id: obs.id)
    assert(obs_comments.one?)
    assert(obs_comments.where(Comment[:summary] =~ /^iNat Data/).present?,
           "Missing Initial Commment (#{:inat_data_comment.l})")
    assert_equal(
      users(:webmaster), obs_comments.first.user,
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

      assert_equal(1, obs.images.length, "Obs should have 1 image")
      assert(obs.sequences.none?)
    end
  end

  def test_import_job_obs_with_many_namings
    file_name = "tremella_mesenterica"
    mock_inat_response = File.read("test/inat/#{file_name}.txt")
    user = users(:rolf)
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

    inat_import = InatImport.create(
      user: user, token: "MockCode",
      inat_ids: JSON.parse(mock_inat_response)["results"].first["id"],
      inat_username: JSON.
        parse(mock_inat_response)["results"].first["user"]["login"]
    )

    stub_token_requests
    stub_inat_api_request(inat_import: inat_import,
                          mock_inat_response: mock_inat_response)
    stub_inat_photo_requests(mock_inat_response)

    # Suggested by CoPilot:
    # I wnat to stub InatPhotoImporter.new,
    # but that class doesn’t have a stub method by default. Therefore:
    # Create a mock photo importer
    mock_photo_importer = Minitest::Mock.new
    mock_photo_importer.expect(
      :new, nil,
      [{ api: MockImageAPI.new(errors: [], results: [Image.first]) }]
    )
    mock_photo_importer.expect(
      :api, # nil,
      MockImageAPI.new(errors: [], results: [Image.first])
    )

    # Stub the InatPhotoImporter class to return the mock_photo_importer
    InatPhotoImporter.stub(:new, mock_photo_importer) do
      InatImportJob.perform_now(inat_import)
    end

    obs = Observation.order(created_at: :asc).last
    assert_not_nil(obs.rss_log)

    assert_equal(name, obs.name)

    namings = obs.namings
    naming = namings.find_by(name: name)
    assert(naming.present?, "Missing Naming for MO consensus ID")
    assert_equal(
      inat_manager, naming.user,
      "Naming without iNat ID should have `user: inat_manager`"
    )
    vote = Vote.find_by(naming: naming, user: naming.user)
    assert(vote.present?, "Naming is missing a Vote")
    assert(vote.value.positive?, "Vote for MO consensus should be positive")

    naming = namings.find_by(name: t_mesenterica)
    assert(naming.present?,
           "Missing Naming for iNat identification by MO User")
    assert_equal(inat_manager, naming.user, "Naming has wrong User")
    vote = Vote.find_by(naming: naming, user: naming.user)
    assert(vote.present?, "Naming is missing a Vote")
    assert_equal(0, vote.value, "Vote for non-consensus name should be 0")

    naming = namings.find_by(name: n_aurantia)
    assert(naming.present?,
           "Missing Naming for iNat identification by random iNat user")
    assert_equal(inat_manager, naming.user, "Naming has wrong User")
    vote = Vote.find_by(naming: naming, user: naming.user)
    assert(vote.present?, "Naming is missing a Vote")
    assert_equal(0, vote.value, "Vote for non-consensus name should be 0")

    obs_comments =
      Comment.where(target_type: "Observation", target_id: obs.id)
    assert(obs_comments.one?)
    assert(obs_comments.where(Comment[:summary] =~ /^iNat Data/).present?,
           "Missing Initial Commment (#{:inat_data_comment.l})")
    assert_equal(
      users(:webmaster), obs_comments.first.user,
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

    assert(obs.images.any?, "Obs should have images")
    assert(obs.sequences.none?)
  end

  ########## Utilities

  def import_mock_observation(filename)
    user = users(:rolf)
    mock_search_result = File.read("test/inat/#{filename}.txt")
    inat_obs = InatObs.new(
      JSON.generate(
        JSON.parse(mock_search_result)["results"].first
      )
    )
    inat_import_ids = inat_obs.inat_id

    simulate_all_inat_interactions(
      user: user, inat_username: inat_obs.inat_user_login,
      inat_import_ids: inat_import_ids,
      mock_inat_response: mock_search_result
    )

    # params = { inat_ids: inat_import_ids, code: "MockCode" }
    # login(user.login)

    inat_import = InatImport.create(
      user: user,
      token: "MockCode",
      state: 3, # "Authenticating"
      inat_ids: inat_import_ids,
      inat_username: inat_obs.inat_user_login
    )

    # NOTE: Stubs the importer's return value, but not its side-effect --
    # i.e., doesn't add Image(s) to the MO Observation.
    # Enables testing everything except Observation.images. jdc 2024-06-23
    #
    # InatPhotoImporter.stub(:new, mock_photo_importer(inat_obs, inat_import)) do
    assert_difference("Observation.count", 1, "Failed to create Obs") do
      InatImportJob.perform_now(inat_import)
    end
    # end

    Observation.order(created_at: :asc).last
  end

  def simulate_all_inat_interactions(
    mock_inat_response:, user: users(:rolf), inat_username: nil,
    inat_import_ids: "",
    import_all: false, id_above: 0
  )
    simulate_inat_accredications(
      user: user, inat_username: inat_username,
      inat_import_ids: inat_import_ids, import_all: import_all
    )
    stub_inat_api_request(inat_import_ids, mock_inat_response,
                          id_above: id_above,
                          inat_user_login: inat_username)
    # stub_inat_photo_requests(mock_inat_response)
  end

  def simulate_inat_accredications(
    user: users(:rolf), inat_username: nil, inat_import_ids: "",
    import_all: false
  )
    simulate_authorization(
      user: user, inat_username: inat_username,
      inat_import_ids: inat_import_ids, import_all: import_all
    )
    stub_token_requests
  end

  def simulate_authorization(
    user: users(:rolf), inat_username: nil, inat_import_ids: "",
    import_all: false
  )
    inat_import = InatImport.find_or_create_by(user: user)
    inat_import.import_all = import_all
    # ignore list of ids if importing all a user's iNat obss
    inat_import.inat_ids = import_all == true ? "" : inat_import_ids
    inat_import.state = "Authorizing"
    inat_import.inat_username = inat_username
    inat_import.save
    stub_request(:any, authorization_url)
  end

  # iNat url where user is sent in order to authorize MO access
  # to iNat confidential data
  # https://www.inaturalist.org/pages/api+reference#authorization_code_flow
  def authorization_url
    "https://www.inaturalist.org/oauthenticate/authorize?" \
    "client_id=#{Rails.application.credentials.inat.id}" \
    "&redirect_uri=#{REDIRECT_URI}" \
    "&response_type=code"
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

  # TODO: add an image param
  # for 1st draft return any old Image
  def stub_mo_image_api
    api = MockImageAPI.new(errors: [], results: [Image.first])
    mock_photo_importer = MockPhotoImporter.new(api: api)
    InatPhotoImporter.stub(:new, mock_photo_importer)
  end

  def old_mock_photo_importer(inat_obs, inat_import)
    # TODO: probably delete this. It looks like a hodgepodge of nonsense
    debugger
    return

    mock_inat_photo = inat_obs.inat_obs_photos.first
    mock_image_api = MockImageAPI.new(
      results: [
        expected_mo_image(mock_inat_photo: mock_inat_photo,
                          user: inat_import.user)
      ]
    )
    mock_photo_importer = Minitest::Mock.new
    inat_obs.inat_obs_photos.length.times do
      mock_photo_importer.expect(:api, mock_image_api)
    end
    mock_photo_importer
  end

  def expected_mo_image(mock_inat_photo:, user:)
    Image.create(
      content_type: "image/jpeg",
      user_id: user.id,
      notes: "Imported from iNat " \
             "#{DateTime.now.utc.strftime("%Y-%m-%d %H:%M:%S %z")}",
      copyright_holder: mock_inat_photo[:photo][:attribution],
      license_id: expected_mo_photo_license(mock_inat_photo),
      width: 2048,
      height: 1534,
      original_name: "iNat photo uuid #{mock_inat_photo[:uuid]}"
    )
  end

  def expected_mo_photo_license(mock_inat_photo)
    InatLicense.new(mock_inat_photo[:photo][:license_code]).
      mo_license.id
  end

  def result_without_photos(mock_search_result)
    ms_hash = JSON.parse(mock_search_result)
    ms_hash["results"].each do |result|
      result["observation_photos"] = []
      result["photos"] = []
    end
    JSON.generate(ms_hash)
  end

  # Turn results with many pages into results with one page
  # By ignoring all pages but the first
  def limited_to_first_page(mock_search_result)
    ms_hash = JSON.parse(mock_search_result)
    ms_hash["total_results"] = ms_hash["results"].length
    JSON.generate(ms_hash)
  end

  def inat_manager
    User.find_by(login: "MO Webmaster")
  end
end
