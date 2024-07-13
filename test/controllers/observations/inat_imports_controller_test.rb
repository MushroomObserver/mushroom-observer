# frozen_string_literal: true

require "test_helper"

# test importing iNaturalist Observations to Mushroom Observer
module Observations
  # a duck type of API2::ImageAPI with enough attributes
  # to preventInatsImportController from throwing an error
  class MockApi
    attr_reader :errors, :results

    def initialize(errors: [], results: [])
      @errors = errors
      @results = results
    end
  end

  class InatImportsControllerTest < FunctionalTestCase
    INAT_OBS_REQUEST_PREFIX = "https://api.inaturalist.org/v1/observations?"
    INAT_OBS_REQUEST_POSTFIX = "&order=desc&order_by=created_at&only_id=false"

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

    def test_create_import_no_consent
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

    def test_authenticate
      skip("Under construction")
      user = users(:rolf)

      login(user.login)
      post(:auth)

      assert_response(:success)
    end

    def test_create_import_evernia_no_photos
      skip("Under construction, Should call `auth`, not create")
      mock_inat_response =
        File.read("test/inat/evernia_no_photos.txt")
      inat_obs_id = InatObs.new(mock_inat_response).inat_id
      params = { inat_ids: inat_obs_id }

      stub_inat_api_request(inat_obs_id, mock_inat_response)

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
      mock_api = MockApi.new(
        results: [
          expected_mo_image(mock_inat_photo: mock_inat_photo,
                            user: User.current)
        ]
      )
      mock_photo_importer = Minitest::Mock.new
      inat_obs.inat_obs_photos.length.times do
        mock_photo_importer.expect(:api, mock_api)
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
  end
end
