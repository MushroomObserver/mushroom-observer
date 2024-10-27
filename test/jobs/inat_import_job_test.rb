# frozen_string_literal: true

require "test_helper"

# Some classes with enough attributes to stub calls to Inat::PhotoImporter
#   (which wraps calls to the MO Image API)
# and get an image back like this
#  api = Inat::PhotoImporter.new(params).api
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
  IMPORTED_BY_MO = InatImportJob::IMPORTED_BY_MO

  # Prevent stubs from persisting between test methods because
  # the same request (/users/me) needs diffferent responses
  def setup
    @stubs = []
  end

  def add_stub(stub)
    @stubs << stub
    stub
  end

  def teardown
    @stubs.each do |stub|
      WebMock::StubRegistry.instance.remove_request_stub(stub)
    end
  end

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

    Inat::PhotoImporter.stub(:new,
                             stub_mo_photo_importer(mock_inat_response)) do
      assert_difference("Observation.count", 1,
                        "Failed to create observation") do
        InatImportJob.perform_now(inat_import)
      end
    end

    obs = Observation.order(created_at: :asc).last
    standard_assertions(obs: obs, name: name, loc: loc)
    assert_not(obs.specimen, "Obs should not have a specimen")
    assert_equal(0, obs.images.length, "Obs should not have images")
    assert_match(/Observation Fields: none/, obs.comments.first.comment,
                 "Missing 'none' for Observation Fields")
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

    Inat::PhotoImporter.stub(:new,
                             stub_mo_photo_importer(mock_inat_response)) do
      assert_difference("Observation.count", 1,
                        "Failed to create observation") do
        InatImportJob.perform_now(inat_import)
      end
    end

    obs = Observation.order(created_at: :asc).last
    standard_assertions(obs: obs, name: name, loc: loc)
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

    Inat::PhotoImporter.stub(:new,
                             stub_mo_photo_importer(mock_inat_response)) do
      assert_difference("Observation.count", 1,
                        "Failed to create observation") do
        InatImportJob.perform_now(inat_import)
      end
    end

    obs = Observation.order(created_at: :asc).last
    standard_assertions(obs: obs, name: name)

    naming = obs.namings.find_by(name: t_mesenterica)
    assert(naming.present?,
           "Missing Naming for iNat identification by MO User")
    assert_equal(inat_manager, naming.user, "Naming has wrong User")
    vote = Vote.find_by(naming: naming, user: naming.user)
    assert(vote.present?, "Naming is missing a Vote")
    assert_equal(Vote::MAXIMUM_VOTE, vote.value,
                 "Vote for non-consensus name should be highest possible")

    naming = obs.namings.find_by(name: n_aurantia)
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

    Inat::PhotoImporter.stub(:new,
                             stub_mo_photo_importer(mock_inat_response)) do
      assert_difference("Observation.count", 1,
                        "Failed to create observation") do
        InatImportJob.perform_now(inat_import)
      end
    end

    obs = Observation.order(created_at: :asc).last
    standard_assertions(obs: obs, name: name)

    assert(obs.images.any?, "Obs should have images")
    assert(obs.sequences.one?, "Obs should have a sequence")
  end

  def test_import_job_infra_specific_name
    file_name = "i_obliquus_f_sterilis"
    mock_inat_response = File.read("test/inat/#{file_name}.txt")
    inat_import = create_inat_import(inat_response: mock_inat_response)

    # Add objects which are not included in fixtures
    name = Name.create(
      text_name: "Inonotus obliquus f. sterilis",
      author: "(Vanin) Balandaykin & Zmitr",
      display_name: "**__Inonotus obliquus__** f. **__sterilis__** " \
                    "(Vanin) Balandaykin & Zmitr.",
      rank: "Form",
      user: users(:rolf)
    )

    stub_inat_interactions(inat_import: inat_import,
                           mock_inat_response: mock_inat_response)

    Inat::PhotoImporter.stub(:new,
                             stub_mo_photo_importer(mock_inat_response)) do
      assert_difference("Observation.count", 1,
                        "Failed to create observation") do
        InatImportJob.perform_now(inat_import)
      end
    end

    obs = Observation.order(created_at: :asc).last
    standard_assertions(obs: obs, name: name)
    assert_equal(1, obs.images.length, "Obs should have 1 image")
    assert(obs.sequences.none?)
  end

  def test_import_job_complex
    file_name = "xeromphalina_campanella_complex"
    mock_inat_response = File.read("test/inat/#{file_name}.txt")
    inat_import = create_inat_import(inat_response: mock_inat_response)

    # Add objects which are not included in fixtures
    name = Name.create(
      text_name: "Xeromphalina campanella group",
      author: "",
      display_name: "**__Xeromphalina campanella__** group",
      rank: "Group",
      user: users(:rolf)
    )

    stub_inat_interactions(inat_import: inat_import,
                           mock_inat_response: mock_inat_response)

    Inat::PhotoImporter.stub(:new,
                             stub_mo_photo_importer(mock_inat_response)) do
      assert_difference("Observation.count", 1,
                        "Failed to create observation") do
        InatImportJob.perform_now(inat_import)
      end
    end

    obs = Observation.order(created_at: :asc).last
    standard_assertions(obs: obs, name: name)
    assert_equal(1, obs.images.length, "Obs should have 1 image")
    assert(obs.sequences.none?)
  end

  # Prove that Namings, Votes, Identification are correct
  # When iNat obs has provisional name that's already in MO
  # `johnplischke` NEMF, DNA, notes, 2 identifications with same id;
  # 3 comments, everyone has MO account;
  # obs fields(include("Voucher Number(s)", "Voucher Specimen Taken"))
  def test_import_job_nemf_plischke
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
    Inat::PhotoImporter.stub(:new,
                             stub_mo_photo_importer(mock_inat_response)) do
      assert_difference("Observation.count", 1,
                        "Failed to create observation") do
        InatImportJob.perform_now(inat_import)
      end
    end

    obs = Observation.order(created_at: :asc).last
    standard_assertions(obs: obs, name: name)

    assert(obs.images.any?, "Obs should have Images")
    assert(obs.sequences.one?, "Obs should have a Sequence")
    assert(obs.specimen, "Obs should show that a Specimen is available")
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

    Inat::PhotoImporter.stub(:new,
                             stub_mo_photo_importer(mock_inat_response)) do
      InatImportJob.perform_now(inat_import)
    end

    obs = Observation.order(created_at: :asc).last
    name = Name.find_by(text_name: 'Arrhenia "sp-NY02"')
    assert(name.present?, "Failed to create provisional name")
    assert(name.rss_log_id.present?,
           "Failed to log creation of provisional name")

    standard_assertions(obs: obs, name: name)

    assert(obs.images.any?, "Obs should have images")
    assert(obs.sequences.one?, "Obs should have a sequence")
  end

  def test_import_job_prov_name_pnw_style
    file_name = "donadinia_PNW01"
    mock_inat_response = File.read("test/inat/#{file_name}.txt")
    inat_import = create_inat_import(inat_response: mock_inat_response)
    name = Name.create(
      text_name: 'Donadinia "sp-PNW01"',
      author: "crypt. temp.",
      display_name: '**__Donadinia "sp-PNW01"__** crypt. temp.',
      rank: "Species",
      user: inat_manager
    )

    stub_inat_interactions(inat_import: inat_import,
                           mock_inat_response: mock_inat_response)

    Inat::PhotoImporter.stub(:new,
                             stub_mo_photo_importer(mock_inat_response)) do
      assert_difference("Observation.count", 1,
                        "Failed to create observation") do
        InatImportJob.perform_now(inat_import)
      end
    end

    obs = Observation.order(created_at: :asc).last
    standard_assertions(obs: obs, name: name)

    assert(obs.images.any?, "Obs should have images")
    assert(obs.sequences.one?, "Obs should have a sequence")
  end

  def test_import_plant
    file_name = "ceanothus_cordulatus"
    mock_inat_response = File.read("test/inat/#{file_name}.txt")
    inat_import = create_inat_import(inat_response: mock_inat_response)
    stub_inat_interactions(inat_import: inat_import,
                           mock_inat_response: mock_inat_response)

    Inat::PhotoImporter.stub(:new,
                             stub_mo_photo_importer(mock_inat_response)) do
      assert_no_difference("Observation.count", "Should not import Plantae") do
        InatImportJob.perform_now(inat_import)
      end
    end
  end

  def test_import_zero_results
    file_name = "zero_results"
    mock_inat_response = File.read("test/inat/#{file_name}.txt")
    inat_import = inat_imports(:rolf_inat_import)
    inat_import.update(inat_ids: "123", token: "MockCode")
    stub_inat_interactions(inat_import: inat_import,
                           mock_inat_response: mock_inat_response)

    Inat::PhotoImporter.stub(:new,
                             stub_mo_photo_importer(mock_inat_response)) do
      assert_no_difference(
        "Observation.count",
        "Should import nothing if no iNat obss match the user's list of id's"
      ) do
        InatImportJob.perform_now(inat_import)
      end
    end
  end

  def test_import_update_inat_username_if_job_succeeds
    user = users(:rolf)
    assert_empty(user.inat_username,
                 "Test needs user fixture without an iNat username")

    file_name = "zero_results"
    mock_inat_response = File.read("test/inat/#{file_name}.txt")
    inat_import = inat_imports(:rolf_inat_import)
    inat_import.update(inat_ids: "123", token: "MockCode")
    stub_inat_interactions(inat_import: inat_import,
                           mock_inat_response: mock_inat_response)

    Inat::PhotoImporter.stub(:new,
                             stub_mo_photo_importer(mock_inat_response)) do
      InatImportJob.perform_now(inat_import)
    end

    assert_equal(inat_import.inat_username, user.reload.inat_username,
                 "Failed to update user's inat_username")
  end

  def test_import_multiple
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

    Inat::PhotoImporter.stub(:new,
                             stub_mo_photo_importer(mock_inat_response)) do
      assert_difference("Observation.count", 2,
                        "Failed to create multiple observations") do
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

    Inat::PhotoImporter.stub(:new,
                             stub_mo_photo_importer(mock_inat_response)) do
      assert_difference("Observation.count", 2,
                        "Failed to create multiple observations") do
        InatImportJob.perform_now(inat_import)
      end
    end
  end

  def test_oauth_failure
    file_name = "calostoma_lutescens"
    mock_inat_response = File.read("test/inat/#{file_name}.txt")
    inat_import = create_inat_import(inat_response: mock_inat_response)

    oauth_return = { status: 401, body: "Unauthorized",
                     headers: { "Content-Type" => "application/json" } }
    stub_oauth_token_request(oauth_return: oauth_return)

    InatImportJob.perform_now(inat_import)

    assert_match(/401 Unauthorized/, inat_import.response_errors,
                 "Failed to report OAuth failure")
  end

  def test_jwt_failure
    file_name = "calostoma_lutescens"
    mock_inat_response = File.read("test/inat/#{file_name}.txt")
    inat_import = create_inat_import(inat_response: mock_inat_response)

    stub_oauth_token_request
    jwt_return = { status: 401, body: "Unauthorized",
                   headers: { "Content-Type" => "application/json" } }
    stub_jwt_request(jwt_return: jwt_return)

    InatImportJob.perform_now(inat_import)

    assert_match(/401 Unauthorized/, inat_import.response_errors,
                 "Failed to report OAuth failure")
  end

  def test_import_anothers_observation
    file_name = "calostoma_lutescens"
    mock_inat_response = File.read("test/inat/#{file_name}.txt")
    inat_import = create_inat_import(inat_response: mock_inat_response)

    stub_inat_interactions(inat_import: inat_import,
                           mock_inat_response: mock_inat_response,
                           login: "another user")

    Inat::PhotoImporter.stub(:new,
                             stub_mo_photo_importer(mock_inat_response)) do
      assert_difference("Observation.count", 0,
                        "It should not import another user's observation") do
        InatImportJob.perform_now(inat_import)
      end
    end
    assert_match(
      :inat_wrong_user.l, inat_import.response_errors,
      "It should warn if a user tries to import another's iNat obs"
    )
  end

  def test_super_importer_anothers_observation
    file_name = "calostoma_lutescens"
    mock_inat_response = File.read("test/inat/#{file_name}.txt")
    user = users(:dick)
    assert(InatImport.super_importers.include?(user),
           "Test needs User fixture that's SuperImporter")

    inat_import = create_inat_import(user: user,
                                     inat_response: mock_inat_response)
    stub_inat_interactions(inat_import: inat_import,
                           mock_inat_response: mock_inat_response,
                           superimporter: true)

    Inat::PhotoImporter.stub(:new,
                             stub_mo_photo_importer(mock_inat_response)) do
      assert_difference(
        "Observation.count", 1,
        "'super_importer' failed to import another user's observation"
      ) do
        InatImportJob.perform_now(inat_import)
      end
    end
    assert_empty(inat_import.response_errors, "There should be no errors")
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
        parse(inat_response)["results"].first["user"]["login"],
      response_errors: ""
    )
  end

  # -------- Test doubles

  def stub_inat_interactions(
    inat_import:, mock_inat_response:, id_above: 0,
    login: inat_import.inat_username, superimporter: false
  )
    stub_token_requests
    stub_check_username_match(login)
    stub_inat_api_request(inat_import: inat_import,
                          mock_inat_response: mock_inat_response,
                          id_above: id_above,
                          superimporter: superimporter)
    stub_inat_photo_requests(mock_inat_response)
    stub_modify_inat_observations(mock_inat_response)
  end

  def good_response
    { status: 200, body: "\"\"", headers: {} }.freeze
  end

  def bad_response
    { status: 401, body: "Unauthorized" }.freeze
  end

  def stub_token_requests
    stub_oauth_token_request
    # must trade oauth access token for a JWT in order to use iNat API v1
    stub_jwt_request
  end

  # stub exchanging iNat code for oauth token
  # https://www.inaturalist.org/pages/api+reference#authorization_code_flow
  def stub_oauth_token_request(oauth_return: {
    status: 200,
    body: { access_token: "MockAccessToken" }.to_json,
    headers: {}
  })
    add_stub(stub_request(:post, "#{SITE}/oauth/token").
      with(
        body: { "client_id" => Rails.application.credentials.inat.id,
                "client_secret" => Rails.application.credentials.inat.secret,
                "code" => "MockCode",
                "grant_type" => "authorization_code",
                "redirect_uri" => REDIRECT_URI }
      ).
      to_return(oauth_return))
  end

  def stub_jwt_request(jwt_return:
    { status: 200,
      body: { access_token: "MockJWT" }.to_json,
      headers: {} })
    add_stub(stub_request(:get, "#{SITE}/users/api_token").
      with(
        headers: {
          "Accept" => "application/json",
          "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
          "Authorization" => "Bearer MockAccessToken",
          "Host" => "www.inaturalist.org"
        }
      ).
      to_return(jwt_return))
  end

  def stub_check_username_match(login)
    add_stub(stub_request(:get, "#{API_BASE}/users/me").
      with(
        headers: {
          "Accept" => "application/json",
          "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
          "Authorization" => "Bearer",
          "Content-Type" => "application/json",
          "Host" => "api.inaturalist.org"
        }
      ).
      to_return(status: 200,
                body: "{\"results\":[{\"login\":\"#{login}\"}]}",
                headers: {}))
  end

  def stub_inat_api_request(inat_import:, mock_inat_response:, id_above: 0,
                            superimporter: false)
    # Params must be in same order as in the controller
    # Limit search to observations by the user, unless superimporter
    # omit trailing "=" since the controller omits it (via `merge`)
    params = <<~PARAMS.delete("\n").chomp("=")
      ?iconic_taxa=#{ICONIC_TAXA}
      &id=#{inat_import.inat_ids}
      &id_above=#{id_above}
      &per_page=200
      &only_id=false
      &order=asc&order_by=id
      &user_login=#{inat_import.inat_username unless superimporter}
    PARAMS
    add_stub(stub_request(:get, "#{API_BASE}/observations#{params}").
      with(headers:
    { "Accept" => "application/json",
      "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
      "Authorization" => "Bearer",
      "Host" => "api.inaturalist.org" }).
      to_return(body: mock_inat_response))
  end

  def stub_inat_photo_requests(mock_inat_response)
    JSON.parse(mock_inat_response)["results"].each do |result|
      result["observation_photos"].each do |photo|
        add_stub(stub_request(
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
          to_return(status: 200, body: "", headers: {}))
      end
    end
  end

  def stub_mo_photo_importer(mock_inat_response)
    # Suggested by CoPilot:
    # I wanted to directly stub Inat::PhotoImporter.new,
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

  def stub_modify_inat_observations(mock_inat_response)
    stub_add_observation_fields
    stub_update_descriptions(mock_inat_response)
  end

  def stub_add_observation_fields
    add_stub(stub_request(:post, "#{API_BASE}/observation_field_values").
      to_return(status: 200, body: "".to_json,
                headers: { "Content-Type" => "application/json" }))
  end

  def stub_update_descriptions(mock_inat_response)
    date = Time.zone.today.strftime(MO.web_date_format)
    observations = JSON.parse(mock_inat_response)["results"]
    observations.each do |obs|
      updated_description =
        "Imported by Mushroom Observer #{date}"
      if obs["description"].present?
        updated_description.prepend("#{obs["description"]}\n\n")
      end

      body = {
        observation: {
          description: updated_description,
          # This param needed in order to retain the photos
          # https://forum.inaturalist.org/t/api-modify-observation-description/55665
          # https://www.inaturalist.org/pages/api+reference#put-observations-id
          ignore_photos: 1
        }
      }
      headers = { authorization: "Bearer",
                  content_type: "application/json", accept: "application/json" }
      add_stub(
        stub_request(
          :put, "#{API_BASE}/observations/#{obs["id"]}?ignore_photos=1"
        ).
        with(body: body.to_json, headers: headers).
        to_return(status: 200, body: "".to_json, headers: {})
      )
    end
  end

  # -------- Standard Test assertions

  def standard_assertions(obs:, name: nil, loc: nil)
    assert_not_nil(obs.rss_log, "Failed to log Observation")
    assert_equal("mo_inat_import", obs.source)
    assert_equal(loc, obs.location) if loc

    obs.namings.each do |naming|
      assert_not(
        naming.vote_cache.zero?,
        "VoteCache for Proposed Name '#{naming.name.text_name}' incorrect"
      )
    end

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

    view = ObservationView.
           find_by(observation_id: obs.id, user_id: inat_manager.id)
    assert(view.present?, "Failed to create ObservationView")

    assert(obs.comments.any?, "Imported iNat should have >= 1 Comment")
    obs_comments =
      Comment.where(target_type: "Observation", target_id: obs.id)
    assert(obs_comments.one?)
    assert(obs_comments.where(Comment[:summary] =~ /iNat Data/).present?,
           "Missing Initial Commment (#{:inat_data_comment.l})")
    assert_equal(
      inat_manager, obs_comments.first.user,
      "Comment user should be webmaster (vs user who imported iNat Obs)"
    )
    inat_data_comment = obs_comments.first.comment
    [
      :USER.l, :OBSERVED.l, :show_observation_inat_lat_lng.l, :PLACE.l,
      :ID.l, :DQA.l, :ANNOTATIONS.l, :PROJECTS.l, :OBSERVATION_FIELDS.l, :TAGS.l
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

  # Hack to turn results with many pages into results with one page
  # By ignoring all pages but the first
  def limited_to_first_page(mock_search_result)
    ms_hash = JSON.parse(mock_search_result)
    ms_hash["total_results"] = ms_hash["results"].length
    JSON.generate(ms_hash)
  end

  def mock_me_response(login)
    { code: 200, body: { "results" => [{ "login" => login }] } }
  end
end
