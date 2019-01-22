require "test_helper"
require "rexml/document"

class ApiControllerTest < FunctionalTestCase
  def assert_no_api_errors(msg = nil)
    @api = assigns(:api)
    return unless @api
    msg = format_api_errors(@api, msg)
    assert(@api.errors.empty?, msg)
  end

  def format_api_errors(api, msg)
    lines = [msg, "Caught API Errors:"]
    lines += api.errors.map do |error|
      error.to_s + "\n" + error.trace.join("\n")
    end
    lines.reject(&:blank?).join("\n")
  end

  def post_and_send_file(action, file, content_type, params)
    data = Rack::Test::UploadedFile.new(file, "image/jpeg")
    params[:body] = data
    post_and_send(action, content_type, params)
  end

  def post_and_send(action, type, params)
    @request.env["CONTENT_TYPE"] = type
    post(action, params)
  end

  def file_checksum(filename)
    File.open(filename) do |f|
      Digest::MD5.hexdigest(f.read)
    end
  end

  def string_checksum(string)
    Digest::MD5.hexdigest(string)
  end

  ##############################################################################

  def test_basic_collection_number_get_request
    do_basic_get_request_for_model(CollectionNumber)
  end

  def test_basic_comment_get_request
    do_basic_get_request_for_model(Comment)
  end

  def test_basic_externallink_get_request
    do_basic_get_request_for_model(ExternalLink)
  end

  def test_basic_externalsite_get_request
    do_basic_get_request_for_model(ExternalSite)
  end

  def test_basic_herbarium_get_request
    do_basic_get_request_for_model(Herbarium)
  end

  def test_basic_herbarium_record_get_request
    do_basic_get_request_for_model(HerbariumRecord)
  end

  def test_basic_image_get_request
    do_basic_get_request_for_model(Image)
  end

  def test_basic_location_get_request
    do_basic_get_request_for_model(Location)
  end

  def test_basic_name_get_request
    do_basic_get_request_for_model(Name)
  end

  def test_basic_observation_get_request
    do_basic_get_request_for_model(Observation)
  end

  def test_basic_project_get_request
    do_basic_get_request_for_model(Project)
  end

  def test_basic_sequence_get_request
    do_basic_get_request_for_model(Sequence)
  end

  def test_basic_specieslist_get_request
    do_basic_get_request_for_model(SpeciesList)
  end

  def test_basic_user_get_request
    do_basic_get_request_for_model(User)
  end

  def do_basic_get_request_for_model(model)
    [:none, :low, :high].each do |detail|
      [:xml, :json].each do |format|
        get(model.table_name.to_sym, detail: detail, format: format)
        assert_no_api_errors("Get #{model.name} #{detail} #{format}")
        assert_objs_equal(model.first, @api.results.first)
      end
    end
  end

  def test_num_of_pages
    get(:observations, detail: :high, format: :json)
    json = JSON.parse(response.body)
    assert_equal((Observation.count / 10.0).ceil, json["number_of_pages"],
                 "Number of pages was not correctly calculated.")
  end

  def test_post_minimal_observation
    post(:observations,
         api_key: api_keys(:rolfs_api_key).key,
         location: "Unknown")
    assert_no_api_errors
    obs = Observation.last
    assert_users_equal(rolf, obs.user)
    assert_equal(Date.today.web_date, obs.when.web_date)
    assert_objs_equal(Location.unknown, obs.location)
    assert_equal("Unknown", obs.where)
    assert_names_equal(names(:fungi), obs.name)
    assert_equal(1, obs.namings.length)
    assert_equal(1, obs.votes.length)
    assert_nil(obs.lat)
    assert_nil(obs.long)
    assert_nil(obs.alt)
    assert_equal(false, obs.specimen)
    assert_equal(true, obs.is_collection_location)
    assert_equal(Observation.no_notes, obs.notes)
    assert_obj_list_equal([], obs.images)
    assert_nil(obs.thumb_image)
    assert_obj_list_equal([], obs.projects)
    assert_obj_list_equal([], obs.species_lists)
  end

  def test_post_maximal_observation
    post(
      :observations,
      api_key: api_keys(:rolfs_api_key).key,
      date: "2012-06-26",
      location: "Burbank, California, USA",
      name: "Coprinus comatus",
      vote: "2",
      latitude: "34.5678N",
      longitude: "123.4567W",
      altitude: "1234 ft",
      has_specimen: "yes",
      is_collection_location: "yes",
      notes: "These are notes.\nThey look like this.\n",
      images: "#{images(:in_situ_image).id}, #{images(:turned_over_image).id}",
      thumbnail: images(:turned_over_image).id.to_s,
      projects: "EOL Project",
      species_lists: "Another Species List"
    )
    assert_no_api_errors
    obs = Observation.last
    assert_users_equal(rolf, obs.user)
    assert_equal("2012-06-26", obs.when.web_date)
    assert_objs_equal(locations(:burbank), obs.location)
    assert_equal("Burbank, California, USA", obs.where)
    assert_names_equal(names(:coprinus_comatus), obs.name)
    assert_equal(1, obs.namings.length)
    assert_equal(1, obs.votes.length)
    assert_equal(2.0, obs.votes.first.value)
    assert_equal(34.5678, obs.lat)
    assert_equal(-123.4567, obs.long)
    assert_equal(376, obs.alt)
    assert_equal(true, obs.specimen)
    assert_equal(true, obs.is_collection_location)
    assert_equal({ Observation.other_notes_key =>
                   "These are notes.\nThey look like this." }, obs.notes)
    assert_obj_list_equal([images(:in_situ_image), images(:turned_over_image)],
                          obs.images)
    assert_objs_equal(images(:turned_over_image), obs.thumb_image)
    assert_obj_list_equal([projects(:eol_project)], obs.projects)
    assert_obj_list_equal([species_lists(:another_species_list)],
                          obs.species_lists)
  end

  def test_post_minimal_image
    setup_image_dirs
    count = Image.count
    file = "#{::Rails.root}/test/images/sticky.jpg"
    File.stub(:rename, false) do
      post_and_send_file(:images, file, "image/jpeg",
                         api_key: api_keys(:rolfs_api_key).key)
    end
    assert_no_api_errors
    assert_equal(count + 1, Image.count)
    img = Image.last
    assert_users_equal(rolf, img.user)
    assert_equal(Date.today.web_date, img.when.web_date)
    assert_equal("", img.notes)
    assert_equal(rolf.legal_name, img.copyright_holder)
    assert_objs_equal(rolf.license, img.license)
    assert_nil(img.original_name)
    assert_equal("image/jpeg", img.content_type)
    assert_equal(407, img.width)
    assert_equal(500, img.height)
    assert_obj_list_equal([], img.projects)
    assert_obj_list_equal([], img.observations)
  end

  def test_post_maximal_image
    setup_image_dirs
    file = "#{::Rails.root}/test/images/Coprinus_comatus.jpg"
    proj = rolf.projects_member.first
    obs = rolf.observations.first
    File.stub(:rename, false) do
      post_and_send_file(:images, file, "image/jpeg",
                         api_key: api_keys(:rolfs_api_key).key,
                         vote: "3",
                         date: "20120626",
                         notes: " Here are some notes. ",
                         copyright_holder: "My Friend",
                         license: licenses(:ccnc30).id.to_s,
                         original_name: "Coprinus_comatus.jpg",
                         projects: proj.id,
                         observations: obs.id)
    end
    assert_no_api_errors
    img = Image.last
    assert_users_equal(rolf, img.user)
    assert_equal("2012-06-26", img.when.web_date)
    assert_equal("Here are some notes.", img.notes)
    assert_equal("My Friend", img.copyright_holder)
    assert_objs_equal(licenses(:ccnc30), img.license)
    assert_equal("Coprinus_comatus.jpg", img.original_name)
    assert_equal("image/jpeg", img.content_type)
    assert_equal(2288, img.width)
    assert_equal(2168, img.height)
    assert_obj_list_equal([proj], img.projects)
    assert_obj_list_equal([obs], img.observations)
  end

  def test_post_user
    rolfs_key = api_keys(:rolfs_api_key)
    post(:users,
         api_key: rolfs_key.key,
         login: "miles",
         email: "miles@davis.com",
         password: "sivadselim",
         create_key: "New API Key",
         detail: :high)
    assert_no_api_errors
    user = User.last
    assert_equal("miles", user.login)
    assert_false(user.verified)
    assert_equal(1, user.api_keys.length)
    doc = REXML::Document.new(@response.body)
    keys = doc.root.elements["results/result/api_keys"]
    num = begin
            keys.attribute("number").value
          rescue
            nil
          end
    assert_equal("1", num.to_s)
    key = begin
            keys.elements["api_key/key"].get_text
          rescue
            nil
          end
    notes = begin
              keys.elements["api_key/notes"].get_text
            rescue
              nil
            end
    assert_not_equal("", key.to_s)
    assert_equal("&lt;p&gt;New &lt;span class=\"caps\"&gt;API&lt;/span&gt; Key&lt;/p&gt;",
                 notes.to_s)
  end

  def test_post_api_key
    email_count = ActionMailer::Base.deliveries.size

    rolfs_key = api_keys(:rolfs_api_key)
    post(:api_keys,
         api_key: rolfs_key.key,
         app: "Mushroom Mapper")
    assert_no_api_errors
    api_key = ApiKey.last
    assert_equal("Mushroom Mapper", api_key.notes)
    assert_users_equal(rolf, api_key.user)
    assert_not_nil(api_key.verified)
    assert_equal(email_count, ActionMailer::Base.deliveries.size)

    post(:api_keys,
         api_key: rolfs_key.key,
         app: "Mushroom Mapper",
         for_user: mary.id)
    assert_no_api_errors
    api_key = ApiKey.last
    assert_equal("Mushroom Mapper", api_key.notes)
    assert_users_equal(mary, api_key.user)
    assert_nil(api_key.verified)
    assert_equal(email_count + 1, ActionMailer::Base.deliveries.size)
    email = ActionMailer::Base.deliveries.last
    assert_equal(mary.email, email.header["to"].to_s)
  end

  # Prove user can add Sequence to someone else's Observation
  def test_post_sequence
    obs = observations(:coprinus_comatus_obs)
    post(
      :sequences,
      observation: obs.id,
      api_key:     api_keys(:marys_api_key).key,
      locus:       "ITS",
      bases:       "catg",
      archive:     "GenBank",
      accession:   "KT1234",
      notes:       "sequence notes"
    )
    assert_no_api_errors
    sequence = Sequence.last
    assert_equal(obs, sequence.observation)
    assert_users_equal(mary, sequence.user)
    refute_equal(obs.user, sequence.user)
    assert_equal("ITS", sequence.locus)
    assert_equal("catg", sequence.bases)
    assert_equal("GenBank", sequence.archive)
    assert_equal("KT1234", sequence.accession)
    assert_equal("sequence notes", sequence.notes)
  end
end
