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
    end

    def test_create_public_import_imageless_obs
      # See test/inat/README_INAT_FIXTURES.md
      mock_inat_response =
        File.read("test/inat/evernia_no_photos.txt")
      inat_id = InatObs.new(mock_inat_response).inat_id
      params = { inat_ids: inat_id }

      WebMock.stub_request(
        :get,
        "#{INAT_OBS_REQUEST_PREFIX}id=#{inat_id}#{INAT_OBS_REQUEST_POSTFIX}"
      ).to_return(body: mock_inat_response)

      login

      assert_difference("Observation.count", 1, "Failed to create Obs") do
        put(:create, params: params)
      end

      obs = Observation.order(created_at: :asc).last
      assert_not_nil(obs.rss_log)
      assert_redirected_to(observations_path)

      assert_equal("mo_inat_import", obs.source)
      assert_equal(inat_id, obs.inat_id)

      assert(obs.comments.any?, "Imported iNat should have >= 1 Comment")
    end

    def test_create_obs_with_photo
      # stub the iNat API request for the iNat observation
      mock_inat_response = File.read("test/inat/tremella_mesenterica.txt")
      inat_obs = InatObs.new(mock_inat_response)
      inat_obs_id = inat_obs.inat_id
      WebMock.stub_request(
        :get,
        "#{INAT_OBS_REQUEST_PREFIX}id=#{inat_obs_id}#{INAT_OBS_REQUEST_POSTFIX}"
      ).to_return(body: mock_inat_response)

      # prepare to stub InatPhotoImporter
      user = users(:rolf)
      expected_mo_img = Image.create(
        content_type: "image/jpeg",
        user_id: user.id,
        notes: "Imported from iNat " \
               "#{DateTime.now.utc.strftime("%Y-%m-%d %H:%M:%S %z")}",
        copyright_holder: "(c) Tim C., some rights reserved (CC BY-NC)",
        license_id: 6,
        width: 2048,
        height: 1534,
        original_name: "iNat photo uuid 6c223538-04d6-404c-8e84-b7d881dbe550"
      )
      mock_api = MockApi.new(results: [expected_mo_img])
      mock_importer = Minitest::Mock.new
      mock_importer.expect(:api, mock_api)

      # NOTE: This stubs the InatPhotoImporter's return value,
      # but doesn't add an Image to the MO Observation.
      # Enables testing everything except Observation.images. jdc 2024-06-23
      InatPhotoImporter.stub(:new, mock_importer) do
        login(user.login)

        assert_difference("Observation.count", 1, "Failed to create Obs") do
          post(:create, params: { inat_ids: inat_obs_id })
        end
      end

      obs = Observation.order(created_at: :asc).last
      assert_not_nil(obs.rss_log)
      assert_redirected_to(observations_path)

      inat_data_comment =
        Comment.where(target_type: "Observation", target_id: obs.id).
        where(Comment[:summary] =~ /^Inat Data/)
      assert(inat_data_comment.one?)
      comment = inat_data_comment.first.comment
      [
        :USER.l, :OBSERVED.l, :LAT_LON.l, :PLACE.l, :ID.l, :DQA.l,
        :ANNOTATIONS.l, :PROJECTS.l, :SEQUENCES.l, :OBSERVATION_FIELDS.l,
        :TAGS.l
      ].each do |caption|
        assert_match(
          /#{caption}/, comment,
          "Initial Commment (#{:inat_data_comment.l}) is missing #{caption}"
        )
      end

      assert(obs.sequences.none?)
    end

    def test_create_import_plant
      # See test/inat/README_INAT_FIXTURES.md
      mock_inat_response =
        File.read("test/inat/ceanothus_cordulatus.txt")
      inat_id = InatObs.new(mock_inat_response).inat_id
      params = { inat_ids: inat_id }

      WebMock.stub_request(
        :get,
        "#{INAT_OBS_REQUEST_PREFIX}id=#{inat_id}#{INAT_OBS_REQUEST_POSTFIX}"
      ).to_return(body: mock_inat_response)

      login

      assert_no_difference(
        "Observation.count", "Should not import iNat Plant observations"
      ) do
        put(:create, params: params)
      end

      assert_flash_text(:inat_taxon_not_importable.l(id: inat_id))
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
  end
