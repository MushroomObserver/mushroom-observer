# encoding: utf-8
require "test_helper"
require "rexml/document"

class ApiControllerTest < FunctionalTestCase
  def assert_no_api_errors
    @api = assigns(:api)
    if @api
      msg = "Caught API Errors:\n" + @api.errors.map do |error|
        error.to_s + "\n" + error.trace.join("\n")
      end.join("\n")
      assert(@api.errors.empty?, msg)
    end
  end

  def post_and_send_file(action, file, content_type, params)
    stream = File.open(file, "rb")
    length = File.size(file)
    checksum = file_checksum(file)
    post_and_send(action, stream, length, content_type, checksum, params)
  end

  def post_and_send_string(action, string, content_type, params)
    stream = StringIO.new(string, "rb")
    length = string.length
    checksum = string_checksum(string)
    post_and_send(action, stream, length, content_type, checksum, params)
  end

  def post_and_send(action, stream, length, type, md5, params)
    @request.env["RAW_POST_DATA"] = stream
    @request.env["CONTENT_LENGTH"] = length
    @request.env["CONTENT_TYPE"] = type
    @request.env["CONTENT_MD5"] = md5
    post(action, params)
    @request.env.delete("RAW_POST_DATA")
  end

  def file_checksum(filename)
    File.open(filename) do |f|
      Digest::MD5.hexdigest(f.read)
    end
  end

  def string_checksum(string)
    Digest::MD5.hexdigest(string)
  end

  ################################################################################

  def test_basic_get_requests
    for model_class in [Comment, Image, Location, Name, Observation, Project,
                        SpeciesList, User]
      for detail in [:none, :low, :high]
        assert_no_api_errors
        get(model_class.table_name.to_sym, detail: detail)
        assert_no_api_errors
        assert_objs_equal(model_class.first, @api.results.first)
      end
    end
  end

  def test_post_minimal_observation
    post(:observations,
         api_key: api_keys(:rolfs_api_key).key,
         location: "Unknown"
        )
    assert_no_api_errors
    obs = Observation.last
    assert_users_equal(rolf, obs.user)
    assert_equal(Date.today.web_date, obs.when.web_date)
    assert_objs_equal(Location.unknown, obs.location)
    assert_nil(obs.where)
    assert_names_equal(names(:fungi), obs.name)
    assert_equal(1, obs.namings.length)
    assert_equal(1, obs.votes.length)
    assert_equal(nil, obs.lat)
    assert_equal(nil, obs.long)
    assert_equal(nil, obs.alt)
    assert_equal(false, obs.specimen)
    assert_equal(true, obs.is_collection_location)
    assert_equal("", obs.notes)
    assert_obj_list_equal([], obs.images)
    assert_nil(obs.thumb_image)
    assert_obj_list_equal([], obs.projects)
    assert_obj_list_equal([], obs.species_lists)
  end

  def test_post_maximal_observation
    post(:observations,
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
    assert_nil(obs.where)
    assert_names_equal(names(:coprinus_comatus), obs.name)
    assert_equal(1, obs.namings.length)
    assert_equal(1, obs.votes.length)
    assert_equal(2.0, obs.votes.first.value)
    assert_equal(34.5678, obs.lat)
    assert_equal(-123.4567, obs.long)
    assert_equal(376, obs.alt)
    assert_equal(true, obs.specimen)
    assert_equal(true, obs.is_collection_location)
    assert_equal("These are notes.\nThey look like this.", obs.notes)
    assert_obj_list_equal([images(:in_situ_image), images(:turned_over_image)], obs.images)
    assert_objs_equal(images(:turned_over_image), obs.thumb_image)
    assert_obj_list_equal([projects(:eol_project)], obs.projects)
    assert_obj_list_equal([species_lists(:another_species_list)],
                          obs.species_lists)
  end

  def test_post_minimal_image
    setup_image_dirs
    count = Image.count
    file = "#{::Rails.root}/test/images/sticky.jpg"
    post_and_send_file(:images, file, "image/jpeg",
                       api_key: api_keys(:rolfs_api_key).key
                      )
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
    post_and_send_file(:images, file, "image/jpeg",
                       api_key: api_keys(:rolfs_api_key).key,
                       vote: "3",
                       date: "20120626",
                       notes: " Here are some notes. ",
                       copyright_holder: "My Friend",
                       license: licenses(:ccnc30).id.to_s,
                       original_name: "Coprinus_comatus.jpg",
                       projects: (proj = rolf.projects_member.first).id,
                       observations: (obs = rolf.observations.first).id
                      )
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
         create_key: "New API Key",
         detail: :high
        )
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
    assert_equal("New API Key", notes.to_s)
  end

  def test_post_api_key
    email_count = ActionMailer::Base.deliveries.size

    rolfs_key = api_keys(:rolfs_api_key)
    post(:api_keys,
         api_key: rolfs_key.key,
         app: "Mushroom Mapper"
        )
    assert_no_api_errors
    api_key = ApiKey.last
    assert_equal("Mushroom Mapper", api_key.notes)
    assert_users_equal(rolf, api_key.user)
    assert_not_nil(api_key.verified)
    assert_equal(email_count, ActionMailer::Base.deliveries.size)

    post(:api_keys,
         api_key: rolfs_key.key,
         app: "Mushroom Mapper",
         for_user: mary.id
        )
    assert_no_api_errors
    api_key = ApiKey.last
    assert_equal("Mushroom Mapper", api_key.notes)
    assert_users_equal(mary, api_key.user)
    assert_nil(api_key.verified)
    assert_equal(email_count + 1, ActionMailer::Base.deliveries.size)
    email = ActionMailer::Base.deliveries.last
    assert_equal(mary.email, email.header["to"].to_s)
  end
end
