# frozen_string_literal: true

require("test_helper")

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
  # Prevent stubs from persisting between test methods because
  # the same request (/users/me) needs diffferent responses
  def setup
    @user = users(:inat_importer)
    @stubs = []
    directory_path = Rails.public_path.join("test_images/orig")
    FileUtils.mkdir_p(directory_path) unless Dir.exist?(directory_path)
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

    inat_import = create_inat_import(inat_response: mock_inat_response)
    # You can import only your own observations.
    # So adjust importing user's inat_username to be the Inat login
    # of the iNat user who made the iNat observation
    @user.update(inat_username: inat_import.inat_username)

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

    stub_inat_interactions(inat_import: inat_import,
                           mock_inat_response: mock_inat_response)

    QueuedEmail.queue = true
    before_emails_to_user = QueuedEmail.where(to_user: @user).count

    Inat::PhotoImporter.stub(:new,
                             stub_mo_photo_importer(mock_inat_response)) do
      assert_difference("Observation.count", 1,
                        "Failed to create observation") do
        InatImportJob.perform_now(inat_import)
      end
    end

    obs = Observation.last
    standard_assertions(obs: obs, name: name, loc: loc)

    # This iNat obs has only 1 suggested ID.
    # The suggester is the person who made the iNat observation.
    proposed_name = obs.namings.first
    used_references = 2
    assert(
      proposed_name.reasons.key?(used_references),
      "Proposed consensus Name reason should be #{:naming_reason_label_2.l}" # rubocop:disable Naming/VariableNumber
    )
    proposed_name_notes = proposed_name[:reasons][used_references]
    suggesting_inat_user = JSON.parse(mock_inat_response)["results"].
                           first["identifications"].
                           first["user"]["login"]
    assert_match(:naming_reason_suggested_on_inat.l(user: suggesting_inat_user),
                 proposed_name_notes)
    suggestion_date = JSON.parse(mock_inat_response)["results"].
                      first["identifications"].
                      first["created_at"]
    assert_match(suggestion_date, proposed_name_notes)

    assert_not(obs.specimen, "Obs should not have a specimen")
    assert_equal(0, obs.images.length, "Obs should not have images")
    assert_match(/Observation Fields: none/, obs.comments.first.comment,
                 "Missing 'none' for Observation Fields")

    assert_equal(
      before_emails_to_user, QueuedEmail.where(to_user: @user).count,
      "Should not have sent any emails to importing user for this obs"
    )
    QueuedEmail.queue = false
  end

  # Prove (inter alia) that the MO Naming.user differs from the importing user
  # when the iNat user who made the 1st iNat id is another MO user
  def test_import_job_inat_id_suggested_by_another_by_mo_user
    file_name = "calostoma_lutescens"
    mock_inat_response = File.read("test/inat/#{file_name}.txt")

    # Tweak mock response to make mary the person who made the 1st iNat id
    user = users(:mary)
    assert(user.inat_username.present?,
           "Test needs user fixture with an inat_username")
    parsed_response = JSON.parse(mock_inat_response)
    parsed_response["results"].first["identifications"].first["user"]["login"] =
      user.inat_username
    mock_inat_response = JSON.generate(parsed_response)
    inat_import = create_inat_import(inat_response: mock_inat_response)

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

    stub_inat_interactions(inat_import: inat_import,
                           mock_inat_response: mock_inat_response)

    Inat::PhotoImporter.stub(:new,
                             stub_mo_photo_importer(mock_inat_response)) do
      assert_difference("Observation.count", 1,
                        "Failed to create observation") do
        InatImportJob.perform_now(inat_import)
      end
    end

    obs = Observation.last
    proposed_name = obs.namings.first
    assert_equal(user, proposed_name.user,
                 "Name should be proposed by #{user.login}")
    used_references = 2
    assert(
      proposed_name.reasons.key?(used_references),
      "Proposed Name reason should be #{:naming_reason_label_2.l}" # rubocop:disable Naming/VariableNumber
    )
    proposed_name_notes = proposed_name[:reasons][used_references]
    suggesting_inat_user = JSON.parse(mock_inat_response)["results"].
                           first["identifications"].
                           first["user"]["login"]
    assert_match(:naming_reason_suggested_on_inat.l(user: suggesting_inat_user),
                 proposed_name_notes)
    suggestion_date = JSON.parse(mock_inat_response)["results"].
                      first["identifications"].
                      first["created_at"]
    assert_match(suggestion_date, proposed_name_notes)
  end

  # Had 1 photo, 1 identification, 0 observation_fields; 0 sequences
  def test_import_job_obs_with_one_photo
    file_name = "evernia"
    mock_inat_response = File.read("test/inat/#{file_name}.txt")
    inat_import = create_inat_import(inat_response: mock_inat_response)

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

    stub_inat_interactions(inat_import: inat_import,
                           mock_inat_response: mock_inat_response)

    assert_difference("Observation.count", 1,
                      "Failed to create observation") do
      InatImportJob.perform_now(inat_import)
    end

    obs = Observation.last
    standard_assertions(obs: obs, name: name, loc: loc)

    assert_equal(1, obs.images.length, "Obs should have 1 image")

    inat_photo = JSON.parse(mock_inat_response)["results"].
                 first["observation_photos"].first
    imported_img = obs.images.first
    assert_equal(@user, imported_img.user,
                 "Image should belong to importing user")
    assert_equal(
      "iNat photo_id: #{inat_photo["photo_id"]}, uuid: #{inat_photo["uuid"]}",
      imported_img.original_name,
      "Image original_name should be iNat photo_id and uuid"
    )

    assert(obs.sequences.none?)
  end

  # Had 1 photo; 2 identifications, 1 not by user.
  def test_import_job_obs_with_many_namings
    file_name = "tremella_mesenterica"
    mock_inat_response = File.read("test/inat/#{file_name}.txt")
    inat_import = create_inat_import(inat_response: mock_inat_response)

    name = Name.find_or_create_by(text_name: "Tremellales",
                                  author: "Fr.",
                                  search_name: "Tremellales Fr.",
                                  display_name: "Tremellales",
                                  rank: "Order",
                                  user: @user)

    stub_inat_interactions(inat_import: inat_import,
                           mock_inat_response: mock_inat_response)

    stub_request(:get, "https://inaturalist-open-data.s3.amazonaws.com/photos/377332865/original.jpeg").
      with(
        headers: {
          "Accept" => "image/*",
          "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
          "Host" => "inaturalist-open-data.s3.amazonaws.com",
          "User-Agent" => "Ruby"
        }
      ).
      to_return(status: 200, body: image_for_stubs, headers: {})
    assert_difference("Observation.count", 1,
                      "Failed to create observation") do
      InatImportJob.perform_now(inat_import)
    end

    obs = Observation.last
    standard_assertions(obs: obs, name: name)
    assert(obs.images.any?, "Obs should have images")
    assert(obs.sequences.none?)
  end

  # Had 2 photos, 6 identifications of 3 taxa, a different taxon,
  # 9 obs fields, including "DNA Barcode ITS", "Collection number", "Collector"
  def test_import_job_obs_with_sequence_and_multiple_ids
    file_name = "lycoperdon"
    mock_inat_response = File.read("test/inat/#{file_name}.txt")
    inat_import = create_inat_import(inat_response: mock_inat_response)

    name = Name.create(
      text_name: "Lycoperdon", author: "Pers.",
      search_name: "Lycoperdon Pers.",
      display_name: "**__Lycoperdon__** Pers.",
      rank: "Genus",
      user: @user
    )

    stub_inat_interactions(inat_import: inat_import,
                           mock_inat_response: mock_inat_response)

    assert_difference("Observation.count", 1,
                      "Failed to create observation") do
      InatImportJob.perform_now(inat_import)
    end

    obs = Observation.last
    standard_assertions(obs: obs, name: name)

    assert(obs.images.any?, "Obs should have images")
    assert(obs.sequences.one?, "Obs should have a sequence")
    assert_equal(@user, obs.sequences.first.user,
                 "Sequences should belong to the user who imported the obs")

    ids = JSON.parse(mock_inat_response)["results"].first["identifications"]
    unique_suggested_taxon_names = ids.each_with_object([]) do |id, ary|
      ary << id["taxon"]["name"]
    end
    unique_suggested_taxon_names.each do |taxon_name|
      assert_match(taxon_name, obs.comments.first.comment,
                   "Snapshot comment missing suggested name #{taxon_name}")
    end
  end

  def test_import_job_infra_specific_name
    file_name = "i_obliquus_f_sterilis"
    mock_inat_response = File.read("test/inat/#{file_name}.txt")
    inat_import = create_inat_import(inat_response: mock_inat_response)

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

    stub_inat_interactions(inat_import: inat_import,
                           mock_inat_response: mock_inat_response)
    stub_request(:get, "https://inaturalist-open-data.s3.amazonaws.com/photos/413872439/original.jpeg").
      with(
        headers: {
          "Accept" => "image/*",
          "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
          "Host" => "inaturalist-open-data.s3.amazonaws.com",
          "User-Agent" => "Ruby"
        }
      ).
      to_return(status: 200, body: image_for_stubs, headers: {})

    assert_difference("Observation.count", 1,
                      "Failed to create observation") do
      InatImportJob.perform_now(inat_import)
    end

    obs = Observation.last
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
      text_name: "Xeromphalina campanella group", author: "",
      search_name: "Xeromphalina campanella group",
      display_name: "**__Xeromphalina campanella__** group",
      rank: "Group",
      user: @user
    )

    stub_inat_interactions(inat_import: inat_import,
                           mock_inat_response: mock_inat_response)
    stub_request(:get, "https://inaturalist-open-data.s3.amazonaws.com/photos/381894665/original.jpeg").
      with(
        headers: {
          "Accept" => "image/*",
          "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
          "Host" => "inaturalist-open-data.s3.amazonaws.com",
          "User-Agent" => "Ruby"
        }
      ).
      to_return(status: 200, body: image_for_stubs, headers: {})
    stub_request(:get, "https://inaturalist-open-data.s3.amazonaws.com/photos/381894686/original.jpeg").
      with(
        headers: {
          "Accept" => "image/*",
          "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
          "Host" => "inaturalist-open-data.s3.amazonaws.com",
          "User-Agent" => "Ruby"
        }
      ).
      to_return(status: 200, body: image_for_stubs, headers: {})

    assert_difference("Observation.count", 1,
                      "Failed to create observation") do
      InatImportJob.perform_now(inat_import)
    end

    obs = Observation.last
    standard_assertions(obs: obs, name: name)
    assert_equal(2, obs.images.length, "Obs should have 2 images")
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
      text_name: 'Arrhenia "sp-NY02"', author: "S.D. Russell crypt. temp.",
      search_name: 'Arrhenia "sp-NY02" S.D. Russell crypt. temp.',
      display_name: '**__Arrhenia "sp-NY02"__** S.D. Russell crypt. temp.',
      rank: "Species",
      user: @user
    )

    stub_inat_interactions(inat_import: inat_import,
                           mock_inat_response: mock_inat_response)
    stub_request(:get, "https://inaturalist-open-data.s3.amazonaws.com/photos/321536915/original.jpeg").
      with(
        headers: {
          "Accept" => "image/*",
          "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
          "Host" => "inaturalist-open-data.s3.amazonaws.com",
          "User-Agent" => "Ruby"
        }
      ).
      to_return(status: 200, body: image_for_stubs, headers: {})

    assert_difference("Observation.count", 1,
                      "Failed to create observation") do
      InatImportJob.perform_now(inat_import)
    end

    obs = Observation.last
    standard_assertions(obs: obs, name: name)

    assert(obs.images.any?, "Obs should have Images")
    assert(obs.sequences.one?, "Obs should have one Sequence")
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

    stub_request(:get, "https://inaturalist-open-data.s3.amazonaws.com/photos/321536915/original.jpeg").
      with(
        headers: {
          "Accept" => "image/*",
          "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
          "Host" => "inaturalist-open-data.s3.amazonaws.com",
          "User-Agent" => "Ruby"
        }
      ).
      to_return(status: 200, body: image_for_stubs, headers: {})

    InatImportJob.perform_now(inat_import)

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
      "Proposed Name reason should be #{:naming_reason_label_2.l}" # rubocop:disable Naming/VariableNumber
    )
    proposed_name_notes = proposed_name[:reasons][used_references]
    provisional_field =
      JSON.parse(mock_inat_response)["results"].first["ofvs"].
      find { |field| field["name"] == "Provisional Species Name" }
    adding_inat_user = provisional_field["user"]["login"]
    assert_match(:naming_inat_provisional.l(user: adding_inat_user),
                 proposed_name_notes)

    assert(obs.images.any?, "Obs should have images")
    assert(obs.sequences.one?, "Obs should have one sequence")
  end

  def image_for_stubs
    @image_for_stubs ||= Rails.root.join("test/images/test_image.jpg").read
  end

  def image_stubs(image_ids)
    image_data = image_for_stubs
    image_ids.each do |id|
      stub_request(:get, "https://static.inaturalist.org/photos/#{id}/original.jpg").
        with(
          headers: {
            "Accept" => "image/*",
            "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
            "Host" => "static.inaturalist.org",
            "User-Agent" => "Ruby"
          }
        ).
        to_return(status: 200, body: image_data, headers: {})
    end
  end

  def test_import_job_prov_name_pnw_style
    file_name = "donadinia_PNW01"
    mock_inat_response = File.read("test/inat/#{file_name}.txt")
    inat_import = create_inat_import(inat_response: mock_inat_response)
    assert(Name.where(Name[:text_name] =~ /Donadinia/).none?,
           "Test requires that MO not yet have `Donadinia` Names")

    stub_inat_interactions(inat_import: inat_import,
                           mock_inat_response: mock_inat_response)

    # JDC 2025-04-14 This obs's photos are All Rights Reserved, not CC licensed.
    # Although physically hosted by Amazon they are
    # not in the Amazon Open Data Sponsorship Program
    # https://www.inaturalist.org/blog/49564-inaturalist-licensed-observation-images-in-the-amazon-open-data-sponsorship-program/
    # cf. https://github.com/inaturalist/inaturalist-open-data
    # Amazon Open Data Sponsorship Program images have a amazonaws.com url.
    # Other images have a static.inaturalist.org url.
    # They therefore are stubbed differently.
    image_stubs([375_217_770, 375_216_871, 375_217_919])

    assert_difference("Observation.count", 1,
                      "Failed to create observation") do
      InatImportJob.perform_now(inat_import)
    end

    obs = Observation.last

    new_names = Name.where(Name[:text_name] =~ /Donadinia/)
    assert_equal(2, new_names.count,
                 "Failed to create new sp. (nom. prov.) and its genus")
    new_names.each do |new_name|
      assert_equal(
        @user, new_name.user,
        "#{new_name.text_name} author should be #{@user.login}"
      )
    end
    name = new_names.find_by(rank: "Species")

    standard_assertions(obs: obs, name: name)

    assert(obs.images.any?, "Obs should have images")
    assert(obs.sequences.one?, "Obs should have one sequence")
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
    user = @user
    assert_empty(user.inat_username,
                 "Test needs user fixture without an iNat username")

    file_name = "zero_results"
    mock_inat_response = File.read("test/inat/#{file_name}.txt")
    inat_import = InatImport.find_by(user: user)
    inat_import.update(inat_ids: "123", token: "MockCode")
    stub_inat_interactions(inat_import: inat_import,
                           mock_inat_response: mock_inat_response)

    Inat::PhotoImporter.stub(:new,
                             stub_mo_photo_importer(mock_inat_response)) do
      InatImportJob.perform_now(inat_import)
    end

    assert_equal(inat_import.inat_username, @user.reload.inat_username,
                 "Failed to update user's inat_username")
  end

  def test_import_multiple
    file_name = "listed_ids"
    mock_inat_response = File.read("test/inat/#{file_name}.txt")
    inat_import = InatImport.create(user: @user,
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
    inat_import = InatImport.create(user: @user,
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
  def create_inat_import(user: @user,
                         inat_response: mock_inat_response)
    InatImport.create(
      user: user, token: "MockCode",
      inat_ids: JSON.parse(inat_response)["results"].first["id"],
      inat_username: JSON.
        parse(inat_response)["results"].first["user"]["login"],
      response_errors: ""
    )
  end

  # -------- Standard Test assertions

  def standard_assertions(obs:, user: @user, name: nil, loc: nil)
    assert_not_nil(obs.rss_log, "Failed to log Observation")
    assert_equal("mo_inat_import", obs.source)
    assert_equal(loc, obs.location) if loc

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

  # -------- Test doubles

  # url for iNat authorization and authentication requests
  SITE = InatImportsController::SITE
  # MO url called by iNat after iNat user authorizes MO to access their data
  REDIRECT_URI = InatImportsController::REDIRECT_URI
  # iNat API url
  API_BASE = InatImportsController::API_BASE
  # Value of the iNat API "iconic_taxa" query param
  # That param is included in iNat API requests in order to limit the results
  # to Fungi and slime molds (with Protozoa as a proxy for slime molds)
  ICONIC_TAXA = InatImportJob::ICONIC_TAXA
  # base url for iNat CC-licensed and public domain photos
  LICENSED_PHOTO_BASE = "https://inaturalist-open-data.s3.amazonaws.com/photos"
  # base url for iNat unlicensed photos
  UNLICENSED_PHOTO_BASE = "https://static.inaturalist.org/photos"

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
      body: { api_token: "MockJWT" }.to_json,
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
          "Authorization" => "Bearer MockJWT",
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
    query_args = {
      iconic_taxa: ICONIC_TAXA,
      id: inat_import.inat_ids,
      id_above: id_above,
      per_page: 200,
      only_id: false,
      order: "asc",
      order_by: "id",
      without_field: "Mushroom Observer URL",
      # Limit results to observations by the user, unless superimporter
      user_login: (inat_import.inat_username unless superimporter)
    }

    add_stub(stub_request(:get,
                          "#{API_BASE}/observations?#{query_args.to_query}").
      with(headers:
    { "Accept" => "application/json",
      "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
      "Authorization" => "Bearer MockJWT",
      "Host" => "api.inaturalist.org" }).
      to_return(body: mock_inat_response))
  end

  def stub_inat_photo_requests(mock_inat_response)
    JSON.parse(mock_inat_response)["results"].each do |result|
      result["observation_photos"].each do |photo|
        if photo["photo"]["license_code"].present?
          stub_inat_licensed_photo_request(photo)
        else
          stub_inat_unlicensed_photo_request(photo)
        end
      end
    end
  end

  # stub the MO implicit request for the iNat photo
  # Returns the same photo for all stubs, which is
  # sufficient for testing purposes.
  def stub_inat_licensed_photo_request(photo)
    add_stub(stub_request(
      :get,
      "#{LICENSED_PHOTO_BASE}/#{photo["photo_id"]}/original.jpg"
    ).
      with(
        headers: {
          "Accept" => "image/*",
          "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
          "Host" => "inaturalist-open-data.s3.amazonaws.com",
          "User-Agent" => "Ruby"
        }
      ).
      to_return(status: 200, body: image_for_stubs, headers: {}))
  end

  def stub_inat_unlicensed_photo_request(photo)
    add_stub(
      stub_request(
        :get,
        "#{UNLICENSED_PHOTO_BASE}/#{photo["id"]}/original.jpg"
      ).
        with(
          headers: {
            "Accept" => "image/*",
            "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
            "Host" => "static.inaturalist.org",
            "User-Agent" => "Ruby"
          }
        ).
      to_return(status: 200, body: image_for_stubs, headers: {})
    )
  end

  def stub_mo_photo_importer(mock_inat_response)
    # Suggested by CoPilot:
    # I wanted to directly stub Inat::PhotoImporter.new,
    # but that class doesn’t have a stub method by default. Therefore:
    # Create a mock photo importer
    mock_photo_importer = Minitest::Mock.new
    img = images(:mock_imported_inat_image)
    mock_photo_importer.expect(
      :new, nil,
      [{ api: MockImageAPI.new(errors: [], results: [img]) }]
    )
    results = JSON.parse(mock_inat_response)["results"]
    # NOTE: This simply insures that ImageAPI is called the right # of times.
    # It does NOT attach the right # of photos or even the correct photo.
    results.each do |inat_obs|
      inat_obs["observation_photos"].each do
        mock_photo_importer.expect(
          :api, # nil,
          MockImageAPI.new(errors: [], results: [img])
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
      headers = { authorization: "Bearer MockJWT",
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
end