end

# rubocop:disable Layout/LineLength
=begin # rubocop:disable Style/BlockComments
# Dump of what InatPhotoImporter returned in real life:
#<InatPhotoImporter:0x000000013b2d3ae8
 @api=
  #<API2::ImageAPI:0x0000000139755aa0
   @action=:image,
   @api_key=
    #<APIKey:0x00000001367dfdc0
     id: 1375,
     created_at: Tue, 18 Jun 2024 09:11:52.000000000 PDT -07:00,
     last_used: Sat, 22 Jun 2024 19:27:31.000000000 PDT -07:00,
     num_uses: 38,
     user_id: 4468,
     key: "z7kd24s8rgf2bav56helqq6qfwck6yw5",
     notes: "inat import temp",
     verified: Tue, 18 Jun 2024 09:11:52.000000000 PDT -07:00>,
   @default_date=Sat, 22 Jun 2024,
   @detail=:none,
   @errors=[],
   @expected_params=
    {:action=>action: string,
     :detail=>detail: enum (limit=high|low|none),
     :page=>page: integer (default=1),
     :version=>version: float,
     :api_key=>api_key: string,
     :method=>method: string,
     :observations=>observations: observation list (must have edit permission),
     :vote=>vote: enum (limit=1|2|3|4),
     :upload_url=>upload_url: string,
     :upload_file=>upload_file: string,
     :upload=>upload: upload,
     :date=>date: date (when photo taken),
     :notes=>notes: string,
     :copyright_holder=>copyright_holder: string (limit=100 chars),
     :license=>license: license,
     :original_name=>original_name: string (limit=120 chars, original file name or other private identifier),
     :md5sum=>md5sum: string,
     :projects=>projects: project list (must be member)},
   @ignore_params={},
   @method=:post,
   @observations=[],
   @page_number=1,
   @params=
    {:method=>:post,
     :action=>:image,
     :api_key=>"z7kd24s8rgf2bav56helqq6qfwck6yw5",
     :upload_url=>"https://inaturalist-open-data.s3.amazonaws.com/photos/377332865/original.jpeg",
     :copyright_holder=>"(c) Tim C., some rights reserved (CC BY-NC)",
     :license=>6,
     :notes=>"Imported from iNat 2024-06-23 02:27:31 +0000",
     :original_name=>"iNat photo uuid 6c223538-04d6-404c-8e84-b7d881dbe550"},
   @result_ids=[1674373],
   @results=
    [#<Image:0x00000001367b1ce0
      id: 1674373,
      created_at: Sat, 22 Jun 2024 19:27:32.000000000 PDT -07:00,
      updated_at: Sat, 22 Jun 2024 19:27:32.000000000 PDT -07:00,
      content_type: "image/jpeg",
      user_id: 4468,
      when: Sat, 22 Jun 2024,
      notes: "Imported from iNat 2024-06-23 02:27:31 +0000",
      copyright_holder: "(c) Tim C., some rights reserved (CC BY-NC)",
      license_id: 6,
      num_views: 0,
      last_view: nil,
      width: 2048,
      height: 1534,
      vote_cache: nil,
      ok_for_export: true,
      original_name: "iNat photo uuid 6c223538-04d6-404c-8e84-b7d881dbe550",
      transferred: false,
      gps_stripped: false,
      diagnostic: true>],
   @upload=
    #<API2::Uploads::UploadFromURL:0x000000012ec44030
     @checksum=nil,
     @content=#<File:/var/folders/f3/l_l8075j5q34q70g93zvzqp80000gn/T/api_upload20240622-16108-tthjm1>,
     @content_length=2315858,
     @content_md5="",
     @content_type="image/jpeg",
     @data=nil,
     @length=nil,
     @temp_file=#<File:/var/folders/f3/l_l8075j5q34q70g93zvzqp80000gn/T/api_upload20240622-16108-tthjm1>>,
   @user=#<User 4468: "Joseph D. Cohen (Joe Cohen)">,
   @version=2.0,
   @vote=nil>>
=end
# rubocop:enable Layout/LineLength
