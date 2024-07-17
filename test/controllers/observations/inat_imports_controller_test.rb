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
    INAT_OBS_REQUEST_PREFIX = "https://api.inaturalist.org/v1/observations?"
    INAT_OBS_REQUEST_POSTFIX = "&order=desc&order_by=created_at&only_id=false"
    # Where iNat will send the code once authorized
    REDIRECT_URI = "http://localhost:3000/observations/inat_imports/auth"

    def test_new_inat_import
      login(users(:rolf).login)
      get(:new)

      assert_response(:success)
      assert_form_action(action: :create)
      assert_select("input#inat_ids", true,
                    "Form needs a field for inputting iNat ids")
      assert_select("input[type=checkbox][id=consent]", true,
                    "Form needs checkbox requiring consent")
    end

    def test_create_inat_import_authorization_request
      user = users(:rolf)
      inat_import = inat_imports(:rolf_inat_import)
      assert_equal("Unstarted", inat_import.state,
                   "Need a Unstarted inat_import fixture")

      stub_request(:any, authorization_url)
      login(user.login)

      assert_no_difference(
        "Observation.count",
        "Authorization request to iNat shouldn't create MO Observation(s)"
      ) do
        post(:create, params: { inat_ids: 123_456_789, consent: 1 })
      end

      assert_response(:redirect)
      assert_equal("Authorizing", inat_import.reload.state,
                   "MO should be awaiting authorization from iNat")
    end

    def test_create_inat_import_no_consent
      mock_inat_response =
        File.read("test/inat/evernia_no_photos.txt")
      inat_obs_id = InatObs.new(mock_inat_response).inat_id
      # TODO: remove consent key after creating model with default consent
      params = { inat_ids: inat_obs_id, consent: 0 }

      stub_inat_api_request(inat_obs_id, mock_inat_response)

      login

      assert_no_difference("Observation.count",
                           "iNat obss imported without consent") do
        put(:create, params: params)
      end

      assert_flash_warning
    end

    def test_create_inat_import_too_many_ids
      user = users(:rolf)
      params = { inat_ids: "12345 6789" }

      login(user.login)
      put(:create, params: params)

      assert_flash_text(:inat_not_single_id.l)
      assert_form_action(action: :create)
    end

    def test_create_inat_import_bad_inat_id
      user = users(:rolf)
      id = "badID"
      params = { inat_ids: id }

      login(user.login)
      put(:create, params: params)

      assert_flash_text(:runtime_illegal_inat_id.l(id: id))
      assert_form_action(action: :create)
    end

    def test_create_inat_import_authorization_denied
      inat_authorization_callback_params =
        { error: "access_denied",
          error_description: "The resource owner or authorization server " \
                             "denied the request." }
      login

      get(:auth, params: inat_authorization_callback_params)

      assert_redirected_to(observations_path)
      assert_flash_error
    end

    def test_create_inat_import_authorized
      user = users(:rolf)
      inat_import = inat_imports(:rolf_inat_import)

      # A blank list to test `auth` without importing anything.
      inat_import.inat_ids = ""
      inat_import.save
      inat_authorization_callback_params = { code: "MockCode" }

      stub_request(:post, "https://www.inaturalist.org/oauth/token").
        with(
          body: { "client_id" => Rails.application.credentials.inat.id,
                  "client_secret" => Rails.application.credentials.inat.secret,
                  "code" => "MockCode",
                  "grant_type" => "authorization_code",
                  "redirect_uri" => REDIRECT_URI }
        ).
        to_return(status: 200, body: "MockToken", headers: {})

      login(user.login)
      get(:auth, params: inat_authorization_callback_params)

      assert_redirected_to(observations_path)
    end

    def test_create_import_evernia_no_photos
      skip("Under construction, Should call `auth`, not create")
      mock_inat_response =
        File.read("test/inat/evernia_no_photos.txt")
      inat_obs_id = InatObs.new(mock_inat_response).inat_id
      stub_inat_api_request(inat_obs_id, mock_inat_response)

      stub_request(:any, authorization_url)

      params = { inat_ids: inat_obs_id }
      login

      assert_difference("Observation.count", 1, "Failed to create Obs") do
        put(:create, params: params)
      end

      obs = Observation.order(created_at: :asc).last
      assert_not_nil(obs.rss_log)
      assert_redirected_to(observations_path)

      assert_equal("mo_inat_import", obs.source)
      assert_equal(inat_obs_id, obs.inat_id)

      assert_equal(0, obs.images.length, "Obs should not have 0 images")

      assert(obs.comments.any?, "Imported iNat should have >= 1 Comment")
      obs_comments =
        Comment.where(target_type: "Observation", target_id: obs.id)
      assert(obs_comments.one?)
      assert(obs_comments.where(Comment[:summary] =~ /^iNat Data/).present?,
             "Missing Initial Commment (#{:inat_data_comment.l})")
    end

    def test_create_obs_tremella_mesenterica
      skip("Under construction, Should call `auth`, not create")
      obs = import_mock_observation("tremella_mesenterica")

      assert_not_nil(obs.rss_log)
      assert_redirected_to(observations_path)

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

    def test_create_obs_lycoperdon
      skip("Under construction, Should call `auth`, not create")
      obs = import_mock_observation("lycoperdon")

      assert(obs.images.any?, "Obs should have images")
      assert(obs.sequences.one?, "Obs should have a sequence")
    end

    def test_create_import_plant
      skip("Under construction, Should call `auth`, not create")
      # See test/inat/README_INAT_FIXTURES.md
      mock_inat_response =
        File.read("test/inat/ceanothus_cordulatus.txt")
      inat_obs = InatObs.new(mock_inat_response)
      inat_obs_id = inat_obs.inat_id
      params = { inat_ids: inat_obs_id }

      stub_inat_api_request(inat_obs_id, mock_inat_response)

      login

      assert_no_difference(
        "Observation.count", "Should not import iNat Plant observations"
      ) do
        put(:create, params: params)
      end

      assert_flash_text(:inat_taxon_not_importable.l(id: inat_obs_id))
    end

    def import_mock_observation(filename)
      user = users(:rolf)
      mock_inat_response = File.read("test/inat/#{filename}.txt")
      inat_obs = InatObs.new(mock_inat_response)
      inat_obs_id = inat_obs.inat_id

      stub_inat_api_request(inat_obs_id, mock_inat_response)

      login(user.login)

      # NOTE: Stubs the importer's return value, but not its side-effect --
      # i.e., doesn't add Image(s) to the MO Observation.
      # Enables testing everything except Observation.images. jdc 2024-06-23
      InatPhotoImporter.stub(:new, mock_photo_importer(inat_obs)) do
        assert_difference("Observation.count", 1, "Failed to create Obs") do
          post(:create, params: { inat_ids: inat_obs_id })
        end
      end

      Observation.order(created_at: :asc).last
    end

    def stub_inat_api_request(inat_obs_id, mock_inat_response)
      WebMock.stub_request(
        :get,
        "#{INAT_OBS_REQUEST_PREFIX}id=#{inat_obs_id}" \
          "#{INAT_OBS_REQUEST_POSTFIX}"
      ).to_return(body: mock_inat_response)
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

    def authorization_url
      "https://www.inaturalist.org/oauth/authorize?" \
      "client_id=#{Rails.application.credentials.inat.id}" \
      "&redirect_uri=http://localhost:3000/observations/inat_imports/auth" \
      "&response_type=code"
    end
  end
end
