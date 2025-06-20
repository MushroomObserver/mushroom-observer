# frozen_string_literal: true

require("test_helper")
require("rexml/document")

class API2ControllerTest < FunctionalTestCase
  def assert_api_failed
    @api = assigns(:api)
    assert_not(@api.errors.empty?, "Expected API to fail with errors.")
  end

  def assert_no_api_errors(msg = nil)
    @api = assigns(:api)
    return unless @api

    msg = format_api_errors(@api, msg)
    assert(@api.errors.empty?, msg)
  end

  def format_api_errors(api, msg)
    lines = [msg, "Caught API2 Errors:"]
    lines += api.errors.map do |error|
      "#{error}\n#{error.trace.join("\n")}"
    end
    lines.compact_blank.join("\n")
  end

  def post_and_send_file(action, file, content_type, params)
    body = Rack::Test::UploadedFile.new(file, "image/jpeg").read
    md5sum = file_checksum(file)
    post_and_send(action, body, content_type, md5sum, params)
  end

  def post_and_send(action, body, content_type, md5sum, params)
    @request.env["CONTENT_TYPE"] = content_type
    @request.env["CONTENT_MD5"] = md5sum
    post(action, params: params, body: body)
  end

  def file_checksum(filename)
    Digest::MD5.file(filename).hexdigest
  end

  def string_checksum(string)
    Digest::MD5.hexdigest(string)
  end

  ##############################################################################

  def test_robot_permissions
    @request.user_agent = "Googlebot"
    obs = Observation.first
    get(:observations, params: { id: obs.id })
    assert_equal(200, @response.status)
  end

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

  def test_basic_location_description_get_request
    do_basic_get_request_for_model(LocationDescription, public: true)
  end

  def test_basic_name_get_request
    do_basic_get_request_for_model(Name)
  end

  def test_basic_name_description_get_request
    do_basic_get_request_for_model(NameDescription, public: true)
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

  def do_basic_get_request_for_model(model, *args)
    # Some models have a default_scope sort order applied.
    # Reorder our expects preventatively to match API2's order.
    expected_object = if args.empty?
                        model.reorder(id: :asc).first
                      else
                        model.reorder(id: :asc).where(*args).first
                      end
    response_formats = [:xml, :json]
    [:none, :low, :high].each do |detail|
      response_formats.each do |format|
        get(model.table_name.to_sym, params: { detail: detail, format: format })
        assert_no_api_errors("Get #{model.name} #{detail} #{format}")
        assert_objs_equal(expected_object, @api.results.first)
      end
    end
  end

  def test_num_of_pages
    get(:observations, params: { detail: :high, format: :json })
    json = response.parsed_body
    assert_equal((Observation.count / 100.0).ceil, json["number_of_pages"],
                 "Number of pages was not correctly calculated.")
  end

  def test_post_minimal_observation
    params = { api_key: api_keys(:rolfs_api_key).key, location: "Earth" }
    post(:observations, params: params)
    assert_no_api_errors
    obs = Observation.last
    assert_users_equal(rolf, obs.user)
    assert_equal(Time.zone.today.web_date, obs.when.web_date)
    assert_objs_equal(Location.unknown, obs.location)
    assert_equal("Earth", obs.where)
    assert_names_equal(names(:fungi), obs.name)
    assert_equal(1, obs.namings.length)
    assert_equal(1, obs.votes.length)
    assert_nil(obs.lat)
    assert_nil(obs.lng)
    assert_nil(obs.alt)
    assert_equal(false, obs.specimen)
    assert_equal(true, obs.is_collection_location)
    assert_equal(Observation.no_notes, obs.notes)
    assert(obs.log_updated_at.is_a?(Time),
           "Observation should have log_updated_at time")
    assert_obj_arrays_equal([], obs.images)
    assert_nil(obs.thumb_image)
    assert_obj_arrays_equal([], obs.projects)
    assert_obj_arrays_equal([], obs.species_lists)
  end

  def test_post_observation_with_code
    params = { api_key: api_keys(:rolfs_api_key).key, location: "Earth",
               code: "EOL-135" }
    post(:observations, params: params)
    assert_no_api_errors
    obs = Observation.last
    assert(obs.field_slips[0].project.observations.include?(obs))
  end

  def test_post_observation_joins_project
    params = { api_key: api_keys(:rolfs_api_key).key, location: "Earth",
               code: "OPEN-135" }
    post(:observations, params: params)
    assert_no_api_errors
    obs = Observation.last
    project = Project.find_by(field_slip_prefix: "OPEN")
    assert(project.member?(obs.user))
  end

  def test_post_maximal_observation
    params = {
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
      code: "EOL-13579",
      species_lists: "Another Observation List"
    }
    post(:observations, params: params)
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
    assert_equal(-123.4567, obs.lng)
    assert_equal(376, obs.alt)
    assert_equal(true, obs.specimen)
    assert_equal(true, obs.is_collection_location)
    assert_equal({ Observation.other_notes_key =>
                   "These are notes.\nThey look like this." }, obs.notes)
    assert_obj_arrays_equal([images(:in_situ_image),
                             images(:turned_over_image)],
                            obs.images.reorder(id: :asc))
    assert_objs_equal(images(:turned_over_image), obs.thumb_image)
    assert_obj_arrays_equal([projects(:eol_project)], obs.projects)
    assert_obj_arrays_equal([species_lists(:another_species_list)],
                            obs.species_lists)
  end

  def test_post_minimal_image
    setup_image_dirs
    count = Image.count
    file = Rails.root.join("test/images/sticky.jpg").to_s
    checksum = file_checksum(file)
    File.stub(:rename, false) do
      post_and_send_file(:images, file, "image/jpeg",
                         api_key: api_keys(:rolfs_api_key).key,
                         detail: :low,
                         format: :xml)
    end
    assert_no_api_errors
    assert_equal(count + 1, Image.count)
    img = Image.last
    assert_users_equal(rolf, img.user)
    assert_equal(Time.zone.today.web_date, img.when.web_date)
    assert_equal("", img.notes)
    assert_equal(rolf.legal_name, img.copyright_holder)
    assert_objs_equal(rolf.license, img.license)
    assert_nil(img.original_name)
    assert_equal("image/jpeg", img.content_type)
    assert_equal(407, img.width)
    assert_equal(500, img.height)
    assert_obj_arrays_equal([], img.projects)
    assert_obj_arrays_equal([], img.observations)
    doc = REXML::Document.new(@response.body)
    checksum_returned = doc.root.elements["results/result/md5sum"].get_text.to_s
    assert_equal(checksum, checksum_returned, "Didn't get the right checksum.")
  end

  def test_post_minimal_image_via_multipart_form_data
    setup_image_dirs
    count = Image.count
    file = Rails.root.join("test/images/sticky.jpg").to_s
    upload = UploadedFileWithChecksum.new(file, "image/jpeg")
    checksum = file_checksum(file)
    File.stub(:rename, false) do
      params = {
        api_key: api_keys(:rolfs_api_key).key,
        upload: upload,
        md5sum: checksum,
        detail: :low,
        format: :json
      }
      post(:images, params: params)
    end
    assert_no_api_errors
    assert_equal(count + 1, Image.count)
    json = response.parsed_body
    checksum_returned = json["results"][0]["md5sum"].to_s
    assert_equal(checksum, checksum_returned, "Didn't get the right checksum.")
  end

  def test_post_corrupt_image
    setup_image_dirs
    count = Image.count
    file = Rails.root.join("test/images/sticky.jpg").to_s
    upload = UploadedFileWithChecksum.new(file, "image/jpeg")
    checksum = file_checksum(file).reverse
    File.stub(:rename, false) do
      params = {
        api_key: api_keys(:rolfs_api_key).key,
        upload: upload,
        md5sum: checksum,
        detail: :low,
        format: :json
      }
      post(:images, params: params)
    end
    assert_api_failed
    assert_equal(count, Image.count)
    assert_match(/MD5/, @api.errors.first.to_s)
  end

  def test_post_maximal_image
    setup_image_dirs
    rolf.update(keep_filenames: "keep_and_show")
    rolf.reload
    file = Rails.root.join("test/images/Coprinus_comatus.jpg").to_s
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
    assert_obj_arrays_equal([proj], img.projects)
    assert_obj_arrays_equal([obs], img.observations)
  end

  def test_post_user
    rolfs_key = api_keys(:rolfs_api_key)
    params = {
      api_key: rolfs_key.key,
      login: "miles",
      email: "miles@davis.com",
      password: "sivadselim",
      create_key: "New API2 Key",
      detail: :high,
      format: :xml
    }
    post(:users, params: params)
    assert_no_api_errors
    user = User.last
    assert_equal("miles", user.login)
    assert_false(user.verified)
    assert_equal(1, user.api_keys.length)
    doc = REXML::Document.new(@response.body)
    keys = doc.root.elements["results/result/api_keys"]
    num = begin
            keys.attribute("number").value
          rescue StandardError
            nil
          end
    assert_equal("1", num.to_s)
    key = begin
            keys.elements["api_key/key"].get_text
          rescue StandardError
            nil
          end
    notes = begin
              keys.elements["api_key/notes"].get_text
            rescue StandardError
              nil
            end
    assert_not_equal("", key.to_s)
    assert_equal(CGI.escapeHTML("New API2 Key"), notes.to_s)
  end

  # NOTE: Checking ActionMailer::Base.deliveries works here only because
  #       QueuedEmail.queue == false.
  #       The mail is sent via QueuedEmail but delivered immediately.
  def test_post_api_key
    QueuedEmail.queue = false
    email_count = ActionMailer::Base.deliveries.size

    rolfs_key = api_keys(:rolfs_api_key)
    params = {
      api_key: rolfs_key.key,
      app: "Mushroom Mapper"
    }
    post(:api_keys, params: params)
    assert_no_api_errors
    api_key = APIKey.last
    assert_equal("Mushroom Mapper", api_key.notes)
    assert_users_equal(rolf, api_key.user)
    assert_not_nil(api_key.verified)
    assert_equal(email_count, ActionMailer::Base.deliveries.size)

    params = {
      api_key: rolfs_key.key,
      app: "Mushroom Mapper",
      for_user: mary.id
    }
    post(:api_keys, params: params)
    assert_no_api_errors
    api_key = APIKey.last
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
    params = {
      observation: obs.id,
      api_key: api_keys(:marys_api_key).key,
      locus: "ITS",
      bases: "catg",
      archive: "GenBank",
      accession: "KT1234",
      notes: "sequence notes"
    }
    post(:sequences, params: params)
    assert_no_api_errors
    sequence = Sequence.last
    assert_equal(obs, sequence.observation)
    assert_users_equal(mary, sequence.user)
    assert_not_equal(obs.user, sequence.user)
    assert_equal("ITS", sequence.locus)
    assert_equal("catg", sequence.bases)
    assert_equal("GenBank", sequence.archive)
    assert_equal("KT1234", sequence.accession)
    assert_equal("sequence notes", sequence.notes)
  end

  def test_get_observation_with_gps_hidden
    obs = observations(:unknown_with_lat_lng)
    get(:observations, params: { id: obs.id, detail: :high, format: :json })
    assert_match(/34.1622|118.3521/, @response.body)
    get(:observations, params: { id: obs.id, detail: :high, format: :xml })
    assert_match(/34.1622|118.3521/, @response.body)

    obs.update(gps_hidden: true)
    get(:observations, params: { id: obs.id, detail: :high, format: :json })
    assert_no_match(/34.1622|118.3521/, @response.body)
    get(:observations, params: { id: obs.id, detail: :high, format: :xml })
    assert_no_match(/34.1622|118.3521/, @response.body)
  end

  def test_get_empty_results
    params = { date: "2100-01-01" }
    get(:observations, params: params.merge(format: :json, detail: :none))
    get(:observations, params: params.merge(format: :json, detail: :high))
    get(:observations, params: params.merge(format: :xml, detail: :none))
    get(:observations, params: params.merge(format: :xml, detail: :high))
  end

  def test_routing
    assert_routing({ path: "/api2/comments", method: :delete },
                   { controller: "api2", action: "comments" })
    assert_routing({ path: "/api2/comments", method: :patch },
                   { controller: "api2", action: "comments" })
  end

  def test_vote_anonymity
    obs = observations(:coprinus_comatus_obs)
    rolf.update!(votes_anonymous: "yes")
    rolfs_key = api_keys(:rolfs_api_key)
    marys_key = api_keys(:marys_api_key)
    rolfs_vote = obs.votes.find_by(user: rolf)
    marys_vote = obs.votes.find_by(user: mary)
    assert_users_equal(rolf, obs.user)

    params = { detail: :high, id: obs.id }

    params[:format] = :json
    get(:observations, params: params.merge(api_key: rolfs_key.key))
    json = response.parsed_body
    votes = json["results"][0]["votes"]
    assert_equal(
      :anonymous.l,
      votes.find { |v| v["id"] == rolfs_vote.id }["owner"]
    )
    assert_equal(
      "mary",
      votes.find { |v| v["id"] == marys_vote.id }["owner"]["login_name"]
    )

    get(:observations, params: params.merge(api_key: marys_key.key))
    json = response.parsed_body
    votes = json["results"][0]["votes"]
    assert_equal(
      :anonymous.l,
      votes.find { |v| v["id"] == rolfs_vote.id }["owner"]
    )
    assert_equal(
      "mary",
      votes.find { |v| v["id"] == marys_vote.id }["owner"]["login_name"]
    )

    params[:format] = :xml
    get(:observations, params: params.merge(api_key: rolfs_key.key))
    doc = REXML::Document.new(response.body)
    votes = doc.root.elements["results/result/votes"]
    check_anonymity(votes, rolfs_vote, true)
    check_anonymity(votes, marys_vote, false)

    get(:observations, params: params.merge(api_key: marys_key.key))
    doc = REXML::Document.new(response.body)
    votes = doc.root.elements["results/result/votes"]
    check_anonymity(votes, rolfs_vote, true)
    check_anonymity(votes, marys_vote, false)
  end

  def check_anonymity(elements, vote, anonymous)
    elements.each do |elem|
      next unless elem.is_a?(REXML::Element)
      next unless elem.attributes["id"] == vote.id.to_s

      assert_equal(anonymous ? "string" : "user",
                   elem.elements["owner"].attributes["type"])
    end
  end
end

class UploadedFileWithChecksum < Rack::Test::UploadedFile
  attr_accessor :checksum
end
