# encoding: utf-8

require "test_helper"

class Hash
  def remove(*keys)
    reject do |key, _val|
      keys.include?(key)
    end
  end
end

class ApiTest < UnitTestCase
  def setup
    @api_key = api_keys(:rolfs_api_key)
    super
  end

  # --------------------
  #  :section: Helpers
  # --------------------

  def aor(*args)
    API::OrderedRange.new(*args)
  end

  def date(str)
    Date.parse(str)
  end

  def time(str)
    DateTime.parse(str + " UTC")
  end

  def assert_no_errors(api, msg = "API errors")
    msg = "#{msg}: <\n" + api.errors.map(&:to_s).join("\n") + "\n>"
    assert(api.errors.empty?, msg)
  end

  def assert_api_fail(params)
    @api = API.execute(params)
    msg = "API request should have failed, params: #{params.inspect}"
    assert(@api.errors.any?, msg)
  end

  def assert_api_pass(params)
    @api = API.execute(params)
    msg = "API request should have passed, params: #{params.inspect}"
    assert_no_errors(@api, msg)
  end

  def assert_api_results(expect)
    msg = "API results wrong.  Query: #{@api.query.query}"
    assert_obj_list_equal(expect, @api.results, msg)
  end

  def assert_parse(*args)
    assert_parse_general(:parse, *args)
  end

  def assert_parse_a(*args)
    assert_parse_general(:parse_array, *args)
  end

  def assert_parse_r(*args)
    assert_parse_general(:parse_range, *args)
  end

  def assert_parse_rs(*args)
    assert_parse_general(:parse_ranges, *args)
  end

  def assert_parse_general(method, type, expect, val, *args)
    @api ||= API.new
    val = val.to_s if val
    begin
      actual = @api.send(method, type, val, *args)
    rescue API::Error => e
      actual = e
    end
    msg = "Expected: <#{show_val(expect)}>\n" \
          "Got: <#{show_val(actual)}>\n"
    if expect.is_a?(Class) && expect <= API::Error
      assert(actual.is_a?(expect), msg)
    else
      assert(actual == expect, msg)
    end
  end

  def show_val(val)
    case val
    when NilClass, TrueClass, FalseClass, String, Symbol, Integer, Float
      val.inspect
    when Array
      "[" + val.map { |v| show_val(v) }.join(", ") + "]"
    when Hash
      "{" + val.map { |k, v| show_val(k) + ": " + show_val(v) }.join(", ") + "}"
    else
      "#{val.class}: #{val}"
    end
  end

  def assert_last_api_key_correct
    api_key = ApiKey.last
    assert_in_delta(Time.zone.now, api_key.created_at, 1.minute)
    if @verified
      assert_in_delta(Time.zone.now, api_key.verified, 1.minute)
    else
      assert_nil(api_key.verified)
    end
    assert_nil(api_key.last_used)
    assert_equal(0, api_key.num_uses)
    assert_equal(@app.strip_squeeze, api_key.notes)
    assert_users_equal(@for_user, api_key.user)
  end

  def assert_last_comment_correct
    com = Comment.last
    assert_users_equal(@user, com.user)
    assert_in_delta(Time.zone.now, com.created_at, 1.minute)
    assert_in_delta(Time.zone.now, com.updated_at, 1.minute)
    assert_objs_equal(@target, com.target)
    assert_equal(@summary.strip, com.summary)
    assert_equal(@content.strip, com.comment)
  end

  def assert_last_image_correct
    img = Image.last
    assert_users_equal(@user, img.user)
    assert_in_delta(Time.zone.now, img.created_at, 1.minute)
    assert_in_delta(Time.zone.now, img.updated_at, 1.minute)
    assert_equal("image/jpeg", img.content_type)
    assert_equal(@date, img.when)
    assert_equal(@notes.strip, img.notes)
    assert_equal(@copy.strip, img.copyright_holder)
    assert_equal(@user.license, img.license)
    assert_equal(0, img.num_views)
    assert_nil(img.last_view)
    assert_equal(@width, img.width)
    assert_equal(@height, img.height)
    assert(@vote == img.vote_cache)
    assert_equal(true, img.ok_for_export)
    assert(@orig == img.original_name)
    assert_equal(false, img.transferred)
    assert_obj_list_equal([@proj].reject(&:nil?), img.projects)
    assert_obj_list_equal([@obs].reject(&:nil?), img.observations)
    assert(@vote == img.users_vote(@user))
  end

  def assert_last_location_correct
    loc = Location.last
    assert_in_delta(Time.zone.now, loc.created_at, 1.minute)
    assert_in_delta(Time.zone.now, loc.updated_at, 1.minute)
    assert_users_equal(@user, loc.user)
    assert_equal(@name, loc.display_name)
    assert_in_delta(@north, loc.north, 0.0001)
    assert_in_delta(@south, loc.south, 0.0001)
    assert_in_delta(@east, loc.east, 0.0001)
    assert_in_delta(@west, loc.west, 0.0001)
    assert_in_delta(@high, loc.high, 0.0001) if @high
    assert_nil(loc.high) if !@high
    assert_in_delta(@low, loc.low, 0.0001) if @low
    assert_nil(loc.low) if !@low
    assert_equal(@notes, loc.notes) if @notes
    assert_nil(loc.notes) if !@notes
  end

  def assert_last_naming_correct
    obs = Observation.last
    naming = Naming.last
    vote = Vote.last
    assert_names_equal(@name, naming.name)
    assert_objs_equal(obs, naming.observation)
    assert_users_equal(@user, naming.user)
    assert_in_delta(@vote, naming.vote_cache, 1) # vote_cache is weird
    assert_in_delta(Time.zone.now, naming.created_at, 1.minute)
    assert_in_delta(Time.zone.now, naming.updated_at, 1.minute)
    assert_equal(1, naming.votes.length)
    assert_objs_equal(vote, naming.votes.first)
  end

  def assert_last_observation_correct
    obs = Observation.last
    assert_in_delta(Time.zone.now, obs.created_at, 1.minute)
    assert_in_delta(Time.zone.now, obs.updated_at, 1.minute)
    assert_equal(@date.web_date, obs.when.web_date)
    assert_users_equal(@user, obs.user)
    assert_equal(@specimen, obs.specimen)
    assert_equal(@notes, obs.notes)
    assert_objs_equal(@img2, obs.thumb_image)
    assert_obj_list_equal([@img1, @img2].reject(&:nil?), obs.images)
    assert_objs_equal(@loc, obs.location)
    assert_nil(obs.where)
    assert_equal(@loc.name, obs.place_name)
    assert_equal(@is_col_loc, obs.is_collection_location)
    assert_equal(0, obs.num_views)
    assert_nil(obs.last_view)
    assert_not_nil(obs.rss_log)
    assert(@lat == obs.lat)
    assert(@long == obs.long)
    assert(@alt == obs.alt)
    assert_obj_list_equal([@proj].reject(&:nil?), obs.projects)
    assert_obj_list_equal([@spl].reject(&:nil?), obs.species_lists)
    assert_names_equal(@name, obs.name)
    assert_in_delta(@vote, obs.vote_cache, 1) # vote_cache is weird
    if @name
      assert_equal(1, obs.namings.length)
      assert_objs_equal(Naming.last, obs.namings.first)
      assert_equal(1, obs.votes.length)
      assert_objs_equal(Vote.last, obs.votes.first)
    else
      assert_equal(0, obs.namings.length)
      assert_equal(0, obs.votes.length)
    end
  end

  def assert_last_user_correct
    user = User.last
    assert_equal(@login, user.login)
    assert_equal(@name, user.name)
    assert_equal(@email, user.email)
    assert_not_equal("", user.password)
    assert_in_delta(Time.zone.now, user.created_at, 1.minute)
    assert_in_delta(Time.zone.now, user.updated_at, 1.minute)
    assert_nil(user.verified)
    assert_nil(user.last_activity)
    assert_nil(user.last_login)
    assert_equal(false, user.admin)
    assert_equal(0, user.contribution)
    assert_nil(user.bonuses)
    assert_nil(user.alert)
    assert_equal(Language.lang_from_locale(@locale), user.lang)
    assert_equal(@notes.strip, user.notes)
    assert_equal(@address.strip, user.mailing_address)
    assert_objs_equal(@license, user.license)
    assert_objs_equal(@location, user.location)
    assert_objs_equal(@image, user.image)
    if @new_key
      assert_equal(1, user.api_keys.length)
      assert_equal(@new_key.strip_squeeze, user.api_keys.first.notes)
    else
      assert_equal(0, user.api_keys.length)
    end
  end

  def assert_last_vote_correct
    obs = Observation.last
    naming = Naming.last
    vote = Vote.last
    assert_objs_equal(naming, vote.naming)
    assert_objs_equal(obs, vote.observation)
    assert_users_equal(@user, vote.user)
    assert_equal(@vote, vote.value)
    assert_in_delta(Time.zone.now, vote.created_at, 1.minute)
    assert_in_delta(Time.zone.now, vote.updated_at, 1.minute)
    assert_true(vote.favorite)
  end

  ##############################################################################

  def test_basic_gets
    [Comment, ExternalLink, Image, Location, Name, Observation, Project,
     Sequence, SpeciesList, User].each do |model|
      expected_object = model.first
      api = API.execute(
        method: :get,
        action: model.type_tag,
        id: expected_object.id
      )
      assert_no_errors(api, "Errors while getting first #{model}")
      assert_obj_list_equal([expected_object], api.results,
                            "Failed to get first #{model}")
    end
  end

  # ----------------------------
  #  :section: ApiKey Requests
  # ----------------------------

  def test_getting_api_keys
    params = {
      method:   :patch,
      action:   :api_key,
      api_key:  @api_key.key,
      user:     rolf.id
    }
    # No GET requests allowed now.
    assert_api_fail(params)
  end

  def test_posting_api_key_for_yourself
    email_count = ActionMailer::Base.deliveries.size
    @for_user = rolf
    @app = "  Mushroom  Mapper  "
    @verified = true
    params = {
      method:  :post,
      action:  :api_key,
      api_key: @api_key.key,
      app:     @app
    }
    api = API.execute(params)
    assert_no_errors(api, "Errors while posting image")
    assert_obj_list_equal([ApiKey.last], api.results)
    assert_last_api_key_correct
    assert_api_fail(params.remove(:api_key))
    assert_api_fail(params.remove(:app))
    assert_equal(email_count, ActionMailer::Base.deliveries.size)
  end

  def test_posting_api_key_for_another_user
    email_count = ActionMailer::Base.deliveries.size
    @for_user = katrina
    @app = "  Mushroom  Mapper  "
    @verified = false
    params = {
      method:   :post,
      action:   :api_key,
      api_key:  @api_key.key,
      app:      @app,
      for_user: @for_user.id
    }
    api = API.execute(params)
    assert_no_errors(api, "Errors while posting image")
    assert_obj_list_equal([ApiKey.last], api.results)
    assert_last_api_key_correct
    assert_api_fail(params.remove(:api_key))
    assert_api_fail(params.remove(:app))
    assert_api_fail(params.merge(app: ""))
    assert_api_fail(params.merge(for_user: 123_456))
    assert_equal(email_count + 1, ActionMailer::Base.deliveries.size)
  end

  def test_updating_api_keys
    params = {
      method:   :patch,
      action:   :api_key,
      api_key:  @api_key.key,
      id:       @api_key.id,
      set_app:  "new app"
    }
    # No PATCH requests allowed now.
    assert_api_fail(params)
  end

  def test_deleting_api_keys
    params = {
      method:   :delete,
      action:   :api_key,
      api_key:  @api_key.key,
      id:       @api_key.id,
    }
    # No DELETE requests allowed now.
    assert_api_fail(params)
  end

  # -----------------------------
  #  :section: Comment Requests
  # -----------------------------

  def test_getting_comments
    params = { method: :get, action: :comment }
    com1 = comments(:minimal_unknown_obs_comment_1)
    com2 = comments(:minimal_unknown_obs_comment_2)
    com3 = comments(:detailed_unknown_obs_comment)

    assert_api_pass(params.merge(id: com1.id))
    assert_api_results([com1])

    assert_api_pass(params.merge(created_at: "2006-03-02 21:16:00"))
    assert_api_results([com2])

    assert_api_pass(params.merge(updated_at: "2007-03-02 21:16:00"))
    assert_api_results([com3])

    assert_api_pass(params.merge(user: "rolf,dick"))
    expect = Comment.where(user: rolf) + Comment.where(user: dick)
    assert_api_results(expect.sort_by(&:id))

    assert_api_pass(params.merge(type: "Observation"))
    expect = Comment.where(target_type: "Observation")
    assert_api_results(expect.sort_by(&:id))

    assert_api_pass(params.merge(summary_has: "complicated"))
    assert_api_results([com2])

    assert_api_pass(params.merge(content_has: "really cool"))
    assert_api_results([com1])

    obs = observations(:minimal_unknown_obs)
    assert_api_pass(params.merge(target: "observation ##{obs.id}"))
    assert_api_results(obs.comments.sort_by(&:id))
  end

  def test_posting_comments
    @user    = rolf
    @target  = names(:petigera)
    @summary = "misspelling"
    @content = "The correct one is 'Peltigera'."
    params = {
      method:  :post,
      action:  :comment,
      api_key: @api_key.key,
      target:  "name ##{@target.id}",
      summary: @summary,
      content: @content
    }
    assert_api_fail(params.remove(:api_key))
    assert_api_fail(params.remove(:target))
    assert_api_fail(params.remove(:summary))
    assert_api_fail(params.merge(target: "foo #1"))
    assert_api_fail(params.merge(target: "observation #1"))
    assert_api_pass(params)
    assert_last_comment_correct
  end

  def test_updating_comments
    com1 = comments(:minimal_unknown_obs_comment_1) # rolf's comment
    com2 = comments(:minimal_unknown_obs_comment_2) # dick's comment
    params = {
      method:      :patch,
      action:      :comment,
      api_key:     @api_key.key,
      id:          com1.id,
      set_summary: "new summary",
      set_content: "new comment"
    }
    assert_api_fail(params.remove(:api_key))
    assert_api_fail(params.merge(id: com2.id))
    assert_api_pass(params)
    com1.reload
    assert_equal("new summary", com1.reload.summary)
    assert_equal("new comment", com1.reload.comment)
  end

  def test_deleting_comments
    com1 = comments(:minimal_unknown_obs_comment_1) # rolf's comment
    com2 = comments(:minimal_unknown_obs_comment_2) # dick's comment
    params = {
      method:      :delete,
      action:      :comment,
      api_key:     @api_key.key,
      id:          com1.id
    }
    assert_api_fail(params.remove(:api_key))
    assert_api_fail(params.merge(id: com2.id))
    assert_api_pass(params)
    assert_nil(Comment.safe_find(com1.id))
  end

  # ----------------------------------
  #  :section: ExternalLink Requests
  # ----------------------------------

  def test_getting_external_links
    other_obs = observations(:agaricus_campestris_obs)
    link1 = external_links(:coprinus_comatus_obs_mycoportal_link)
    link2 = external_links(:coprinus_comatus_obs_inaturalist_link)
    link3 = ExternalLink.create!(user: rolf, observation: other_obs,
                                 external_site: link1.external_site,
                                 url: "http://nowhere.com")
    params = { method: :get, action: :external_link }

    assert_api_pass(params.merge(id: link2.id))
    assert_api_results([link2])

    assert_api_pass(params.merge(created_at: "2016-12-29"))
    assert_api_results([link1])

    assert_api_pass(params.merge(updated_at: "2016-11-11-2017-11-11"))
    assert_api_results([link1, link2])

    assert_api_pass(params.merge(user: "rolf"))
    assert_api_results([link3])

    assert_api_pass(params.merge(observation: other_obs.id))
    assert_api_results([link3])
    assert_api_pass(params.merge(observation: link1.observation.id))
    assert_api_results([link1, link2])

    assert_api_pass(params.merge(external_site: "mycoportal"))
    assert_api_results([link1, link3])

    assert_api_pass(params.merge(url: link2.url))
    assert_api_results([link2])
  end

    def test_posting_external_links
      marys_obs = observations(:detailed_unknown_obs)
      rolfs_obs = observations(:agaricus_campestris_obs)
      katys_obs = observations(:amateur_obs)
      marys_key = api_keys(:marys_api_key)
      rolfs_key = api_keys(:rolfs_api_key)
      params = {
        method:        :post,
        action:        :external_link,
        api_key:       rolfs_key.key,
        observation:   rolfs_obs.id,
        external_site: external_sites(:mycoportal).id,
        url:           "http://blah.blah"
      }
      assert_api_pass(params)
      assert_api_fail(params.remove(:api_key))
      assert_api_fail(params.remove(:observation))
      assert_api_fail(params.remove(:external_site))
      assert_api_fail(params.remove(:url))
      assert_api_fail(params.merge(api_key: "spammer"))
      assert_api_fail(params.merge(observation: "spammer"))
      assert_api_fail(params.merge(external_site: "spammer"))
      assert_api_fail(params.merge(url: "spammer"))
      assert_api_fail(params.merge(observation: marys_obs.id))
      assert_api_fail(params.merge(api_key: marys_key.key)) # already exists!
      assert_api_pass(params.merge(api_key: marys_key.key,
                                   observation: katys_obs.id))
    end

  # ---------------------------
  #  :section: Image Requests
  # ---------------------------

  def test_getting_images
    img = Image.all.sample
    params = { method: :get, action: :image }

    assert_api_pass(params.merge(id: img.id))
    assert_api_results([img])

    assert_api_pass(params.merge(created_at: "2006"))
    assert_api_results(Image.where("year(created_at) = 2006"))

    assert_api_pass(params.merge(updated_at: "2006-05-22"))
    assert_api_results(Image.where('date(updated_at) = "2006-05-22"'))

    assert_api_pass(params.merge(date: "2007-03"))
    assert_api_results(Image.where("year(`when`) = 2007 and month(`when`) = 3"))

    assert_api_pass(params.merge(user: "#{mary.id},#{katrina.id}"))
    assert_api_results(Image.where(user: [mary, katrina]))

    name = names(:agaricus_campestris)
    imgs = name.observations.map(&:images).flatten
    assert_not_empty(imgs)
    assert_api_pass(params.merge(name: "Agaricus campestris"))
    assert_api_results(imgs)

    name2 = names(:agaricus_campestros)
    synonym = Synonym.create!
    name.update_attributes!(synonym: synonym)
    name2.update_attributes!(synonym: synonym)
    assert_api_pass(params.merge(synonyms_of: "Agaricus campestros"))
    assert_api_results(imgs)

    assert_api_pass(params.merge(children_of: "Agaricus"))
    assert_api_results(imgs)

    burbank = locations(:burbank)
    imgs = burbank.observations.map(&:images).flatten
    assert_not_empty(imgs)
    assert_api_pass(params.merge(location: burbank.id))
    assert_api_results(imgs)

    project = projects(:bolete_project)
    assert_not_empty(project.images)
    assert_api_pass(params.merge(project: "Bolete Project"))
    assert_api_results(project.images)

    img1 = images(:in_situ_image)
    img2 = images(:turned_over_image)
    spl  = species_lists(:unknown_species_list)
    assert_api_pass(params.merge(species_list: spl.title))
    assert_api_results([img1, img2])

    attached   = Image.all.select {|i| i.observations.count > 0}
    unattached = Image.all - attached
    assert_not_empty(attached)
    assert_not_empty(unattached)
    assert_api_pass(params.merge(has_observation: "yes"))
    assert_api_results(attached)
    # This query doesn't work, no way to negate join.
    # assert_api_pass(params.merge(has_observation: "no"))
    # assert_api_results(unattached)

    imgs = Image.where("width >= 1280 || height >= 1280")
    assert_empty(imgs)
    imgs = Image.where("width >= 960 || height >= 960")
    assert_not_empty(imgs)
    assert_api_pass(params.merge(size: "huge"))
    assert_api_results([])
    assert_api_pass(params.merge(size: "large"))
    assert_api_results(imgs)

    img1.update_attributes!(content_type: "image/png")
    assert_api_pass(params.merge(content_type: "png"))
    assert_api_results([img1])

    noteless_img = images(:rolf_profile_image)
    assert_api_pass(params.merge(has_notes: "no"))
    assert_api_results([noteless_img])

    pretty_img = images(:peltigera_image)
    assert_api_pass(params.merge(notes_has: "pretty"))
    assert_api_results([pretty_img])

    assert_api_pass(params.merge(copyright_holder_has: "Insil Choi"))
    assert_api_results(Image.where("copyright_holder like '%insil choi%'"))
    assert_api_pass(params.merge(copyright_holder_has: "Nathan"))
    assert_api_results(Image.where("copyright_holder like '%nathan%'"))

    pd = licenses(:publicdomain)
    assert_api_pass(params.merge(license: pd.id))
    assert_api_results(Image.where(license: pd))

    assert_api_pass(params.merge(has_votes: "yes"))
    assert_api_results(Image.where("vote_cache IS NOT NULL"))
    assert_api_pass(params.merge(has_votes: "no"))
    assert_api_results(Image.where("vote_cache IS NULL"))

    assert_api_pass(params.merge(quality: "2-3"))
    assert_api_results(Image.where("vote_cache > 2.0"))
    assert_api_pass(params.merge(quality: "1-2"))
    assert_api_results([])

    imgs = Observation.where("vote_cache >= 2.0").map(&:images).flatten
    assert_not_empty(imgs)
    assert_api_pass(params.merge(confidence: "2-3"))
    assert_api_results(imgs)

    pretty_img.update_attributes!(ok_for_export: false)
    assert_api_pass(params.merge(ok_for_export: "no"))
    assert_api_results([pretty_img])
  end

  def test_posting_minimal_image
    setup_image_dirs
    @user   = rolf
    @proj   = nil
    @date   = Time.now.in_time_zone("GMT").to_date
    @copy   = @user.legal_name
    @notes  = ""
    @orig   = nil
    @width  = 407
    @height = 500
    @vote   = nil
    @obs    = nil
    params  = {
      method:      :post,
      action:      :image,
      api_key:     @api_key.key,
      upload_file: "#{::Rails.root}/test/images/sticky.jpg"
    }
    api = API.execute(params)
    assert_no_errors(api, "Errors while posting image")
    assert_obj_list_equal([Image.last], api.results)
    assert_last_image_correct
  end

  def test_posting_maximal_image
    setup_image_dirs
    @user   = rolf
    @proj   = projects(:eol_project)
    @date   = date("20120626")
    @copy   = "My Friend"
    @notes  = "These are notes.\nThey look like this.\n"
    @orig   = "sticky.png"
    @width  = 407
    @height = 500
    @vote   = 3
    @obs    = @user.observations.last
    params  = {
      method:           :post,
      action:           :image,
      api_key:          @api_key.key,
      date:             "20120626",
      notes:            @notes,
      copyright_holder: " My Friend ",
      license:          @user.license.id,
      vote:             "3",
      observations:     @obs.id,
      projects:         @proj.id,
      upload_file:      "#{::Rails.root}/test/images/sticky.jpg",
      original_name:    @orig
    }
    api = API.execute(params)
    assert_no_errors(api, "Errors while posting image")
    assert_obj_list_equal([Image.last], api.results)
    assert_last_image_correct
    assert_api_fail(params.remove(:api_key))
    assert_api_fail(params.remove(:upload_file))
    assert_api_fail(params.merge(original_name: "x" * 1000))
    assert_api_fail(params.merge(vote: "-5"))

    obs = Observation.where(user: katrina).first
    assert_api_fail(params.merge(observations: obs.id.to_s))
    # Rolf is not a member of this project
    assert_api_fail(params.merge(projects: projects(:bolete_project).id.to_s))
  end

  def test_posting_image_via_url
    setup_image_dirs
    url = "http://mushroomobserver.org/images/thumb/459340.jpg"
    stub_request(:any, url).
      to_return(File.read("#{::Rails.root}/test/images/test_image.curl"))
    params = {
      method:     :post,
      action:     :image,
      api_key:    @api_key.key,
      upload_url: url
    }
    api = API.execute(params)
    assert_no_errors(api, "Errors while posting image")
    img = Image.last
    assert_obj_list_equal([img], api.results)
    actual = File.read(img.local_file_name(:full_size))
    expect = File.read("#{::Rails.root}/test/images/test_image.jpg")
    assert_equal(expect, actual, "Uploaded image differs from original!")
  end

    def test_updating_images
      rolfs_img = images(:rolf_profile_image)
      marys_img = images(:in_situ_image)
      eol = projects(:eol_project)
      pd = licenses(:publicdomain)
      assert(rolfs_img.has_edit_permission?(rolf))
      assert(!marys_img.has_edit_permission?(rolf))
      params = {
        method:               :patch,
        action:               :image,
        api_key:              @api_key.key,
        set_date:             "2012-3-4",
        set_notes:            "new notes",
        set_copyright_holder: "new person",
        set_license:          pd.id,
        set_original_name:    "new name"
      }
      assert_api_fail(params.merge(id: marys_img.id))
      assert_api_pass(params.merge(id: rolfs_img.id))
      rolfs_img.reload
      assert_equal(Date.parse("2012-3-4"), rolfs_img.when)
      assert_equal("new notes", rolfs_img.notes)
      assert_equal("new person", rolfs_img.copyright_holder)
      assert_objs_equal(pd, rolfs_img.license)
      assert_equal("new name", rolfs_img.original_name)
      eol.images << marys_img
      marys_img.reload
      assert(marys_img.has_edit_permission?(rolf))
      assert_api_pass(params.merge(id: marys_img.id))
      marys_img.reload
      assert_equal(Date.parse("2012-3-4"), marys_img.when)
      assert_equal("new notes", marys_img.notes)
      assert_equal("new person", marys_img.copyright_holder)
      assert_objs_equal(pd, marys_img.license)
      assert_equal("new name", marys_img.original_name)
    end

    def test_deleting_images
      rolfs_img = rolf.images.sample
      marys_img = mary.images.sample
      params = {
        method:  :delete,
        action:  :image,
        api_key: @api_key.key,
      }
      assert_api_fail(params.merge(id: marys_img.id))
      assert_api_pass(params.merge(id: rolfs_img.id))
      assert_not_nil(Image.safe_find(marys_img.id))
      assert_nil(Image.safe_find(rolfs_img.id))
    end

  # ------------------------------
  #  :section: Location Requests
  # ------------------------------

  def test_getting_locations
    loc = Location.all.sample
    params = { method: :get, action: :location }

    assert_api_pass(params.merge(id: loc.id))
    assert_api_results([loc])

    locs = Location.where("year(created_at) = 2008")
    assert_not_empty(locs)
    assert_api_pass(params.merge(created_at: "2008"))
    assert_api_results(locs)

    locs = Location.where("date(created_at) = '2012-01-01'")
    assert_not_empty(locs)
    assert_api_pass(params.merge(updated_at: "2012-01-01"))
    assert_api_results(locs)

    locs = Location.where(user: rolf)
    assert_not_empty(locs)
    assert_api_pass(params.merge(user: "rolf"))
    assert_api_results(locs)

    locs = Location.where("south > 39 and north < 40 and west > -124 and
                           east < -123 and west < east")
    assert_not_empty(locs)
    assert_api_fail(params.merge(south: 39, east: -123, west: -124))
    assert_api_fail(params.merge(north: 40, east: -123, west: -124))
    assert_api_fail(params.merge(north: 40, south: 39, west: -124))
    assert_api_fail(params.merge(north: 40, south: 39, east: -123))
    assert_api_pass(params.merge(north: 40, south: 39, east: -123, west: -124))
    assert_api_results(locs)
  end

  def test_posting_locations
    name1  = "Reno, Nevada, USA"
    name2  = "Sparks, Nevada, USA"
    name3  = "Evil Lair, Latveria"
    name4  = "Nowhere, East Paduka, USA"
    name5  = "Washoe County, Nevada, USA"
    @name  = name1
    @north = 39.64
    @south = 39.39
    @east  = -119.70
    @west  = -119.94
    @high  = 1700
    @low   = 1350
    @notes = "Biggest Little City"
    @user  = rolf
    params = {
      method:  :post,
      action:  :location,
      api_key: @api_key.key,
      name:    @name,
      north:   @north,
      south:   @south,
      east:    @east,
      west:    @west,
      high:    @high,
      low:     @low,
      notes:   @notes
    }
    name = params[:name]
    assert_api_pass(params)
    assert_last_location_correct
    assert_api_fail(params)
    assert_api_fail(params.merge(name: name3))
    assert_api_fail(params.merge(name: name4))
    assert_api_fail(params.merge(name: name5))
    params[:name] = @name = name2
    assert_api_fail(params.remove(:api_key))
    assert_api_fail(params.remove(:name))
    assert_api_fail(params.remove(:north))
    assert_api_fail(params.remove(:south))
    assert_api_fail(params.remove(:east))
    assert_api_fail(params.remove(:west))
    assert_api_fail(params.remove(:north, :south, :east, :west))
    assert_api_pass(params.remove(:high, :low, :notes))
    @high = @low = @notes = nil
    assert_last_location_correct
  end

  def test_updating_locations
    loc = locations(:burbank)
    params = {
      method:    :patch,
      action:    :location,
      api_key:   @api_key.key,
      id:        loc.id,
      set_name:  "Reno, Nevada, USA",
      set_north: 39.64,
      set_south: 39.39,
      set_east:  -119.70,
      set_west:  -119.94,
      set_high:  1700,
      set_low:   1350,
      set_notes: "Biggest Little City"
    }
    assert_api_fail(params.remove(:api_key))
    assert_api_fail(params.merge(set_name: "Evil Lair, Latveria"))
    assert_api_fail(params.merge(set_name: locations(:albion).display_name))
    assert_api_pass(params)
    loc.reload
    assert_equal("Reno, Nevada, USA", loc.display_name)
    assert_in_delta(39.64, loc.north, 0.0001)
    assert_in_delta(39.39, loc.south, 0.0001)
    assert_in_delta(-119.70, loc.east, 0.0001)
    assert_in_delta(-119.94, loc.west, 0.0001)
    assert_in_delta(1700, loc.high, 0.0001)
    assert_in_delta(1350, loc.low, 0.0001)
    assert_equal("Biggest Little City", loc.notes)
  end

  def test_deleting_locations
    loc = rolf.locations.sample
    params = {
      method:  :delete,
      action:  :location,
      api_key: @api_key.key,
      id:      loc.id
    }
    # No DELETE requests should be allowed at all.
    assert_api_fail(params)
  end

  # --------------------------
  #  :section: Name Requests
  # --------------------------

  # ---------------------------------
  #  :section: Observation Requests
  # ---------------------------------

  def test_getting_observations_from_august
    api = API.execute(method: :get, action: :observation, date: "20140824")
    assert_no_errors(api)
  end

  def test_getting_observations_updated_on_day
    api = API.execute(method: :get, action: :observation,
                      updated_at: "20140824")
    assert_no_errors(api)
  end

  def test_post_minimal_observation
    @user = rolf
    @name = Name.unknown
    @loc = locations(:unknown_location)
    @img1 = nil
    @img2 = nil
    @spl = nil
    @proj = nil
    @date = Time.now.in_time_zone("GMT").to_date
    @notes = Observation.no_notes
    @vote = Vote.maximum_vote
    @specimen = false
    @is_col_loc = true
    @lat = nil
    @long = nil
    @alt = nil
    params = {
      method:   :post,
      action:   :observation,
      api_key:  @api_key.key,
      location: "Anywhere"
    }
    api = API.execute(params)
    assert_no_errors(api, "Errors while posting observation")
    assert_obj_list_equal([Observation.last], api.results)
    assert_last_observation_correct
    assert_api_fail(params.remove(:location))
  end

  def test_post_maximal_observation
    @user = rolf
    @name = names(:coprinus_comatus)
    @loc = locations(:albion)
    @img1 = images(:in_situ_image)
    @img2 = images(:turned_over_image)
    @spl = species_lists(:first_species_list)
    @proj = projects(:eol_project)
    @date = date("20120626")
    @notes = { Other: "These are notes.\nThey look like this." }
    @vote = 2.0
    @specimen = true
    @is_col_loc = true
    @lat = 39.229
    @long = -123.77
    @alt = 50
    params = {
      method:        :post,
      action:        :observation,
      api_key:       @api_key.key,
      date:          "20120626",
      notes:         "These are notes.\nThey look like this.\n",
      location:      "USA, California, Albion",
      latitude:      "39.229°N",
      longitude:     "123.770°W",
      altitude:      "50m",
      has_specimen: "yes",
      name:          "Coprinus comatus",
      vote:          "2",
      projects:      @proj.id,
      species_lists: @spl.id,
      thumbnail:     @img2.id,
      images:        "#{@img1.id},#{@img2.id}"
    }
    api = API.execute(params)
    assert_no_errors(api, "Errors while posting observation")
    assert_obj_list_equal([Observation.last], api.results)
    assert_last_observation_correct
    assert_last_naming_correct
    assert_last_vote_correct
    assert_api_fail(params.remove(:api_key))
    assert_api_fail(params.merge(api_key: "this should fail"))
    assert_api_fail(params.merge(date: "yesterday"))
    assert_api_pass(params.merge(location: "This is a bogus location")) # ???
    assert_api_pass(params.merge(location: "New Place, Oregon, USA")) # ???
    assert_api_fail(params.remove(:latitude)) # need to supply both or neither
    assert_api_fail(params.merge(longitude: "bogus"))
    assert_api_fail(params.merge(altitude: "bogus"))
    assert_api_fail(params.merge(has_specimen: "bogus"))
    assert_api_fail(params.merge(name: "Unknown name"))
    assert_api_fail(params.merge(vote: "take that"))
    assert_api_fail(params.merge(extra: "argument"))
    assert_api_fail(params.merge(thumbnail: "1234567"))
    assert_api_fail(params.merge(images: "1234567"))
    assert_api_fail(params.merge(projects: "1234567"))
    # Rolf is not a member of this project
    assert_api_fail(params.merge(projects: projects(:bolete_project).id))
    assert_api_fail(params.merge(species_lists: "1234567"))
    assert_api_fail(
      # owned by Mary
      params.merge(species_lists: species_lists(:unknown_species_list).id)
    )
  end

  def test_post_observation_with_no_log
    params = {
      method:   :post,
      action:   :observation,
      api_key:  @api_key.key,
      location: "Anywhere",
      name:     "Agaricus campestris",
      log:      "no"
    }
    api = API.execute(params)
    assert_no_errors(api, "Errors while posting observation")
    obs = Observation.last
    assert_nil(obs.rss_log_id)
  end

  def test_post_observation_scientific_location
    params = {
      method:   :post,
      action:   :observation,
      api_key:  @api_key.key
    }
    assert_equal(:postal, rolf.location_format)

    params[:location] = "New Place, California, USA"
    api = API.execute(params)
    assert_no_errors(api, "Errors while posting observation")
    obs = Observation.last
    assert_nil(obs.location_id)
    assert_equal("New Place, California, USA", obs.where)

    params[:location] = "Burbank, California, USA"
    api = API.execute(params)
    assert_no_errors(api, "Errors while posting observation")
    obs = Observation.last
    assert_nil(obs.where)
    assert_objs_equal(locations(:burbank), obs.location)

    User.update(rolf.id, location_format: :scientific)
    assert_equal(:scientific, rolf.reload.location_format)

    params[:location] = "USA, California, Somewhere Else"
    api = API.execute(params)
    assert_no_errors(api, "Errors while posting observation")
    obs = Observation.last
    assert_nil(obs.location_id)
    assert_equal("Somewhere Else, California, USA", obs.where)

    params[:location] = "Burbank, California, USA"
    api = API.execute(params)
    assert_no_errors(api, "Errors while posting observation")
    obs = Observation.last
    assert_nil(obs.where)
    assert_objs_equal(locations(:burbank), obs.location)
  end

  def test_post_observation_with_specimen
    params = {
      method:   :post,
      action:   :observation,
      api_key:  @api_key.key,
      location: locations(:burbank).name,
      name:     names(:peltigera).text_name
    }

    assert_api_fail(params.merge(has_specimen: "no", herbarium: "1"))
    assert_api_fail(params.merge(has_specimen: "no", specimen_id: "1"))
    assert_api_fail(params.merge(has_specimen: "no", herbarium_label: "1"))
    assert_api_fail(params.merge(has_specimen: "yes", specimen_id: "1",
                                 herbarium_label: "1"))
    assert_api_fail(params.merge(has_specimen: "yes", herbarium: "bogus"))

    assert_api_pass(params.merge(has_specimen: "yes"))

    obs = Observation.last
    spec = Specimen.last
    assert_objs_equal(rolf.personal_herbarium, spec.herbarium)
    assert_equal("Peltigera: #{obs.id}", spec.herbarium_label)
    assert_obj_list_equal([obs], spec.observations)

    nybg = herbaria(:nybg_herbarium)
    assert_api_pass(params.merge(has_specimen: "yes", herbarium: nybg.code,
                                 specimen_id: "R. Singer 12345"))

    obs = Observation.last
    spec = Specimen.last
    assert_objs_equal(nybg, spec.herbarium)
    assert_equal("Peltigera: R. Singer 12345", spec.herbarium_label)
    assert_obj_list_equal([obs], spec.observations)
  end

  # -----------------------------
  #  :section: Project Requests
  # -----------------------------

  # ------------------------------
  #  :section: Sequence Requests
  # ------------------------------

  # ---------------------------------
  #  :section: SpeciesList Requests
  # ---------------------------------

  # --------------------------
  #  :section: User Requests
  # --------------------------

  def test_posting_minimal_user
    @login = "stephane"
    @name = ""
    @email = "stephane@grappelli.com"
    @locale = "en-US"
    @notes = ""
    @license = License.preferred
    @location = nil
    @image = nil
    @address = ""
    @new_key = nil
    params = {
      method:   :post,
      action:   :user,
      api_key:  @api_key.key,
      login:    @login,
      email:    @email,
      password: "secret"
    }
    api = API.execute(params)
    assert_no_errors(api, "Errors while posting image")
    assert_obj_list_equal([User.last], api.results)
    assert_last_user_correct
    assert_api_fail(params)
    params[:login] = "miles"
    assert_api_fail(params.remove(:api_key))
    assert_api_fail(params.remove(:login))
    assert_api_fail(params.remove(:email))
    assert_api_fail(params.merge(login: "x" * 1000))
    assert_api_fail(params.merge(email: "x" * 1000))
    assert_api_fail(params.merge(email: "bogus address @ somewhere dot com"))
  end

  def test_posting_maximal_user
    @login = "stephane"
    @name = "Stephane Grappelli"
    @email = "stephane@grappelli.com"
    @locale = "el-GR"
    @notes = " Here are some notes\nThey look like this!\n "
    @license = (License.where(deprecated: false) - [License.preferred]).first
    @location = Location.last
    @image = Image.last
    @address = " I live here "
    @new_key = "  Blah  Blah  Blah  "
    params = {
      method:   :post,
      action:   :user,
      api_key:  @api_key.key,
      login:    @login,
      name:     @name,
      email:    @email,
      password: "supersecret",
      locale:   @locale,
      notes:    @notes,
      license:  @license.id,
      location: @location.id,
      image:    @image.id,
      mailing_address:  @address,
      create_key: @new_key
    }
    api = API.execute(params)
    assert_no_errors(api, "Errors while posting image")
    assert_obj_list_equal([User.last], api.results)
    assert_last_user_correct
    params[:login] = "miles"
    assert_api_fail(params.merge(name: "x" * 1000))
    assert_api_fail(params.merge(locale: "xx-XX"))
    assert_api_fail(params.merge(license: "123456"))
    assert_api_fail(params.merge(location: "123456"))
    assert_api_fail(params.merge(image: "123456"))
  end

  # --------------------
  #  :section: Parsers
  # --------------------

  def test_parse_boolean
    assert_parse(:boolean, nil, nil)
    assert_parse(:boolean, true, nil, default: true)
    assert_parse(:boolean, false, "0")
    assert_parse(:boolean, false, "0", default: true)
    assert_parse(:boolean, false, "no")
    assert_parse(:boolean, false, "NO")
    assert_parse(:boolean, false, "false")
    assert_parse(:boolean, false, "False")
    assert_parse(:boolean, true, "1")
    assert_parse(:boolean, true, "yes")
    assert_parse(:boolean, true, "true")
    assert_parse(:boolean, API::BadParameterValue, "foo")
    assert_parse_a(:boolean, nil, nil)
    assert_parse_a(:boolean, [], nil, default: [])
    assert_parse_a(:boolean, [true], "1")
    assert_parse_a(:boolean, [true, false], "1,0")
  end

  def test_parse_enum
    limit = [:one, :two, :three, :four, :five]
    assert_parse(:enum, nil, nil, limit: limit)
    assert_parse(:enum, :three, nil, limit: limit, default: :three)
    assert_parse(:enum, :two, "two", limit: limit)
    assert_parse(:enum, :two, "Two", limit: limit)
    assert_parse(:enum, API::BadLimitedParameterValue, "", limit: limit)
    assert_parse(:enum, API::BadLimitedParameterValue, "Ten", limit: limit)
    assert_parse_a(:enum, nil, nil, limit: limit)
    assert_parse_a(:enum, [:one], "one", limit: limit)
    assert_parse_a(:enum, [:one, :two, :three], "one,two,three", limit: limit)
    assert_parse_r(:enum, nil, nil, limit: limit)
    assert_parse_r(:enum, :four, "four", limit: limit)
    assert_parse_r(:enum, aor(:one, :four), "four-one", limit: limit)
  end

  def test_parse_string
    assert_parse(:string, nil, nil)
    assert_parse(:string, "hello", nil, default: "hello")
    assert_parse(:string, "foo", "foo", default: "hello")
    assert_parse(:string, "foo", " foo\n", default: "hello")
    assert_parse(:string, "", "", default: "hello")
    assert_parse(:string, "abcd", "abcd", limit: 4)
    assert_parse(:string, API::StringTooLong, "abcde", limit: 4)
    assert_parse_a(:string, nil, nil)
    assert_parse_a(:string, ["foo"], "foo")
    assert_parse_a(:string, %w[foo bar], "foo,bar", limit: 4)
    assert_parse_a(:string, API::StringTooLong, "foo,abcde", limit: 4)
  end

  def test_parse_integer
    exception = API::BadLimitedParameterValue
    assert_parse(:integer, nil, nil)
    assert_parse(:integer, 42, nil, default: 42)
    assert_parse(:integer, 1, "1")
    assert_parse(:integer, 0, " 0 ")
    assert_parse(:integer, -13, "-13")
    assert_parse_a(:integer, nil, nil)
    assert_parse_a(:integer, [1], "1")
    assert_parse_a(:integer, [3, -1, 4, -159], "3,-1,4,-159")
    assert_parse_a(:integer, [1, 13], "1,13", limit: 1..13)
    assert_parse_a(:integer, exception, "0,13", limit: 1..13)
    assert_parse_a(:integer, exception, "1,14", limit: 1..13)
    assert_parse_r(:integer, aor(1, 13), "1-13", limit: 1..13)
    assert_parse_r(:integer, exception, "0-13", limit: 1..13)
    assert_parse_r(:integer, exception, "1-14", limit: 1..13)
    assert_parse_rs(:integer, nil, nil, limit: 1..13)
    assert_parse_rs(:integer, [aor(1, 4), aor(6, 9)], "1-4,6-9", limit: 1..13)
    assert_parse_rs(:integer, [1, 4, aor(6, 9)], "1,4,6-9", limit: 1..13)
  end

  def test_parse_float
    assert_parse(:float, nil, nil)
    assert_parse(:float, -2.71828, nil, default: -2.71828)
    assert_parse(:float, 0, "0", default: -2.71828)
    assert_parse(:float, 4, "4")
    assert_parse(:float, -4, "-4")
    assert_parse(:float, 4, "4.0")
    assert_parse(:float, -4, "-4.0")
    assert_parse(:float, 0, ".0")
    assert_parse(:float, 0.123, ".123")
    assert_parse(:float, -0.123, "-.123")
    assert_parse(:float, 123.123, "123.123")
    assert_parse(:float, -123.123, "-123.123")
    assert_parse_a(:float, nil, nil)
    assert_parse_a(:float, [1.2, 3.4], " 1.20, 3.40 ")
    assert_parse_rs(:float, [aor(1, 2), 4, 5], "1-2,4,5")
    assert_parse(:float, API::BadParameterValue, "")
    assert_parse(:float, API::BadParameterValue, "one")
    assert_parse(:float, API::BadParameterValue, "+1e5")
  end

  def test_parse_date
    assert_parse(:date, nil, nil)
    assert_parse(:date, date("2012-06-25"), nil,
                 default: date("2012-06-25"))
    assert_parse(:date, date("2012-06-26"), "20120626")
    assert_parse(:date, date("2012-06-26"), "2012-06-26")
    assert_parse(:date, date("2012-06-26"), "2012/06/26")
    assert_parse(:date, date("2012-06-07"), "2012-6-7")
    assert_parse(:date, API::BadParameterValue, "2012-06/7")
    assert_parse(:date, API::BadParameterValue, "2012 6/7")
    assert_parse(:date, API::BadParameterValue, "6/26/2012")
    assert_parse(:date, API::BadParameterValue, "today")
  end

  def test_parse_time
    assert_parse(:time, nil, nil)
    assert_parse(:time, time("2012-06-25 12:34:56"), nil,
                 default: time("2012-06-25 12:34:56"))
    assert_parse(:time, time("2012-06-25 12:34:56"),
                 "20120625123456")
    assert_parse(:time, time("2012-06-25 12:34:56"),
                 "2012-06-25 12:34:56")
    assert_parse(:time, time("2012-06-25 12:34:56"),
                 "2012/06/25 12:34:56")
    assert_parse(:time, time("2012-06-05 02:04:06"),
                 "2012/6/5 2:4:6")
    assert_parse(:time, API::BadParameterValue, "20120625")
    assert_parse(:time, API::BadParameterValue, "201206251234567")
    assert_parse(:time, API::BadParameterValue, "2012/06/25 103456")
    assert_parse(:time, API::BadParameterValue, "2012-06/25 10:34:56")
    assert_parse(:time, API::BadParameterValue, "2012/06/25 10:34:56am")
  end

  def test_parse_date_range
    assert_parse_r(:date, nil, nil)
    assert_parse_r(:date, "blah", nil, default: "blah")
    assert_parse_dr("2012-06-26", "2012-06-26", "20120626")
    assert_parse_dr("2012-06-26", "2012-06-26", "2012-06-26")
    assert_parse_dr("2012-06-26", "2012-06-26", "2012/06/26")
    assert_parse_dr("2012-06-07", "2012-06-07", "2012-6-7")
    assert_parse_r(:date, API::BadParameterValue, "2012-06/7")
    assert_parse_r(:date, API::BadParameterValue, "2012 6/7")
    assert_parse_r(:date, API::BadParameterValue, "6/26/2012")
    assert_parse_r(:date, API::BadParameterValue, "today")
    assert_parse_dr("2012-06-01", "2012-06-30", "201206")
    assert_parse_dr("2012-06-01", "2012-06-30", "2012-6")
    assert_parse_dr("2012-06-01", "2012-06-30", "2012/06")
    assert_parse_dr("2012-01-01", "2012-12-31", "2012")
    assert_parse_r(:date, aor(6, 6), "6")
    assert_parse_r(:date, aor(613, 613), "6/13")
    assert_parse_dr("2011-05-13", "2012-06-15", "20110513-20120615")
    assert_parse_dr("2011-05-13", "2012-06-15", "2011-05-13-2012-06-15")
    assert_parse_dr("2011-05-13", "2012-06-15", "2011-5-13-2012-6-15")
    assert_parse_dr("2011-05-13", "2012-06-15", "2011/05/13 - 2012/06/15")
    assert_parse_dr("2011-05-01", "2012-06-30", "201105-201206")
    assert_parse_dr("2011-05-01", "2012-06-30", "2011-5-2012-6")
    assert_parse_dr("2011-05-01", "2012-06-30", "2011/05 - 2012/06")
    assert_parse_dr("2011-01-01", "2012-12-31", "2011-2012")
    assert_parse_r(:date, aor(2, 5), "2-5")
    assert_parse_r(:date, aor(10, 3), "10-3")
    assert_parse_r(:date, aor(612, 623), "0612-0623")
    assert_parse_r(:date, aor(1225, 101), "12-25-1-1")
  end

  def assert_parse_dr(from, to, str)
    from = date(from)
    to   = date(to)
    assert_parse_r(:date, aor(from, to), str)
  end

  # rubocop:disable Metric/LineLength
  def test_parse_time_range
    assert_parse_r(:time, nil, nil)
    assert_parse_tr("2012-06-25 12:34:56", "2012-06-25 12:34:56", "20120625123456")
    assert_parse_tr("2012-06-25 12:34:56", "2012-06-25 12:34:56", "2012-06-25 12:34:56")
    assert_parse_tr("2012-06-25 12:34:56", "2012-06-25 12:34:56", "2012/06/25 12:34:56")
    assert_parse_tr("2012-06-05 02:04:06", "2012-06-05 02:04:06", "2012/6/5 2:4:6")
    assert_parse_r(:time, API::BadParameterValue, "201206251234567")
    assert_parse_r(:time, API::BadParameterValue, "2012/06/25 103456")
    assert_parse_r(:time, API::BadParameterValue, "2012-06/25 10:34:56")
    assert_parse_r(:time, API::BadParameterValue, "2012/06/25 10:34:56am")
    assert_parse_tr("2011-02-24 02:03:00", "2011-02-24 02:03:59", "201102240203")
    assert_parse_tr("2011-02-24 02:03:00", "2011-02-24 02:03:59", "2011-2-24 2:3")
    assert_parse_tr("2011-02-24 02:03:00", "2011-02-24 02:03:59", "2011/02/24 02:03")
    assert_parse_tr("2011-02-24 02:00:00", "2011-02-24 02:59:59", "2011022402")
    assert_parse_tr("2011-02-24 02:00:00", "2011-02-24 02:59:59", "2011-2-24 2")
    assert_parse_tr("2011-02-24 02:00:00", "2011-02-24 02:59:59", "2011/02/24 02")
    assert_parse_tr("2011-02-24 00:00:00", "2011-02-24 23:59:59", "20110224")
    assert_parse_tr("2011-02-24 00:00:00", "2011-02-24 23:59:59", "2011-2-24")
    assert_parse_tr("2011-02-24 00:00:00", "2011-02-24 23:59:59", "2011/02/24")
    assert_parse_tr("2011-02-01 00:00:00", "2011-02-28 23:59:59", "201102")
    assert_parse_tr("2011-02-01 00:00:00", "2011-02-28 23:59:59", "2011-2")
    assert_parse_tr("2011-02-01 00:00:00", "2011-02-28 23:59:59", "2011/02")
    assert_parse_tr("2011-01-01 00:00:00", "2011-12-31 23:59:59", "2011")
    assert_parse_tr("2011-05-24 02:03:04", "2012-06-25 03:04:05", "20110524020304-20120625030405")
    assert_parse_tr("2011-05-24 02:03:04", "2012-06-25 03:04:05", "2011-5-24 2:3:4-2012-6-25 3:4:5")
    assert_parse_tr("2011-05-24 02:03:04", "2012-06-25 03:04:05", "2011/05/24 02:03:04 - 2012/06/25 03:04:05")
    assert_parse_tr("2011-05-24 02:03:00", "2012-06-25 03:04:59", "201105240203-201206250304")
    assert_parse_tr("2011-05-24 02:03:00", "2012-06-25 03:04:59", "2011-5-24 2:3-2012-6-25 3:4")
    assert_parse_tr("2011-05-24 02:03:00", "2012-06-25 03:04:59", "2011/05/24 02:03 - 2012/06/25 03:04")
    assert_parse_tr("2011-05-24 02:00:00", "2012-06-25 03:59:59", "2011052402-2012062503")
    assert_parse_tr("2011-05-24 02:00:00", "2012-06-25 03:59:59", "2011-5-24 2-2012-6-25 3")
    assert_parse_tr("2011-05-24 02:00:00", "2012-06-25 03:59:59", "2011/05/24 02 - 2012/06/25 03")
    assert_parse_tr("2011-05-24 00:00:00", "2012-06-25 23:59:59", "20110524-20120625")
    assert_parse_tr("2011-05-24 00:00:00", "2012-06-25 23:59:59", "2011-5-24-2012-6-25")
    assert_parse_tr("2011-05-24 00:00:00", "2012-06-25 23:59:59", "2011/05/24 - 2012/06/25")
    assert_parse_tr("2011-05-01 00:00:00", "2012-06-30 23:59:59", "201105-201206")
    assert_parse_tr("2011-05-01 00:00:00", "2012-06-30 23:59:59", "2011-5-2012-6")
    assert_parse_tr("2011-05-01 00:00:00", "2012-06-30 23:59:59", "2011/05 - 2012/06")
    assert_parse_tr("2011-01-01 00:00:00", "2012-12-31 23:59:59", "2011-2012")
    assert_parse_tr("2011-01-01 00:00:00", "2012-12-31 23:59:59", "2011 - 2012")
  end
  # rubocop:enable Metric/LineLength

  def assert_parse_tr(from, to, str)
    from = time(from)
    to   = time(to)
    ordered_range = aor(from, to)
    assert_parse_r(:time, ordered_range, str)
  end

  def test_parse_latitude
    assert_parse(:latitude, nil, nil)
    assert_parse(:latitude, 45, nil, default: 45)
    assert_parse(:latitude, 4, "4")
    assert_parse(:latitude, -4, "-4")
    assert_parse(:latitude, 4.1235, "4.1234567")
    assert_parse(:latitude, -4.1235, "-4.1234567")
    assert_parse(:latitude, -4.1235, "4.1234567S")
    assert_parse(:latitude, 12.5822, '12°34\'56"N')
    assert_parse(:latitude, 12.5760, "12 34.56 N")
    assert_parse(:latitude, -12.0094, "12deg 34sec S")
    assert_parse(:latitude, API::BadParameterValue, "12 34.56 E")
    assert_parse(:latitude, API::BadParameterValue, "12 degrees 34.56 minutes")
    assert_parse(:latitude, API::BadParameterValue, "12.56s")
    assert_parse(:latitude, 90.0000, "90d 0s N")
    assert_parse(:latitude, -90.0000, "90d 0s S")
    assert_parse(:latitude, API::BadParameterValue, "90d 1s N")
    assert_parse(:latitude, API::BadParameterValue, "90d 1s S")
    assert_parse_a(:latitude, nil, nil)
    assert_parse_a(:latitude, [1.2, 3.4], "1.2,3.4")
    assert_parse_r(:latitude, nil, nil)
    assert_parse_r(:latitude, aor(-12, 34), "12S-34N")
    assert_parse_rs(:latitude, [aor(-12, 34), 6, 7], "12S-34N,6,7")
  end

  def test_parse_longitude
    assert_parse(:longitude, nil, nil)
    assert_parse(:longitude, 45, nil, default: 45)
    assert_parse(:longitude, 4, "4")
    assert_parse(:longitude, -4, "-4")
    assert_parse(:longitude, 4.1235, "4.1234567")
    assert_parse(:longitude, -4.1235, "-4.1234567")
    assert_parse(:longitude, -4.1235, "4.1234567W")
    assert_parse(:longitude, 12.5822, '12°34\'56"E')
    assert_parse(:longitude, 12.5760, "12 34.56 E")
    assert_parse(:longitude, -12.0094, "12deg 34sec W")
    assert_parse(:longitude, API::BadParameterValue, "12 34.56 S")
    assert_parse(:longitude, API::BadParameterValue, "12 degrees 34.56 minutes")
    assert_parse(:longitude, API::BadParameterValue, "12.56e")
    assert_parse(:longitude, 180.0000, "180d 0s E")
    assert_parse(:longitude, -180.0000, "180d 0s W")
    assert_parse(:longitude, API::BadParameterValue, "180d 1s E")
    assert_parse(:longitude, API::BadParameterValue, "180d 1s W")
    assert_parse_a(:longitude, nil, nil)
    assert_parse_a(:longitude, [1.2, 3.4], "1.2,3.4")
    assert_parse_r(:longitude, nil, nil)
    assert_parse_r(:longitude, aor(-12, 34), "12W-34E")
    assert_parse_rs(:longitude, [aor(-12, 34), 6, 7], "12W-34E,6,7")
  end

  def test_parse_altitude
    assert_parse(:altitude, nil, nil)
    assert_parse(:altitude, 123, nil, default: 123)
    assert_parse(:altitude, 123, "123")
    assert_parse(:altitude, 123, "123 m")
    assert_parse(:altitude, 123, "403 ft")
    assert_parse(:altitude, 123, "403\'")
    assert_parse(:altitude, API::BadParameterValue, "sealevel")
    assert_parse(:altitude, API::BadParameterValue, "123 FT")
    assert_parse_a(:altitude, nil, nil)
    assert_parse_a(:altitude, [123], "123")
    assert_parse_a(:altitude, [123, 456], "123,456m")
    assert_parse_r(:altitude, nil, nil)
    assert_parse_r(:altitude, aor(12, 34), "12-34")
    assert_parse_r(:altitude, aor(54, 76), "54-76")
    assert_parse_rs(:altitude, nil, nil)
    assert_parse_rs(:altitude, [aor(54, 76), 3, 2], "54-76,3,2")
  end

  def test_parse_external_site
    site = external_sites(:mycoportal)
    assert_parse(:external_site, nil, nil)
    assert_parse(:external_site, site, nil, default: site)
    assert_parse(:external_site, site, site.id)
    assert_parse(:external_site, site, site.name)
    assert_parse(:external_site, API::BadParameterValue, "")
    assert_parse(:external_site, API::ObjectNotFoundByString, "name")
    assert_parse(:external_site, API::ObjectNotFoundById, "12345")
  end

  def test_parse_image
    img1 = images(:in_situ_image)
    img2 = images(:turned_over_image)
    assert_parse(:image, nil, nil)
    assert_parse(:image, img1, nil, default: img1)
    assert_parse(:image, img1, img1.id)
    assert_parse_a(:image, [img2, img1], "#{img2.id},#{img1.id}")
    assert_parse_r(:image, aor(img2, img1), "#{img2.id}-#{img1.id}")
    assert_parse(:image, API::BadParameterValue, "")
    assert_parse(:image, API::BadParameterValue, "name")
    assert_parse(:image, API::ObjectNotFoundById, "12345")
  end

  def test_parse_license
    lic1 = licenses(:ccnc25)
    lic2 = licenses(:ccnc30)
    assert_parse(:license, nil, nil)
    assert_parse(:license, lic2, nil, default: lic2)
    assert_parse(:license, lic2, lic2.id)
    assert_parse_a(:license, [lic2, lic1], "#{lic2.id},#{lic1.id}")
    assert_parse_r(:license, aor(lic2, lic1), "#{lic2.id}-#{lic1.id}")
    assert_parse(:license, API::BadParameterValue, "")
    assert_parse(:license, API::BadParameterValue, "name")
    assert_parse(:license, API::ObjectNotFoundById, "12345")
  end

  def test_parse_location
    burbank = locations(:burbank)
    gualala = locations(:gualala)
    assert_parse(:location, nil, nil)
    assert_parse(:location, gualala, nil, default: gualala)
    assert_parse(:location, gualala, gualala.id)
    assert_parse_a(:location, [gualala, burbank], "#{gualala.id},#{burbank.id}")
    assert_parse_r(:location, aor(gualala, burbank),
                   "#{gualala.id}-#{burbank.id}")
    assert_parse(:location, API::BadParameterValue, "")
    assert_parse(:location, API::ObjectNotFoundByString, "name")
    assert_parse(:location, API::ObjectNotFoundById, "12345")
    assert_parse(:location, burbank, burbank.name)
    assert_parse(:location, burbank, burbank.scientific_name)
  end

  def test_parse_place_name
    burbank = locations(:burbank)
    gualala = locations(:gualala)
    assert_parse(:place_name, nil, nil)
    assert_parse(:place_name, gualala.name, nil, default: gualala.name)
    assert_parse(:place_name, gualala.name, gualala.name)
    assert_parse(:place_name, API::BadParameterValue, "")
    assert_parse(:place_name, "name", "name")
    assert_parse(:place_name, API::ObjectNotFoundById, "12345")
    assert_parse(:place_name, burbank.name, burbank.name)
    assert_parse(:place_name, burbank.name, burbank.scientific_name)
  end

  def test_parse_name
    m_rhacodes = names(:macrolepiota_rhacodes)
    a_campestris = names(:agaricus_campestras)
    assert_parse(:name, nil, nil)
    assert_parse(:name, a_campestris, nil, default: a_campestris)
    assert_parse(:name, a_campestris, a_campestris.id)
    assert_parse(:name, API::BadParameterValue, "")
    assert_parse(:name, API::ObjectNotFoundById, "12345")
    assert_parse(:name, API::ObjectNotFoundByString, "Bogus name")
    assert_parse(:name, API::NameDoesntParse, "yellow mushroom")
    assert_parse(:name, API::AmbiguousName, "Amanita baccata")
    assert_parse(:name, m_rhacodes, "Macrolepiota rhacodes")
    assert_parse(:name, m_rhacodes, "Macrolepiota rhacodes (Vittad.) Singer")
    assert_parse_a(:name, [a_campestris, m_rhacodes],
                   "#{a_campestris.id},#{m_rhacodes.id}")
    assert_parse_r(:name, aor(a_campestris, m_rhacodes),
                   "#{a_campestris.id}-#{m_rhacodes.id}")
  end

  def test_parse_observation
    a_campestrus_obs = observations(:agaricus_campestrus_obs)
    unknown_lat_lon_obs = observations(:unknown_with_lat_long)
    assert_parse(:observation, nil, nil)
    assert_parse(:observation, a_campestrus_obs, nil, default: a_campestrus_obs)
    assert_parse(:observation, a_campestrus_obs, a_campestrus_obs.id)
    assert_parse_a(:observation, [unknown_lat_lon_obs, a_campestrus_obs],
                   "#{unknown_lat_lon_obs.id},#{a_campestrus_obs.id}")
    assert_parse_r(:observation, aor(unknown_lat_lon_obs, a_campestrus_obs),
                   "#{unknown_lat_lon_obs.id}-#{a_campestrus_obs.id}")
    assert_parse(:observation, API::BadParameterValue, "")
    assert_parse(:observation, API::BadParameterValue, "name")
    assert_parse(:observation, API::ObjectNotFoundById, "12345")
  end

  def test_parse_project
    eol_proj = projects(:eol_project)
    bolete_proj = projects(:bolete_project)
    assert_parse(:project, nil, nil)
    assert_parse(:project, bolete_proj, nil, default: bolete_proj)
    assert_parse(:project, bolete_proj, bolete_proj.id)
    assert_parse_a(:project, [bolete_proj, eol_proj],
                   "#{bolete_proj.id},#{eol_proj.id}")
    assert_parse_r(:project, aor(bolete_proj, eol_proj),
                   "#{bolete_proj.id}-#{eol_proj.id}")
    assert_parse(:project, API::BadParameterValue, "")
    assert_parse(:project, API::ObjectNotFoundByString, "name")
    assert_parse(:project, API::ObjectNotFoundById, "12345")
    assert_parse(:project, eol_proj, eol_proj.title)
  end

  def test_parse_species_list
    first_list = species_lists(:first_species_list)
    another_list = species_lists(:another_species_list)
    assert_parse(:species_list, nil, nil)
    assert_parse(:species_list, another_list, nil, default: another_list)
    assert_parse(:species_list, another_list, another_list.id)
    assert_parse_a(:species_list, [another_list, first_list],
                   "#{another_list.id},#{first_list.id}")
    assert_parse_r(:species_list, aor(another_list, first_list),
                   "#{another_list.id}-#{first_list.id}")
    assert_parse(:species_list, API::BadParameterValue, "")
    assert_parse(:species_list, API::ObjectNotFoundByString, "name")
    assert_parse(:species_list, API::ObjectNotFoundById, "12345")
    assert_parse(:species_list, first_list, first_list.title)
  end

  def test_parse_user
    assert_parse(:user, nil, nil)
    assert_parse(:user, mary, nil, default: mary)
    assert_parse(:user, mary, mary.id)
    assert_parse_a(:user, [mary, rolf], "#{mary.id},#{rolf.id}")
    assert_parse_r(:user, aor(mary, rolf), "#{mary.id}-#{rolf.id}")
    assert_parse(:user, API::BadParameterValue, "")
    assert_parse(:user, API::ObjectNotFoundByString, "name")
    assert_parse(:user, API::ObjectNotFoundById, "12345")
    assert_parse(:user, rolf, rolf.login)
    assert_parse(:user, rolf, rolf.name)
  end

  def test_parse_object
    limit = [Name, Observation, SpeciesList]
    obs = observations(:unknown_with_lat_long)
    nam = names(:agaricus_campestras)
    list = species_lists(:another_species_list)
    assert_parse(:object, nil, nil, limit: limit)
    assert_parse(:object, obs, nil, default: obs, limit: limit)
    assert_parse(:object, obs, "observation #{obs.id}", limit: limit)
    assert_parse(:object, nam, "name #{nam.id}", limit: limit)
    assert_parse(:object, list, "species list #{list.id}", limit: limit)
    assert_parse(:object, list, "species_list #{list.id}", limit: limit)
    assert_parse(:object, list, "Species List #{list.id}", limit: limit)
    assert_parse(:object, API::BadParameterValue, "", limit: limit)
    assert_parse(:object, API::BadParameterValue, "1", limit: limit)
    assert_parse(:object, API::BadParameterValue, "bogus", limit: limit)
    assert_parse(:object, API::BadLimitedParameterValue, "bogus 1",
                 limit: limit)
    assert_parse(:object, API::BadLimitedParameterValue,
                 "license #{licenses(:ccnc25).id}", limit: limit)
    assert_parse(:object, API::ObjectNotFoundById, "name 12345",
                 limit: limit)
    assert_parse_a(:object, [obs, nam],
                   "observation #{obs.id}, name #{nam.id}", limit: limit)
  end

  # ---------------------------
  #  :section: Authentication
  # ---------------------------

  def test_unverified_user_rejected
    params = {
      method:   :post,
      action:   :observation,
      api_key:  @api_key.key,
      location: "Anywhere"
    }
    User.update(rolf.id, verified: nil)
    assert_api_fail(params)
    User.update(rolf.id, verified: Time.zone.now)
    assert_api_pass(params)
  end

  def test_unverified_api_key_rejected
    params = {
      method:   :post,
      action:   :observation,
      api_key:  @api_key.key,
      location: "Anywhere"
    }
    ApiKey.update(@api_key.id, verified: nil)
    assert_api_fail(params)
    @api_key.verify!
    assert_api_pass(params)
  end

  def test_check_edit_permission
    @api      = API.new
    @api.user = dick
    proj      = dick.projects_member.first

    img_good = proj.images.first
    img_bad  = (Image.all - proj.images - dick.images).first
    obs_good = proj.observations.first
    obs_bad  = (Observation.all - proj.observations - dick.observations).first
    spl_good = proj.species_lists.first
    spl_bad  = (SpeciesList.all - proj.species_lists - dick.species_lists).first
    assert_not_nil(img_good)
    assert_not_nil(img_bad)
    assert_not_nil(obs_good)
    assert_not_nil(obs_bad)
    assert_not_nil(spl_good)
    assert_not_nil(spl_bad)

    args = { must_have_edit_permission: true }
    assert_parse(:image, img_good, img_good.id, args)
    assert_parse(:image, API::MustHaveEditPermission, img_bad.id, args)
    assert_parse(:observation, obs_good, obs_good.id, args)
    assert_parse(:observation, API::MustHaveEditPermission, obs_bad.id, args)
    assert_parse(:species_list, spl_good, spl_good.id, args)
    assert_parse(:species_list, API::MustHaveEditPermission, spl_bad.id, args)
    assert_parse(:user, dick, dick.id, args)
    assert_parse(:user, API::MustHaveEditPermission, rolf.id, args)

    args[:limit] = [Image, Observation, SpeciesList, User]
    assert_parse(:object, img_good, "image #{img_good.id}", args)
    assert_parse(:object, API::MustHaveEditPermission,
                 "image #{img_bad.id}", args)
    assert_parse(:object, obs_good, "observation #{obs_good.id}", args)
    assert_parse(:object, API::MustHaveEditPermission,
                 "observation #{obs_bad.id}", args)
    assert_parse(:object, spl_good, "species list #{spl_good.id}", args)
    assert_parse(:object, API::MustHaveEditPermission,
                 "species list #{spl_bad.id}", args)
    assert_parse(:object, dick, "user #{dick.id}", args)
    assert_parse(:object, API::MustHaveEditPermission, "user #{rolf.id}", args)
  end

  def test_check_project_membership
    @api   = API.new
    proj   = projects(:eol_project)
    admin  = proj.admin_group.users.first
    member = (proj.user_group.users - proj.admin_group.users).first
    other  = (User.all - proj.admin_group.users - proj.user_group.users).first
    assert_not_nil(admin)
    assert_not_nil(member)
    assert_not_nil(other)

    @api.user = admin
    assert_parse(:project, proj, proj.id, must_be_admin: true)
    assert_parse(:project, proj, proj.id, must_be_member: true)

    @api.user = member
    assert_parse(:project, API::MustBeAdmin, proj.id, must_be_admin: true)
    assert_parse(:project, proj, proj.id, must_be_member: true)

    @api.user = other
    assert_parse(:project, API::MustBeAdmin, proj.id, must_be_admin: true)
    assert_parse(:project, API::MustBeMember, proj.id, must_be_member: true)
  end
end
