# frozen_string_literal: true

require "test_helper"

# test importing iNaturalist Observations to Mushroom Observer
module Observations
  # a duck type of API2::ImageAPI with enough attributes
  # to preventInatsImportController from throwing an error
  class MockImageAPI
    attr_reader :errors, :results

    def initialize(errors: [], results: [])
      @errors = errors
      @results = results
    end
  end

  class InatImportsControllerTest < FunctionalTestCase
    INAT_OBS_REQUEST_PREFIX = "https://api.inaturalist.org/v1/observations"
    INAT_OBS_REQUEST_POSTFIX = "&order=asc&order_by=id&only_id=false"
    # Where iNat will send the code once authorized
    REDIRECT_URI =
      "http://localhost:3000/observations/inat_imports/authenticate"

    def test_new_inat_import
      login(users(:rolf).login)
      get(:new)

      assert_response(:success)
      assert_form_action(action: :create)
      assert_select("input#inat_ids", true,
                    "Form needs a field for inputting iNat ids")
      assert_select("input#inat_username", true,
                    "Form needs a field for inputting iNat username")
      assert_select("input[type=checkbox][id=all]", true,
                    "Form needs checkbox for importing all a user's iNat obss")
      assert_select("input[type=checkbox][id=consent]", true,
                    "Form needs checkbox requiring consent")
    end

    def test_create_missing_username
      user = users(:rolf)
      id = "123"
      params = { inat_ids: id }

      login(user.login)
      post(:create, params: params)

      assert_flash_text(:inat_missing_username.l)
      assert_form_action(action: :create)
    end

    def test_create_no_observations_designated
      params = { inat_username: "anything", inat_ids: "",
                 consent: 1 }
      login
      assert_no_difference("Observation.count",
                           "Imported observation(s) though none designated") do
        post(:create, params: params)
      end

      assert_flash_text(:inat_no_imports_designated.l)
    end

    def test_create_illega_observation_id
      params = { inat_username: "anything", inat_ids: "123*",
                 consent: 1 }
      login
      assert_no_difference("Observation.count",
                           "Imported observation(s) though none designated") do
        post(:create, params: params)
      end

      assert_flash_text(:runtime_illegal_inat_id.l)
    end

    def test_create_no_consent
      params = { inat_username: "anything", inat_ids: 123,
                 consent: 0 }
      login
      assert_no_difference("Observation.count",
                           "iNat obss imported without consent") do
        post(:create, params: params)
      end

      assert_flash_text(:inat_consent_required.l)
    end

    def test_create_authorization_request
      user = users(:rolf)
      inat_username = "rolf"
      inat_import = inat_imports(:rolf_inat_import)
      assert_equal("Unstarted", inat_import.state,
                   "Need a Unstarted inat_import fixture")

      stub_request(:any, authorization_url)
      login(user.login)

      assert_no_difference(
        "Observation.count",
        "Authorization request to iNat shouldn't create MO Observation(s)"
      ) do
        post(:create,
             params: { inat_ids: 123_456_789, inat_username: inat_username,
                       consent: 1 })
      end

      assert_response(:redirect)
      assert_equal("Authorizing", inat_import.reload.state,
                   "MO should be awaiting authorization from iNat")
      assert_equal(inat_username, inat_import.inat_username,
                   "Failed to save InatImport.inat_username")
    end

    def test_import_authorization_denied
      inat_authorization_callback_params =
        { error: "access_denied",
          error_description: "The resource owner or authorization server " \
                             "denied the request." }
      login

      get(:authenticate, params: inat_authorization_callback_params)

      assert_redirected_to(observations_path)
      assert_flash_error
    end

    def test_import_authorized
      user = users(:rolf)
      inat_import = inat_imports(:rolf_inat_import)

      # A blank list to test `authenticate` without importing anything.
      inat_import.inat_ids = ""
      inat_import.save
      inat_authorization_callback_params = { code: "MockCode" }

      stub_access_token_request
      stub_jwt_request
      login(user.login)
      get(:authenticate, params: inat_authorization_callback_params)

      assert_redirected_to(observations_path)
    end

    def test_import_evernia
      user = rolf
      loc = Location.create(
        user: user,
        name: "Troutdale, Multnomah Co., Oregon, USA",
        north: 45.5609,
        south: 45.5064,
        east: -122.367,
        west: -122.431
      )
      evernia = Name.create(text_name: "Evernia",
                            author: "Ach.",
                            display_name: "Evernia",
                            rank: "Genus",
                            user: user)

      obs = import_mock_observation("evernia")

      assert_not_nil(obs.rss_log)
      assert_redirected_to(observations_path)

      assert_equal(evernia, obs.name)
      namings = obs.namings
      naming = namings.find_by(name: evernia)
      assert(naming.present?, "Missing Naming for MO consensus ID")
      assert_equal(user, naming.user,
                   "Naming with iNat ID should have user == MO User")
      vote = Vote.find_by(naming: naming, user: naming.user)
      assert(vote.present?, "Naming is missing a Vote")
      assert(vote.value.positive?, "Vote for MO consensus should be positive")

      assert_equal("mo_inat_import", obs.source)
      assert_equal(1, obs.images.length, "Obs should have 1 image")
      assert_equal(loc, obs.location)
      assert(obs.comments.any?, "Imported iNat should have >= 1 Comment")
      obs_comments =
        Comment.where(target_type: "Observation", target_id: obs.id)
      assert(obs_comments.one?)
      assert(obs_comments.where(Comment[:summary] =~ /^iNat Data/).present?,
             "Missing Initial Commment (#{:inat_data_comment.l})")
    end

    def test_import_tremella_mesenterica
      # This iNat obs has two identifications:
      # Tremella mesenterica, which in is fixtures
      t_mesenterica = Name.find_by(text_name: "Tremella mesenterica")
      # "Naematelia aurantia, which is not
      n_aurantia = Name.create(text_name: "Naematelia aurantia",
                               author: "(Schwein.) Burt",
                               display_name: "Naematelia aurantia",
                               rank: "Species",
                               user: rolf)
      # iNat Community Taxon, which is not an identification for this iNat obs
      tremellales = Name.create(text_name: "Tremellales",
                                author: "Fr.",
                                display_name: "Tremellales",
                                rank: "Order",
                                user: rolf)

      obs = import_mock_observation("tremella_mesenterica")

      assert_not_nil(obs.rss_log)
      assert_redirected_to(observations_path)

      assert_equal(tremellales, obs.name)

      namings = obs.namings
      naming = namings.find_by(name: tremellales)
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
      assert_equal(User.current, naming.user, "Naming has wrong User")
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

    def test_import_lycoperdon
      obs = import_mock_observation("lycoperdon")

      assert(obs.images.any?, "Obs should have images")
      assert(obs.sequences.one?, "Obs should have a sequence")
    end

    # Prove that Namings, Votes, Identification are correct
    # When iNat obs has provisional name that's in MO
    def test_import_arrhenia_sp_ny02_old_name
      name = Name.create(
        text_name: 'Arrhenia "sp-NY02"',
        author: "S.D. Russell crypt. temp.",
        display_name: '**__Arrhenia "sp-NY02"__** S.D. Russell crypt. temp.',
        rank: "Species",
        user: rolf
      )

      obs = import_mock_observation("arrhenia_sp_NY02")

      namings = obs.namings
      naming = namings.find_by(name: name)
      assert(naming.present?, "Missing Naming for provisional name")
      assert_equal(inat_manager, naming.user,
                   "Naming without iNat ID should have user: inat_manager")
      vote = Vote.find_by(naming: naming, user: naming.user)
      assert(vote.present?, "Naming is missing a Vote")
      assert_equal(name, obs.name, "Consensus ID should be provisional name")
      assert(vote.value.positive?, "Vote for MO consensus should be positive")
    end

    # Prove that Namings, Votes, Identification are correct
    # when iNat obs has provisional name that wasn't in MO
    def test_import_arrhenia_sp_ny02_new_name
      assert_nil(Name.find_by(text_name: 'Arrhenia "sp-NY02"'),
                 "Test requires that MO not yest have provisional name")

      obs = import_mock_observation("arrhenia_sp_NY02")

      name = Name.find_by(text_name: 'Arrhenia "sp-NY02"')
      assert(name.rss_log_id.present?)

      assert(name.present?, "Failed to create provisional name")
      namings = obs.namings
      naming = namings.find_by(name: name)
      assert(naming.present?, "Missing Naming for provisional name")
      assert_equal(inat_manager, naming.user,
                   "Naming without iNat ID should have user: inat_manager")
      vote = Vote.find_by(naming: naming, user: naming.user)
      assert(vote.present?, "Naming is missing a Vote")
      assert_equal(name, obs.name, "Consensus ID should be provisional name")
      assert(vote.value.positive?, "Vote for MO consensus should be positive")
    end

    def test_import_plant
      user = rolf
      filename = "ceanothus_cordulatus"
      mock_search_result = File.read("test/inat/#{filename}.txt")
      inat_import_ids = InatObs.new(
        JSON.generate(JSON.parse(mock_search_result)["results"].first)
      ).inat_id

      stub_inat_api_request(inat_import_ids, mock_search_result)
      simulate_authorization(user: user, inat_import_ids: inat_import_ids)
      stub_access_token_request
      stub_jwt_request

      params = { inat_ids: inat_import_ids, code: "MockCode" }
      login(user.login)

      assert_no_difference(
        "Observation.count", "Should not import iNat Plant observations"
      ) do
        post(:authenticate, params: params)
      end

      assert_flash_text(:inat_taxon_not_importable.l(id: inat_import_ids))
    end

    def test_import_zero_results
      user = rolf
      filename = "zero_results"
      mock_search_result = File.read("test/inat/#{filename}.txt")
      inat_import_ids = "123"

      stub_inat_api_request(inat_import_ids, mock_search_result)
      simulate_authorization(user: user, inat_import_ids: inat_import_ids)
      stub_access_token_request
      stub_jwt_request

      params = { inat_ids: inat_import_ids, code: "MockCode" }
      login(user.login)

      assert_no_difference(
        "Observation.count",
        "Should not import if there's no iNat obs with a matching id"
      ) do
        post(:authenticate, params: params)
      end
    end

    def test_import_multiple
      # NOTE: using obss without photos to avoid stubbing photo import
      # amanita_flavorubens, calostoma lutescens
      inat_obss = "231104466,195434438"
      inat_import_ids = inat_obss
      user = users(:rolf)
      filename = "listed_ids"
      mock_inat_response = File.read("test/inat/#{filename}.txt")
      # prove that mock was constructed properly
      json = JSON.parse(mock_inat_response)
      assert_equal(2, json["total_results"])
      assert_equal(1, json["page"])
      assert_equal(30, json["per_page"])
      # mock is sorted by id, asc
      assert_equal(195_434_438, json["results"].first["id"])
      assert_equal(231_104_466, json["results"].second["id"])

      simulate_authorization(user: user, inat_import_ids: inat_import_ids)
      stub_access_token_request
      stub_jwt_request
      stub_inat_api_request(inat_import_ids, mock_inat_response)

      params = { inat_ids: inat_import_ids, code: "MockCode" }
      login(user.login)

      assert_difference(
        "Observation.count", 2, "Failed to create multiple observations"
      ) do
        post(:authenticate, params: params)
      end
    end

    def test_import_all
      user = users(:rolf)
      login(user.login)

      filename = "import_all"
      mock_search_result = File.read("test/inat/#{filename}.txt")
      # shorten it to one page to avoid stubbing multiple inat api requests
      mock_search_result = limited_to_first_page(mock_search_result)
      # delete the photos in order to avoid stubbing photo imports
      mock_search_result = result_without_photos(mock_search_result)

      inat_import_ids = ""

      simulate_authorization(user: user, inat_import_ids: inat_import_ids,
                             import_all: true)
      stub_access_token_request
      stub_jwt_request
      stub_inat_api_request(inat_import_ids, mock_search_result)

      params = { inat_ids: inat_import_ids, code: "MockCode" }

      assert_difference(
        "Observation.count", 2, "Failed to create multiple observations"
      ) do
        post(:authenticate, params: params)
      end
    end

    def inat_manager
      User.find_by(login: "MO Webmaster")
    end

    # Turn results with many pages into results with one page
    # By ignoring all pages but the first
    def limited_to_first_page(mock_search_result)
      ms_hash = JSON.parse(mock_search_result)
      ms_hash["total_results"] = ms_hash["results"].length
      JSON.generate(ms_hash)
    end

    def import_mock_observation(filename)
      user = users(:rolf)
      mock_search_result = File.read("test/inat/#{filename}.txt")
      inat_obs = InatObs.new(
        JSON.generate(
          JSON.parse(mock_search_result)["results"].first
        )
      )
      inat_import_ids = inat_obs.inat_id

      simulate_authorization(user: user,
                             inat_username: inat_obs.inat_user_login,
                             inat_import_ids: inat_import_ids)
      stub_access_token_request
      stub_jwt_request
      stub_inat_api_request(inat_import_ids, mock_search_result,
                            inat_user_login: inat_obs.inat_user_login)

      params = { inat_ids: inat_import_ids, code: "MockCode" }
      login(user.login)

      # NOTE: Stubs the importer's return value, but not its side-effect --
      # i.e., doesn't add Image(s) to the MO Observation.
      # Enables testing everything except Observation.images. jdc 2024-06-23
      InatPhotoImporter.stub(:new, mock_photo_importer(inat_obs)) do
        assert_difference("Observation.count", 1, "Failed to create Obs") do
          post(:authenticate, params: params)
        end
      end

      Observation.order(created_at: :asc).last
    end

    def stub_inat_api_request(inat_obs_ids, mock_inat_response, id_above: 0,
                              inat_user_login: nil)
      # params must be in same order as in the controller
      # omit trailing "=" since the controller omits it (via `merge`)
      params = <<~PARAMS.delete("\n").chomp("=")
        ?iconic_taxa=#{Observations::InatImportsController::ICONIC_TAXA}
        &id=#{inat_obs_ids}
        &id_above=#{id_above}
        &per_page=200
        &only_id=false
        &order=asc&order_by=id
        &user_login=#{inat_user_login}
      PARAMS
      stub_request(:get, "#{INAT_OBS_REQUEST_PREFIX}#{params}").
        with(headers:
        { "Accept" => "application/json",
          "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
          "Authorization" => "Bearer",
          "Host" => "api.inaturalist.org" }).
        to_return(body: mock_inat_response)
    end

    def mock_photo_importer(inat_obs)
      mock_inat_photo = inat_obs.inat_obs_photos.first
      mock_image_api = MockImageAPI.new(
        results: [
          expected_mo_image(mock_inat_photo: mock_inat_photo,
                            user: User.current)
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

    def simulate_authorization(
      user: rolf, inat_username: nil, inat_import_ids: "", import_all: false
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

    # stub exchanging iNat code for oauth token
    # https://www.inaturalist.org/pages/api+reference#authorization_code_flow
    def stub_access_token_request
      stub_request(:post, "https://www.inaturalist.org/oauth/token").
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
      stub_request(:get, "https://www.inaturalist.org/users/api_token").
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

    def result_without_photos(mock_search_result)
      ms_hash = JSON.parse(mock_search_result)
      ms_hash["results"].each do |result|
        result["observation_photos"] = []
        result["photos"] = []
      end
      JSON.generate(ms_hash)
    end
  end
end
