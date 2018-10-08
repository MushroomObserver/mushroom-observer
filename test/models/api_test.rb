# TODO: naming API
# TODO: vote API
# TODO: image_vote API

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

  # This method renamed from "time"
  # minitest 5.11.1 throws ArgumentError with "time".
  def api_test_time(str)
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
    assert_obj_list_equal(expect, @api.results, :sort, msg)
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
    assert_equal(@app.strip, api_key.notes)
    assert_users_equal(@for_user, api_key.user)
  end

  def assert_last_collection_number_correct
    num = CollectionNumber.last
    assert_users_equal(@user, num.user)
    assert_in_delta(Time.zone.now, num.created_at, 1.minute)
    assert_in_delta(Time.zone.now, num.updated_at, 1.minute)
    assert_obj_list_equal([@obs], num.observations)
    assert_equal(@name.strip, num.name)
    assert_equal(@number.strip, num.number)
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

  def assert_last_herbarium_record_correct
    rec = HerbariumRecord.last
    assert_users_equal(@user, rec.user)
    assert_in_delta(Time.zone.now, rec.created_at, 1.minute)
    assert_in_delta(Time.zone.now, rec.updated_at, 1.minute)
    assert_obj_list_equal([@obs], rec.observations)
    assert_objs_equal(@herbarium, rec.herbarium)
    assert_equal(@initial_det.strip, rec.initial_det)
    assert_equal(@accession_number.strip, rec.accession_number)
    assert_equal(@notes.strip, rec.notes)
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

  def assert_last_name_correct(name = Name.last)
    assert_in_delta(Time.zone.now, name.created_at, 1.minute)
    assert_in_delta(Time.zone.now, name.updated_at, 1.minute)
    assert_users_equal(@user, name.user)
    assert_equal(@name, name.text_name)
    assert_equal(@author, name.author)
    assert_equal(@rank, name.rank)
    assert_equal(@deprecated, name.deprecated)
    assert_equal(@citation, name.citation)
    assert_equal(@classification, name.classification)
    assert_equal(@notes, name.notes)
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
    assert_equal(@loc.name, obs.where)
    assert_objs_equal(@loc, obs.location)
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

  def assert_last_project_correct
    proj = Project.last
    assert_in_delta(Time.zone.now, proj.created_at, 1.minute)
    assert_in_delta(Time.zone.now, proj.updated_at, 1.minute)
    assert_users_equal(@user, proj.user)
    assert_equal(@title, proj.title)
    assert_equal(@summary, proj.summary)
    assert_user_list_equal(@admins, proj.admin_group.users)
    assert_user_list_equal(@members, proj.user_group.users)
  end

  def assert_last_sequence_correct(seq = Sequence.last)
    assert_in_delta(Time.zone.now, seq.created_at, 1.minute) \
      unless seq != Sequence.last
    assert_in_delta(Time.zone.now, seq.updated_at, 1.minute)
    assert_users_equal(@user, seq.user)
    assert_objs_equal(@obs, seq.observation)
    assert_equal(@locus.to_s, seq.locus.to_s)
    assert_equal(@bases.to_s, seq.bases.to_s)
    assert_equal(@archive.to_s, seq.archive.to_s)
    assert_equal(@accession.to_s, seq.accession.to_s)
    assert_equal(@notes.to_s, seq.notes.to_s)
  end

  def assert_last_species_list_correct(spl = SpeciesList.last)
    assert_in_delta(Time.zone.now, spl.created_at, 1.minute) \
      unless spl != SpeciesList.last
    assert_in_delta(Time.zone.now, spl.updated_at, 1.minute)
    assert_users_equal(@user, spl.user)
    assert_equal(@title, spl.title)
    assert_equal(@date, spl.when)
    assert_objs_equal(@location, spl.location)
    assert_equal(@where.to_s, spl.where.to_s)
    assert_equal(@notes.to_s, spl.notes.to_s)
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
    assert_equal(@locale, user.locale)
    assert_equal(@notes.strip, user.notes)
    assert_equal(@address.strip, user.mailing_address)
    assert_objs_equal(@license, user.license)
    assert_objs_equal(@location, user.location)
    assert_objs_equal(@image, user.image)
    if @new_key
      assert_equal(1, user.api_keys.length)
      assert_equal(@new_key.strip, user.api_keys.first.notes)
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

  def test_basic_comment_get
    do_basic_get_test(Comment)
  end

  def test_basic_external_link_get
    do_basic_get_test(ExternalLink)
  end

  def test_basic_external_site_get
    do_basic_get_test(ExternalSite)
  end

  def test_basic_herbarium_get
    do_basic_get_test(Herbarium)
  end

  def test_basic_image_get
    do_basic_get_test(Image)
  end

  def test_basic_location_get
    do_basic_get_test(Location)
  end

  def test_basic_name_get
    do_basic_get_test(Name)
  end

  def test_basic_observation_get
    do_basic_get_test(Observation)
  end

  def test_basic_project_get
    do_basic_get_test(Project)
  end

  def test_basic_sequence_get
    do_basic_get_test(Sequence)
  end

  def test_basic_species_list_get
    do_basic_get_test(SpeciesList)
  end

  def test_basic_user_get
    do_basic_get_test(User)
  end

  def do_basic_get_test(model)
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

  def test_patching_api_keys
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
      id:       @api_key.id
    }
    # No DELETE requests allowed now.
    assert_api_fail(params)
  end

  # ---------------------------------------
  #  :section: Collection Number Requests
  # ---------------------------------------

  def test_getting_collection_numbers
    params = { method: :get, action: :collection_number }

    nums = CollectionNumber.where("year(created_at) = 2006")
    assert_not_empty(nums)
    assert_api_pass(params.merge(created_at: "2006"))
    assert_api_results(nums)

    nums = CollectionNumber.where("year(updated_at) = 2005")
    assert_not_empty(nums)
    assert_api_pass(params.merge(updated_at: "2005"))
    assert_api_results(nums)

    nums = CollectionNumber.where(user: mary)
    assert_not_empty(nums)
    assert_api_pass(params.merge(user: "mary"))
    assert_api_results(nums)

    obs  = observations(:detailed_unknown_obs)
    nums = obs.collection_numbers
    assert_not_empty(nums)
    assert_api_pass(params.merge(observation: obs.id))
    assert_api_results(nums)

    nums = CollectionNumber.where(name: "Mary Newbie")
    assert_not_empty(nums)
    assert_api_pass(params.merge(collector: "Mary Newbie"))
    assert_api_results(nums)

    nums = CollectionNumber.where("name LIKE '%mary%'")
    assert_not_empty(nums)
    assert_api_pass(params.merge(collector_has: "Mary"))
    assert_api_results(nums)

    nums = CollectionNumber.where(number: "174")
    assert_not_empty(nums)
    assert_api_pass(params.merge(number: "174"))
    assert_api_results(nums)

    nums = CollectionNumber.where("number LIKE '%17%'")
    assert_not_empty(nums)
    assert_api_pass(params.merge(number_has: "17"))
    assert_api_results(nums)
  end

  def test_posting_collection_numbers
    rolfs_obs  = observations(:strobilurus_diminutivus_obs)
    marys_obs  = observations(:detailed_unknown_obs)
    @obs       = rolfs_obs
    @name      = "Someone Else"
    @number    = "13579a"
    @user      = rolf
    params = {
      method:      :post,
      action:      :collection_number,
      api_key:     @api_key.key,
      observation: @obs.id,
      collector:   @name,
      number:      @number
    }
    assert_api_fail(params.remove(:api_key))
    assert_api_fail(params.remove(:observation))
    assert_api_fail(params.remove(:number))
    assert_api_fail(params.merge(observation: marys_obs.id))
    assert_api_pass(params)
    assert_last_collection_number_correct

    collection_number_count = CollectionNumber.count
    rolfs_other_obs = observations(:stereum_hirsutum_1)
    assert_api_pass(params.merge(observation: rolfs_other_obs.id))
    assert_equal(collection_number_count, CollectionNumber.count)
    assert_obj_list_equal([rolfs_obs, rolfs_other_obs],
                          CollectionNumber.last.observations, :sort)
  end

  def test_patching_collection_numbers
    rolfs_num = collection_numbers(:coprinus_comatus_coll_num)
    marys_num = collection_numbers(:minimal_unknown_coll_num)
    rolfs_rec = herbarium_records(:coprinus_comatus_rolf_spec)
    params = {
      method:        :patch,
      action:        :collection_number,
      api_key:       @api_key.key,
      id:            rolfs_num.id,
      set_collector: "New",
      set_number:    "42"
    }
    assert_equal("Rolf Singer 1", rolfs_rec.accession_number)
    assert_api_fail(params.remove(:api_key))
    assert_api_fail(params.merge(id: marys_num.id))
    assert_api_pass(params)
    assert_equal("New", rolfs_num.reload.name)
    assert_equal("42", rolfs_num.reload.number)
    assert_equal("New 42", rolfs_rec.reload.accession_number)

    old_obs   = rolfs_num.observations.first
    rolfs_obs = observations(:agaricus_campestris_obs)
    marys_obs = observations(:detailed_unknown_obs)
    params = {
      method:        :patch,
      action:        :collection_number,
      api_key:       @api_key.key,
      id:            rolfs_num.id
    }
    assert_api_fail(params.merge(add_observation: marys_obs.id))
    assert_api_pass(params.merge(add_observation: rolfs_obs.id))
    assert_obj_list_equal([old_obs, rolfs_obs], rolfs_num.reload.observations,
                          :sort)
    assert_api_pass(params.merge(remove_observation: old_obs.id))
    assert_obj_list_equal([rolfs_obs], rolfs_num.reload.observations)
    assert_api_pass(params.merge(remove_observation: rolfs_obs.id))
    assert_nil(CollectionNumber.safe_find(rolfs_num.id))
  end

  def test_patching_collection_numbers_merge
    num1 = collection_numbers(:coprinus_comatus_coll_num)
    num2 = collection_numbers(:agaricus_campestris_coll_num)
    obs1 = num1.observations.first
    obs2 = num2.observations.first
    params = {
      method:     :patch,
      action:     :collection_number,
      api_key:    @api_key.key,
      id:         num1.id,
      set_number: num2.number
    }
    assert_api_pass(params)
    assert_obj_list_equal(obs1.reload.collection_numbers,
                          obs2.reload.collection_numbers)
    assert_equal(1, obs1.collection_numbers.count)
  end

  def test_deleting_collection_numbers
    rolfs_num = collection_numbers(:coprinus_comatus_coll_num)
    marys_num = collection_numbers(:minimal_unknown_coll_num)
    params = {
      method:     :delete,
      action:     :collection_number,
      api_key:    @api_key.key,
      id:         rolfs_num.id
    }
    assert_api_fail(params.remove(:api_key))
    assert_api_fail(params.merge(id: marys_num.id))
    assert_api_pass(params)
    assert_nil(CollectionNumber.safe_find(rolfs_num.id))
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

    expect = Comment.where(user: rolf) + Comment.where(user: dick)
    assert_api_pass(params.merge(user: "rolf,dick"))
    assert_api_results(expect.sort_by(&:id))

    expect = Comment.where(target_type: "Observation")
    assert_api_pass(params.merge(type: "Observation"))
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

  def test_patching_comments
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
    assert_api_fail(params.merge(set_summary: ""))
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

  def test_patching_external_links
    link = external_links(:coprinus_comatus_obs_mycoportal_link)
    assert_users_equal(mary, link.user)
    assert_users_equal(rolf, link.observation.user)
    assert_false(link.external_site.project.is_member?(dick))
    new_url = "http://something.else"
    params = {
      method:  :patch,
      action:  :external_link,
      api_key: @api_key.key,
      id:      link.id,
      set_url: new_url
    }
    @api_key.update_attributes!(user: dick)
    assert_api_fail(params)
    @api_key.update_attributes!(user: rolf)
    assert_api_fail(params.merge(set_url: ""))
    assert_api_pass(params)
    assert_equal(new_url, link.reload.url)
    @api_key.update_attributes!(user: mary)
    assert_api_pass(params.merge(set_url: new_url + "2"))
    assert_equal(new_url + "2", link.reload.url)
    @api_key.update_attributes!(user: dick)
    link.external_site.project.user_group.users << dick
    assert_api_pass(params.merge(set_url: new_url + "3"))
    assert_equal(new_url + "3", link.reload.url)
  end

  def test_deleting_external_links
    link = external_links(:coprinus_comatus_obs_mycoportal_link)
    assert_users_equal(mary, link.user)
    assert_users_equal(rolf, link.observation.user)
    assert_false(link.external_site.project.is_member?(dick))
    params = {
      method:  :delete,
      action:  :external_link,
      api_key: @api_key.key,
      id:      link.id
    }
    recreate_params = {
      user:          mary,
      observation:   link.observation,
      external_site: link.external_site,
      url:           link.url
    }
    @api_key.update_attributes!(user: dick)
    assert_api_fail(params)
    @api_key.update_attributes!(user: rolf)
    assert_api_pass(params)
    assert_nil(ExternalLink.safe_find(link.id))
    link = ExternalLink.create!(recreate_params)
    @api_key.update_attributes!(user: mary)
    assert_api_pass(params.merge(id: link.id))
    assert_nil(ExternalLink.safe_find(link.id))
    link = ExternalLink.create!(recreate_params)
    @api_key.update_attributes!(user: dick)
    link.external_site.project.user_group.users << dick
    assert_api_pass(params.merge(id: link.id))
    assert_nil(ExternalLink.safe_find(link.id))
  end

  # ----------------------------------
  #  :section: ExternalSite Requests
  # ----------------------------------

  def test_getting_external_sites
    params = {
      method: :get,
      action: :external_site
    }
    sites = ExternalSite.where("name like '%inat%'")
    assert_not_empty(sites)
    assert_api_pass(params.merge(name: "inat"))
    assert_api_results(sites)
  end

  # -------------------------------
  #  :section: Herbarium Requests
  # -------------------------------

  def test_getting_herbaria
    params = {
      method: :get,
      action: :herbarium
    }

    herbs = Herbarium.where("date(created_at) = '2012-10-21'")
    assert_not_empty(herbs)
    assert_api_pass(params.merge(created_at: "2012-10-21"))
    assert_api_results(herbs)

    herbs = [herbaria(:nybg_herbarium)]
    assert_not_empty(herbs)
    assert_api_pass(params.merge(updated_at: "2012-10-21 12:14"))
    assert_api_results(herbs)

    herbs = Herbarium.where(code: "NY")
    assert_not_empty(herbs)
    assert_api_pass(params.merge(code: "NY"))
    assert_api_results(herbs)

    herbs = Herbarium.where("name like '%personal%'")
    assert_not_empty(herbs)
    assert_api_pass(params.merge(name: "personal"))
    assert_api_results(herbs)

    herbs = Herbarium.where("description like '%awesome%'")
    assert_not_empty(herbs)
    assert_api_pass(params.merge(description: "awesome"))
    assert_api_results(herbs)

    herbs = Herbarium.where("mailing_address like '%New York%'")
    assert_not_empty(herbs)
    assert_api_pass(params.merge(address: "New York"))
    assert_api_results(herbs)
  end

  # --------------------------------------
  #  :section: Herbarium Record Requests
  # --------------------------------------

  def test_getting_herbarium_records
    params = { method: :get, action: :herbarium_record }

    recs = HerbariumRecord.where("year(created_at) = 2012")
    assert_not_empty(recs)
    assert_api_pass(params.merge(created_at: "2012"))
    assert_api_results(recs)

    recs = HerbariumRecord.where("year(updated_at) = 2017")
    assert_not_empty(recs)
    assert_api_pass(params.merge(updated_at: "2017"))
    assert_api_results(recs)

    recs = HerbariumRecord.where(user: mary)
    assert_not_empty(recs)
    assert_api_pass(params.merge(user: "mary"))
    assert_api_results(recs)

    herb = herbaria(:nybg_herbarium)
    recs = herb.herbarium_records
    assert_not_empty(recs)
    assert_api_pass(params.merge(herbarium: "The New York Botanical Garden"))
    assert_api_results(recs)

    obs  = observations(:detailed_unknown_obs)
    recs = obs.herbarium_records
    assert_not_empty(recs)
    assert_api_pass(params.merge(observation: obs.id))
    assert_api_results(recs)

    recs = HerbariumRecord.where("notes LIKE '%dried%'")
    assert_not_empty(recs)
    assert_api_pass(params.merge(notes_has: "dried"))
    assert_api_results(recs)

    recs = HerbariumRecord.where("COALESCE(notes, '') = ''")
    assert_not_empty(recs)
    assert_api_pass(params.merge(has_notes: "no"))
    assert_api_results(recs)

    recs = HerbariumRecord.where("CONCAT(notes, '') != ''")
    assert_not_empty(recs)
    assert_api_pass(params.merge(has_notes: "yes"))
    assert_api_results(recs)

    recs = HerbariumRecord.where(initial_det: "Coprinus comatus")
    assert_not_empty(recs)
    assert_api_pass(params.merge(initial_det: "Coprinus comatus"))
    assert_api_results(recs)

    recs = HerbariumRecord.where("initial_det LIKE '%coprinus%'")
    assert_not_empty(recs)
    assert_api_pass(params.merge(initial_det_has: "coprinus"))
    assert_api_results(recs)

    recs = HerbariumRecord.where(accession_number: "NYBG 1234")
    assert_not_empty(recs)
    assert_api_pass(params.merge(accession_number: "NYBG 1234"))
    assert_api_results(recs)

    recs = HerbariumRecord.where("accession_number LIKE '%nybg%'")
    assert_not_empty(recs)
    assert_api_pass(params.merge(accession_number_has: "nybg"))
    assert_api_results(recs)
  end

  def test_posting_herbarium_records
    rolfs_obs         = observations(:strobilurus_diminutivus_obs)
    marys_obs         = observations(:detailed_unknown_obs)
    @obs              = rolfs_obs
    @herbarium        = herbaria(:mycoflora_herbarium)
    @initial_det      = "Absurdus namus"
    @accession_number = "13579a"
    @notes            = "i make good specimen"
    @user             = rolf
    params = {
      method:           :post,
      action:           :herbarium_record,
      api_key:          @api_key.key,
      observation:      @obs.id,
      herbarium:        @herbarium.id,
      initial_det:      @initial_det,
      accession_number: @accession_number,
      notes:            @notes
    }
    assert_api_fail(params.remove(:api_key))
    assert_api_fail(params.remove(:observation))
    assert_api_fail(params.remove(:herbarium))
    assert_api_fail(params.merge(observation: marys_obs.id))
    assert_api_pass(params)
    assert_last_herbarium_record_correct

    herbarium_record_count = HerbariumRecord.count
    rolfs_other_obs = observations(:stereum_hirsutum_1)
    assert_api_pass(params.merge(observation: rolfs_other_obs.id))
    assert_equal(herbarium_record_count, HerbariumRecord.count)
    assert_obj_list_equal([rolfs_obs, rolfs_other_obs],
                          HerbariumRecord.last.observations, :sort)

    # Make sure it gives correct default for initial_det.
    assert_api_pass(params.remove(:initial_det).merge(accession_number: "2"))
    assert_equal(rolfs_obs.name.text_name, HerbariumRecord.last.initial_det)

    # Check default accession number if obs has no collection number.
    assert_api_pass(params.remove(:accession_number))
    assert_equal("MO #{rolfs_obs.id}", HerbariumRecord.last.accession_number)

    # Check default accession number if obs has one collection number.
    obs = observations(:coprinus_comatus_obs)
    num = obs.collection_numbers.first
    assert_operator(obs.collection_numbers.count, :==, 1)
    assert_api_pass(params.remove(:accession_number).
                           merge(observation: obs.id))
    assert_equal(num.format_name, HerbariumRecord.last.accession_number)

    # Check default accession number if obs has two collection numbers.
    # Also check that Rolf can add a record to Mary's obs if he's a curator.
    nybg = herbaria(:nybg_herbarium)
    assert_true(nybg.curator?(rolf))
    assert_operator(marys_obs.collection_numbers.count, :>, 1)
    assert_api_pass(params.remove(:accession_number).
                      merge(observation: marys_obs.id, herbarium: nybg.id))
    assert_equal("MO #{marys_obs.id}", HerbariumRecord.last.accession_number)
  end

  def test_patching_herbarium_records
    # Rolf owns the first record, and curates NYBG, but shouldn't be able to
    # touch Mary's record at an herbarium that he doesn't curate.
    rolfs_rec = herbarium_records(:coprinus_comatus_rolf_spec)
    nybgs_rec = herbarium_records(:interesting_unknown)
    marys_rec = herbarium_records(:mycoflora_record)
    mycoflora = herbaria(:mycoflora_herbarium)
    params = {
      method:               :patch,
      action:               :herbarium_record,
      api_key:              @api_key.key,
      id:                   rolfs_rec.id,
      set_herbarium:        "North American Mycoflora Project",
      set_initial_det:      " New name ",
      set_accession_number: " 1234 ",
      set_notes:            " new notes "
    }
    assert_api_fail(params.remove(:api_key))
    assert_api_fail(params.merge(id: marys_rec.id))
    assert_api_fail(params.merge(set_herbarium: ""))
    assert_api_fail(params.merge(set_initial_det: ""))
    assert_api_fail(params.merge(set_accession_number: ""))
    assert_api_pass(params)
    assert_objs_equal(mycoflora, rolfs_rec.reload.herbarium)
    assert_equal("New name", rolfs_rec.initial_det)
    assert_equal("1234", rolfs_rec.accession_number)
    assert_equal("new notes", rolfs_rec.notes)

    # This should fail because we don't allow merges via API.
    assert_api_fail(params.merge(id: nybgs_rec.id))
    assert_api_pass(params.merge(id: nybgs_rec.id).remove(:set_herbarium))
    assert_equal("New name", nybgs_rec.reload.initial_det)
    assert_equal("1234", nybgs_rec.accession_number)
    assert_equal("new notes", nybgs_rec.notes)

    # Rolfs_rec is now at Mycoflora, so Rolf is not a curator, just owns rec.
    old_obs   = rolfs_rec.observations.first
    rolfs_obs = observations(:agaricus_campestris_obs)
    marys_obs = observations(:minimal_unknown_obs)
    params = {
      method:  :patch,
      action:  :herbarium_record,
      api_key: @api_key.key,
      id:      rolfs_rec.id
    }
    assert_api_fail(params.merge(add_observation: marys_obs.id))
    assert_api_pass(params.merge(add_observation: rolfs_obs.id))
    assert_obj_list_equal([old_obs, rolfs_obs], rolfs_rec.reload.observations,
                          :sort)
    assert_api_pass(params.merge(remove_observation: old_obs.id))
    assert_obj_list_equal([rolfs_obs], rolfs_rec.reload.observations)
    assert_api_pass(params.merge(remove_observation: rolfs_obs.id))
    assert_nil(HerbariumRecord.safe_find(rolfs_rec.id))
  end

  def test_deleting_herbarium_records
    # Rolf should be able to destroy his own records and NYBG records but not
    # Mary's records at a different herbarium that he doesn't curate.
    rolfs_rec = herbarium_records(:coprinus_comatus_rolf_spec)
    nybgs_rec = herbarium_records(:interesting_unknown)
    marys_rec = herbarium_records(:mycoflora_record)
    params = {
      method:     :delete,
      action:     :herbarium_record,
      api_key:    @api_key.key
    }
    assert_api_fail(params.remove(:api_key))
    assert_api_pass(params.merge(id: rolfs_rec.id))
    assert_api_pass(params.merge(id: nybgs_rec.id))
    assert_api_fail(params.merge(id: marys_rec.id))
    assert_nil(HerbariumRecord.safe_find(rolfs_rec.id))
    assert_nil(HerbariumRecord.safe_find(nybgs_rec.id))
    assert_not_nil(HerbariumRecord.safe_find(marys_rec.id))
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
    File.stub(:rename, true) do
      File.stub(:chmod, true) do
        api = API.execute(params)
        assert_no_errors(api, "Errors while posting image")
        assert_obj_list_equal([Image.last], api.results)
      end
    end
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
    File.stub(:rename, true) do
      File.stub(:chmod, true) do
        api = API.execute(params)
        assert_no_errors(api, "Errors while posting image")
        assert_obj_list_equal([Image.last], api.results)
      end
    end
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
    File.stub(:rename, false) do
      api = API.execute(params)
      assert_no_errors(api, "Errors while posting image")
      img = Image.last
      assert_obj_list_equal([img], api.results)
      actual = File.read(img.local_file_name(:full_size))
      expect = File.read("#{::Rails.root}/test/images/test_image.jpg")
      assert_equal(expect, actual, "Uploaded image differs from original!")
    end
  end

  def test_patching_images
    rolfs_img = images(:rolf_profile_image)
    marys_img = images(:in_situ_image)
    eol = projects(:eol_project)
    pd = licenses(:publicdomain)
    assert(rolfs_img.can_edit?(rolf))
    assert(!marys_img.can_edit?(rolf))
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
    assert_api_fail(params.merge(set_date: ""))
    assert_api_fail(params.merge(set_license: ""))
    assert_api_pass(params.merge(id: rolfs_img.id))
    rolfs_img.reload
    assert_equal(Date.parse("2012-3-4"), rolfs_img.when)
    assert_equal("new notes", rolfs_img.notes)
    assert_equal("new person", rolfs_img.copyright_holder)
    assert_objs_equal(pd, rolfs_img.license)
    assert_equal("new name", rolfs_img.original_name)
    eol.images << marys_img
    marys_img.reload
    assert(marys_img.can_edit?(rolf))
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
      api_key: @api_key.key
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

    locs = Location.where("south >= 39 and north <= 40 and
                           west >= -124 and east <= -123 and west <= east")
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

  def test_patching_locations
    albion = locations(:albion)
    burbank = locations(:burbank)
    params = {
      method:    :patch,
      action:    :location,
      api_key:   @api_key.key,
      id:        albion.id,
      set_name:  "Reno, Nevada, USA",
      set_north: 39.64,
      set_south: 39.39,
      set_east:  -119.70,
      set_west:  -119.94,
      set_high:  1700,
      set_low:   1350,
      set_notes: "Biggest Little City"
    }

    # Just to be clear about the starting point, the only objects attached to
    # this location at first are some versions and a description, all owned by
    # rolf, the same user who created the location.  So it should be modifiable
    # as it is.  The plan is to temporarily attach one object at a time to make
    # sure it is *not* modifiable if anything is wrong.
    assert_objs_equal(rolf, albion.user)
    assert_not_empty(albion.versions.select {|v| v.user_id == rolf.id})
    assert_not_empty(albion.descriptions.select {|v| v.user == rolf})
    assert_empty(albion.versions.select {|v| v.user_id != rolf.id})
    assert_empty(albion.descriptions.select {|v| v.user != rolf})
    assert_empty(albion.observations)
    assert_empty(albion.species_lists)
    assert_empty(albion.users)
    assert_empty(albion.herbaria)

    # Not allowed to change if anyone else has an observation there.
    obs = observations(:minimal_unknown_obs)
    assert_objs_equal(mary, obs.user)
    obs.update_attributes!(location: albion)
    assert_api_fail(params)
    obs.update_attributes!(location: burbank)

    # But allow it if rolf owns that observation.
    obs = observations(:coprinus_comatus_obs)
    assert_objs_equal(rolf, obs.user)
    obs.update_attributes!(location: albion)

    # Not allowed to change if anyone else has a species_list there.
    spl = species_lists(:unknown_species_list)
    assert_objs_equal(mary, spl.user)
    spl.update_attributes!(location: albion)
    assert_api_fail(params)
    spl.update_attributes!(location: burbank)

    # But allow it if rolf owns that list.
    spl = species_lists(:first_species_list)
    assert_objs_equal(rolf, spl.user)
    spl.update_attributes!(location: albion)

    # Not allowed to change if anyone has made this their personal location.
    mary.update_attributes!(location: albion)
    assert_api_fail(params)
    mary.update_attributes!(location: burbank)

    # But allow it if rolf is that user.
    rolf.update_attributes!(location: albion)

    # Not allowed to change if an herbarium is at that location, period.
    nybg = herbaria(:nybg_herbarium)
    nybg.update_attributes!(location: albion)
    assert_api_fail(params)
    nybg.update_attributes!(location: burbank)

    # Not allowed to change if user didn't create it.
    albion.update_attributes!(user: mary)
    assert_api_fail(params)
    albion.update_attributes!(user: rolf)

    # Okay, permissions should be right, now.  Proceed to "normal" tests.  That
    # is, make sure api key is required, and that name is valid and not already
    # taken.
    assert_api_fail(params.remove(:api_key))
    assert_api_fail(params.merge(set_name: ""))
    assert_api_fail(params.merge(set_name: "Evil Lair, Latveria"))
    assert_api_fail(params.merge(set_name: burbank.display_name))
    assert_api_fail(params.merge(set_north: "", set_south: "", set_west: "",
                                 set_east: ""))
    assert_api_pass(params)

    albion.reload
    assert_equal("Reno, Nevada, USA", albion.display_name)
    assert_in_delta(39.64, albion.north, 0.0001)
    assert_in_delta(39.39, albion.south, 0.0001)
    assert_in_delta(-119.70, albion.east, 0.0001)
    assert_in_delta(-119.94, albion.west, 0.0001)
    assert_in_delta(1700, albion.high, 0.0001)
    assert_in_delta(1350, albion.low, 0.0001)
    assert_equal("Biggest Little City", albion.notes)
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

  def test_getting_names
    params = { method: :get, action: :name }

    name = Name.where(correct_spelling: nil).sample
    assert_api_pass(params.merge(id: name.id))
    assert_api_results([name])

    names = Name.where("year(created_at) = 2008").
            reject { |n| n.correct_spelling_id }
    assert_not_empty(names)
    assert_api_pass(params.merge(created_at: "2008"))
    assert_api_results(names)

    names = Name.where("date(updated_at) = '2008-09-05'").
            reject { |n| n.correct_spelling_id }
    assert_not_empty(names)
    assert_api_pass(params.merge(updated_at: "2008-09-05"))
    assert_api_results(names)

    names = Name.where(user: mary).
            reject { |n| n.correct_spelling_id }
    assert_not_empty(names)
    assert_api_pass(params.merge(user: "mary"))
    assert_api_results(names)

    names = Name.where(text_name: "Lentinellus ursinus").
            reject { |n| n.correct_spelling_id }
    assert_not_empty(names)
    assert_api_fail(params.merge(name: "Lentinellus ursinus"))
    assert_api_pass(params.merge(name: "Lentinellus ursinus Kühner,
                                        Lentinellus ursinus Kuhner"))
    assert_api_results(names)

    names = names(:lactarius_alpinus).synonyms.sort_by(&:id).
            reject { |n| n.correct_spelling_id }
    assert_not_empty(names)
    assert_api_pass(params.merge(synonyms_of: "Lactarius alpinus"))
    assert_api_results(names)

    names = Name.where("classification like '%Fungi%'").each do |n|
      genus = n.text_name.split.first
      Name.where("text_name like '#{genus} %'") + [n]
    end.flatten.uniq.sort_by(&:id).reject { |n| n.correct_spelling_id }
    assert_not_empty(names)
    assert_api_pass(params.merge(children_of: "Fungi"))
    assert_api_results(names)

    names = Name.where(deprecated: true).
            reject { |n| n.correct_spelling_id }
    assert_not_empty(names)
    assert_api_pass(params.merge(is_deprecated: "true"))
    assert_api_results(names)

    names = Name.where("date(updated_at) = '2009-10-12'")
    goods = names.reject { |n| n.correct_spelling_id }
    bads  = names.select { |n| n.correct_spelling_id }
    assert_not_empty(names)
    assert_not_empty(goods)
    assert_not_empty(bads)
    assert_api_pass(params.merge(updated_at: "20091012", misspellings: :either))
    assert_api_results(names)
    assert_api_pass(params.merge(updated_at: "20091012", misspellings: :only))
    assert_api_results(bads)
    assert_api_pass(params.merge(updated_at: "20091012", misspellings: :no))
    assert_api_results(goods)
    assert_api_pass(params.merge(updated_at: "20091012"))
    assert_api_results(goods)

    without = Name.where(synonym_id: nil)
    with    = Name.where.not(synonym_id: nil).
              reject { |n| n.correct_spelling_id }
    assert_not_empty(without)
    assert_not_empty(with)
    assert_api_pass(params.merge(has_synonyms: "no"))
    assert_api_results(without)
    assert_api_pass(params.merge(has_synonyms: "true"))
    assert_api_results(with)

    loc   = locations(:burbank)
    names = loc.observations.map(&:name).
            flatten.uniq.sort_by(&:id).
            reject { |n| n.correct_spelling_id }
    assert_not_empty(names)
    assert_api_pass(params.merge(location: loc.id))
    assert_api_results(names)

    spl   = species_lists(:unknown_species_list)
    names = spl.observations.map(&:name).
            flatten.uniq.sort_by(&:id).
            reject { |n| n.correct_spelling_id }
    assert_not_empty(names)
    assert_api_pass(params.merge(species_list: spl.id))
    assert_api_results(names)

    names = Name.where(rank: Name.ranks[:Variety]).
            reject { |n| n.correct_spelling_id }
    assert_not_empty(names)
    assert_api_pass(params.merge(rank: "variety"))
    assert_api_results(names)

    with    = Name.where.not("author is null or author = ''").
              reject { |n| n.correct_spelling_id }
    without = Name.where("author is null or author = ''").
              reject { |n| n.correct_spelling_id }
    assert_not_empty(with)
    assert_not_empty(without)
    assert_api_pass(params.merge(has_author: "yes"))
    assert_api_results(with)
    assert_api_pass(params.merge(has_author: "no"))
    assert_api_results(without)

    with    = Name.where.not("citation is null or citation = ''").
              reject { |n| n.correct_spelling_id }
    without = Name.where("citation is null or citation = ''").
              reject { |n| n.correct_spelling_id }
    assert_not_empty(with)
    assert_not_empty(without)
    assert_api_pass(params.merge(has_citation: "yes"))
    assert_api_results(with)
    assert_api_pass(params.merge(has_citation: "no"))
    assert_api_results(without)

    with    = Name.where.not("classification is null or classification = ''").
              reject { |n| n.correct_spelling_id }
    without = Name.where("classification is null or classification = ''").
              reject { |n| n.correct_spelling_id }
    assert_not_empty(with)
    assert_not_empty(without)
    assert_api_pass(params.merge(has_classification: "yes"))
    assert_api_results(with)
    assert_api_pass(params.merge(has_classification: "no"))
    assert_api_results(without)

    with    = Name.where.not("notes is null or notes = ''").
              reject { |n| n.correct_spelling_id }
    without = Name.where("notes is null or notes = ''").
              reject { |n| n.correct_spelling_id }
    assert_not_empty(with)
    assert_not_empty(without)
    assert_api_pass(params.merge(has_notes: "yes"))
    assert_api_results(with)
    assert_api_pass(params.merge(has_notes: "no"))
    assert_api_results(without)

    names = Comment.where(target_type: "Name").map(&:target).
            uniq.sort_by(&:id).reject { |n| n.correct_spelling_id }
    assert_not_empty(names)
    assert_api_pass(params.merge(has_comments: "yes"))
    assert_api_results(names)

    with    = Name.where.not(description_id: nil).
              reject { |n| n.correct_spelling_id }
    without = Name.where(description_id: nil).
              reject { |n| n.correct_spelling_id }
    assert_not_empty(with)
    assert_not_empty(without)
    assert_api_pass(params.merge(has_description: "yes"))
    assert_api_results(with)
    assert_api_pass(params.merge(has_description: "no"))
    assert_api_results(without)

    names = Name.where("text_name like '%bunny%'").
            reject { |n| n.correct_spelling_id }
    assert_not_empty(names)
    assert_api_pass(params.merge(text_name_has: "bunny"))
    assert_api_results(names)

    names = Name.where("author like '%peck%'").
            reject { |n| n.correct_spelling_id }
    assert_not_empty(names)
    assert_api_pass(params.merge(author_has: "peck"))
    assert_api_results(names)

    names = Name.where("citation like '%lichenes%'").
            reject { |n| n.correct_spelling_id }
    assert_not_empty(names)
    assert_api_pass(params.merge(citation_has: "lichenes"))
    assert_api_results(names)

    names = Name.where("classification like '%lecanorales%'").
            reject { |n| n.correct_spelling_id }
    assert_not_empty(names)
    assert_api_pass(params.merge(classification_has: "lecanorales"))
    assert_api_results(names)

    names = Name.where("notes like '%known%'").
            reject { |n| n.correct_spelling_id }
    assert_not_empty(names)
    assert_api_pass(params.merge(notes_has: "known"))
    assert_api_results(names)

    names = Comment.where("target_type = 'Name' and comment like '%mess%'").
            map(&:target).uniq.sort_by(&:id).
            reject { |n| n.correct_spelling_id }
    assert_not_empty(names)
    assert_api_pass(params.merge(comments_has: "mess"))
    assert_api_results(names)

    Name.where(correct_spelling: nil).sample.
      update_attributes!(ok_for_export: true)
    names = Name.where(ok_for_export: true).
            reject { |n| n.correct_spelling_id }
    assert_not_empty(names)
    assert_api_pass(params.merge(ok_for_export: "yes"))
    assert_api_results(names)
  end

  def test_creating_names
    @name           = "Parmeliaceae"
    @author         = ""
    @rank           = :Family
    @deprecated     = true
    @citation       = ""
    @classification = ""
    @notes          = ""
    @user           = rolf
    params = {
      method:         :post,
      action:         :name,
      api_key:        @api_key.key,
      name:           @name,
      rank:           @rank,
      deprecated:     @deprecated
    }
    assert_api_fail(params.remove(:api_key))
    assert_api_fail(params.remove(:name))
    assert_api_fail(params.remove(:rank))
    assert_api_fail(params.merge(name: "Agaricus"))
    assert_api_fail(params.merge(rank: "Species"))
    assert_api_fail(params.merge(classification: "spam spam spam"))
    assert_api_pass(params)
    assert_last_name_correct

    @name           = "Anzia ornata"
    @author         = "(Zahlbr.) Asahina"
    @rank           = :Species
    @deprecated     = false
    @citation       = "Jap. Bot. 13: 219-226"
    @classification = "Kingdom: _Fungi_\r\nFamily: _Parmeliaceae_"
    @notes          = "neat species!"
    @user           = rolf
    params = {
      method:         :post,
      action:         :name,
      api_key:        @api_key.key,
      name:           @name,
      author:         @author,
      rank:           @rank,
      deprecated:     @deprecated,
      citation:       @citation,
      classification: @classification,
      notes:          @notes
    }
    assert_api_pass(params)
    assert_last_name_correct(Name.where(text_name: @name).first)
    assert_not_empty(Name.where(text_name: "Anzia"))
  end

  def test_patching_name_attributes
    agaricus = names(:agaricus)
    lepiota  = names(:lepiota)
    new_classification = [
      "Kingdom: Fungi",
      "Class: Basidiomycetes",
      "Order: Agaricales",
      "Family: Agaricaceae"
    ].join("\n")
    params = {
      method:             :patch,
      action:             :name,
      api_key:            @api_key.key,
      id:                 agaricus.id,
      set_notes:          "new notes",
      set_citation:       "new citation",
      set_classification: new_classification
    }

    lepiota.update_attributes!(user: mary)

    # Just to be clear about the starting point, the only objects attached to
    # this name at first are a version and a description, both owned by rolf,
    # the same user who created the name.  So it should be modifiable as it is.
    # The plan is to temporarily attach one object at a time to make sure it is
    # *not* modifiable if anything is wrong.
    assert_objs_equal(rolf, agaricus.user)
    assert_not_empty(agaricus.versions.select {|v| v.user_id == rolf.id})
    assert_not_empty(agaricus.descriptions.select {|v| v.user == rolf})
    assert_empty(agaricus.versions.select {|v| v.user_id != rolf.id})
    assert_empty(agaricus.descriptions.select {|v| v.user != rolf})
    assert_empty(agaricus.observations)
    assert_empty(agaricus.namings)

    # Not allowed to change if anyone else has an observation of that name.
    obs = observations(:minimal_unknown_obs)
    assert_objs_equal(mary, obs.user)
    obs.update_attributes!(name: agaricus)
    assert_api_fail(params)
    obs.update_attributes!(name: lepiota)

    # But allow it if rolf owns that observation.
    obs = observations(:coprinus_comatus_obs)
    assert_objs_equal(rolf, obs.user)
    obs.update_attributes!(name: agaricus)

    # Not allowed to change if anyone else has proposed that name.
    nam = namings(:detailed_unknown_naming)
    assert_objs_equal(mary, nam.user)
    nam.update_attributes!(name: agaricus)
    assert_api_fail(params)
    nam.update_attributes!(name: lepiota)

    # But allow it if rolf owns that name proposal.
    nam = namings(:coprinus_comatus_naming)
    assert_objs_equal(rolf, nam.user)
    nam.update_attributes!(name: agaricus)

    # Not allowed to change if user didn't create it.
    agaricus.update_attributes!(user: mary)
    assert_api_fail(params)
    agaricus.update_attributes!(user: rolf)

    # Okay, permissions should be right, now.  Proceed to "normal" tests.  That
    # is, make sure api key is required, and that classification is valid.
    assert_api_fail(params.remove(:api_key))
    assert_api_fail(params.merge(set_classification: "spam spam spam"))
    assert_api_pass(params)

    agaricus.reload
    assert_equal("new notes", agaricus.notes)
    assert_equal("new citation", agaricus.citation)
    assert_equal(Name.validate_classification(:Genus, new_classification),
                 agaricus.classification)
  end

  def test_changing_names
    agaricus = names(:agaricus)
    params = {
      method:  :patch,
      action:  :name,
      api_key: @api_key.key,
      id:      agaricus.id
    }
    assert_api_fail(params.merge(set_name: ""))
    assert_api_pass(params.merge(set_name: "Suciraga"))
    assert_equal("Suciraga", agaricus.reload.text_name)
    assert_api_pass(params.merge(set_author: "L."))
    assert_equal("Suciraga L.", agaricus.reload.search_name)
    assert_api_pass(params.merge(set_rank: "order"))
    assert_equal(:Order, agaricus.reload.rank)
    assert_api_fail(params.merge(set_rank: ""))
    assert_api_fail(params.merge(set_rank: "species"))
    assert_api_pass(params.merge(
      set_name:   "Agaricus bitorquis",
      set_author: "(Quélet) Sacc.",
      set_rank:   "species"
    ))
    agaricus.reload
    assert_equal("Agaricus bitorquis (Quélet) Sacc.", agaricus.search_name)
    assert_equal(:Species, agaricus.rank)
    parent = Name.where(text_name: "Agaricus").to_a
    assert_not_empty(parent)
    assert_not_equal(agaricus.id, parent[0].id)
  end

  def test_changing_deprecation
    agaricus = names(:agaricus)
    params = {
      method:  :patch,
      action:  :name,
      api_key: @api_key.key,
      id:      agaricus.id
    }
    assert_api_pass(params.merge(set_deprecated: "true"))
    assert_true(agaricus.reload.deprecated)
    assert_equal("__Agaricus__", agaricus.display_name)
    assert_api_pass(params.merge(set_deprecated: "false"))
    assert_false(agaricus.reload.deprecated)
    assert_equal("**__Agaricus__**", agaricus.display_name)
  end

  def test_changing_synonymy
    name1 = names(:lactarius_alpigenes)
    name2 = names(:lactarius_subalpinus)
    name3 = names(:macrolepiota_rhacodes)
    params = {
      method:  :patch,
      action:  :name,
      api_key: @api_key.key
    }
    syns = name1.synonyms
    assert(syns.count > 2)
    assert(syns.include?(name2))
    assert_api_pass(params.merge(id: name1.id, clear_synonyms: "yes"))
    assert_obj_list_equal([name1], Name.find(name1.id).synonyms)
    assert_obj_list_equal(syns-[name1], Name.find(name2.id).synonyms)
    assert_api_fail(params.merge(id: name2.id, synonymize_with: name1.id))
    assert_api_pass(params.merge(id: name1.id, synonymize_with: name2.id))
    assert_obj_list_equal(syns, Name.find(name1.id).synonyms)
    assert_api_fail(params.merge(id: name1.id, synonymize_with: name3.id))
  end

  def test_changing_correct_spelling
    correct  = names(:macrolepiota_rhacodes)
    misspelt = names(:macrolepiota_rachodes)
    params = {
      method:  :patch,
      action:  :name,
      api_key: @api_key.key
    }
    correct.clear_synonym
    assert_api_pass(params.merge(id: misspelt.id,
                                 set_correct_spelling: correct.id))
    misspelt = Name.find(misspelt.id) # reload might not be enough
    assert_true(misspelt.deprecated)
    assert_names_equal(correct, misspelt.correct_spelling)
    assert_obj_list_equal([correct, misspelt].sort_by(&:id),
                          misspelt.synonyms.sort_by(&:id))
  end

  def test_deleting_names
    name = rolf.names.sample
    params = {
      method:  :delete,
      action:  :name,
      api_key: @api_key.key,
      id:      name.id
    }
    # No DELETE requests should be allowed at all.
    assert_api_fail(params)
  end

  # ---------------------------------
  #  :section: Observation Requests
  # ---------------------------------

  def test_getting_observations
    params = { method: :get, action: :observation }

    obs = Observation.all.sample
    assert_api_pass(params.merge(id: obs.id))
    assert_api_results([obs])

    obses = Observation.where("year(created_at) = 2010")
    assert_not_empty(obses)
    assert_api_pass(params.merge(created_at: "2010"))
    assert_api_results(obses)

    obses = Observation.where("date(updated_at) = '2007-06-24'")
    assert_not_empty(obses)
    assert_api_pass(params.merge(updated_at: "20070624"))
    assert_api_results(obses)

    obses = Observation.where("year(`when`) >= 2012 and year(`when`) <= 2014")
    assert_not_empty(obses)
    assert_api_pass(params.merge(date: "2012-2014"))
    assert_api_results(obses)

    obses = Observation.where(user: dick)
    assert_not_empty(obses)
    assert_api_pass(params.merge(user: "dick"))
    assert_api_results(obses)

    obses = Observation.where(name: names(:fungi))
    assert_not_empty(obses)
    assert_api_pass(params.merge(name: "Fungi"))
    assert_api_results(obses)

    Observation.create!(user: rolf, when: Time.now, where: locations(:burbank),
                        name: names(:lactarius_alpinus))
    Observation.create!(user: rolf, when: Time.now, where: locations(:burbank),
                        name: names(:lactarius_alpigenes))
    obses = Observation.where(name: names(:lactarius_alpinus).synonyms)
    assert(obses.length > 1)
    assert_api_pass(params.merge(synonyms_of: "Lactarius alpinus"))
    assert_api_results(obses)

    obses = Observation.where(name: Name.where("text_name like 'Agaricus%'"))
    assert(obses.length > 1)
    assert_api_pass(params.merge(children_of: "Agaricus"))
    assert_api_results(obses)

    obses = Observation.where(location: locations(:burbank))
    assert(obses.length > 1)
    assert_api_pass(params.merge(location: 'Burbank\, California\, USA'))
    assert_api_results(obses)

    obses = HerbariumRecord.where(herbarium: herbaria(:nybg_herbarium)).
            map(&:observations).flatten.sort_by(&:id)
    assert(obses.length > 1)
    assert_api_pass(params.merge(herbarium: "The New York Botanical Garden"))
    assert_api_results(obses)

    rec = herbarium_records(:interesting_unknown)
    obses = rec.observations.sort_by(&:id)
    assert(obses.length > 1)
    assert_api_pass(params.merge(herbarium_record: rec.id))
    assert_api_results(obses)

    proj = projects(:one_genus_two_species_project)
    obses = proj.observations.sort_by(&:id)
    assert(obses.length > 1)
    assert_api_pass(params.merge(project: proj.id))
    assert_api_results(obses)

    spl = species_lists(:one_genus_three_species_list)
    obses = spl.observations.sort_by(&:id)
    assert(obses.length > 1)
    assert_api_pass(params.merge(species_list: spl.id))
    assert_api_results(obses)

    obses = Observation.where(vote_cache: 3)
    assert(obses.length > 1)
    assert_api_pass(params.merge(confidence: "3.0"))
    assert_api_results(obses)

    obses = Observation.where(is_collection_location: false)
    assert(obses.length > 1)
    assert_api_pass(params.merge(is_collection_location: "no"))
    assert_api_results(obses)

    with    = Observation.where.not(thumb_image_id: nil)
    without = Observation.where(thumb_image_id: nil)
    assert(with.length > 1)
    assert(without.length > 1)
    assert_api_pass(params.merge(has_images: "yes"))
    assert_api_results(with)
    assert_api_pass(params.merge(has_images: "no"))
    assert_api_results(without)

    with    = Observation.where.not(location: nil)
    without = Observation.where(location: nil)
    assert(with.length > 1)
    assert(without.length > 1)
    assert_api_pass(params.merge(has_location: "yes"))
    assert_api_results(with)
    assert_api_pass(params.merge(has_location: "no"))
    assert_api_results(without)

    genus = Name.ranks[:Genus]
    group = Name.ranks[:Group]
    names = Name.where("rank <= #{genus} or rank = #{group}")
    with    = Observation.where(name: names)
    without = Observation.where.not(name: names)
    assert(with.length > 1)
    assert(without.length > 1)
    assert_api_pass(params.merge(has_name: "yes"))
    assert_api_results(with)
    assert_api_pass(params.merge(has_name: "no"))
    assert_api_results(without)

    obses = Comment.where(target_type: "Observation").
            map(&:target).uniq.sort_by(&:id)
    assert(obses.length > 1)
    assert_api_pass(params.merge(has_comments: "yes"))
    assert_api_results(obses)

    with    = Observation.where(specimen: true)
    without = Observation.where(specimen: false)
    assert(with.length > 1)
    assert(without.length > 1)
    assert_api_pass(params.merge(has_specimen: "yes"))
    assert_api_results(with)
    assert_api_pass(params.merge(has_specimen: "no"))
    assert_api_results(without)

    no_notes = Observation.no_notes_persisted
    with    = Observation.where("notes != ?", no_notes)
    without = Observation.where("notes = ?", no_notes)
    assert(with.length > 1)
    assert(without.length > 1)
    assert_api_pass(params.merge(has_notes: "yes"))
    assert_api_results(with)
    assert_api_pass(params.merge(has_notes: "no"))
    assert_api_results(without)

    obses = Observation.where("notes like '%:substrate:%'").
            reject { |o| o.notes[:substrate].blank? }
    assert(obses.length > 1)
    assert_api_pass(params.merge(has_notes_field: "substrate"))
    assert_api_results(obses)

    obses = Observation.where("notes like '%orphan%'")
    assert(obses.length > 1)
    assert_api_pass(params.merge(notes_has: "orphan"))
    assert_api_results(obses)

    obses = Comment.where("concat(summary, comment) like \"%let's%\"").
            map(&:target).uniq.sort_by(&:id)
    assert(obses.length > 1)
    assert_api_pass(params.merge(comments_has: "let's"))
    assert_api_results(obses)

    obses = Observation.where("`lat` >= 34 and `lat` <= 35 and
                               `long` >= -119 and `long` <= -118")
    locs  = Location.where("south >= 34 and north <= 35 and west >= -119 and
                            east <= -118 and west <= east")
    obses = (obses + locs.map(&:observations)).flatten.uniq.sort_by(&:id)
    assert_not_empty(obses)
    assert_api_fail(params.merge(south: 34, east: -118, west: -119))
    assert_api_fail(params.merge(north: 35, east: -118, west: -119))
    assert_api_fail(params.merge(north: 35, south: 34, west: -119))
    assert_api_fail(params.merge(north: 35, south: 34, east: -118))
    assert_api_pass(params.merge(north: 35, south: 34, east: -118, west: -119))
    assert_api_results(obses)
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
    @notes = {
      Cap:   "scaly",
      Gills: "inky",
      Stipe: "smooth",
      Other: "These are notes.\nThey look like this."
    }
    @vote = 2.0
    @specimen = true
    @is_col_loc = true
    @lat = 39.229
    @long = -123.77
    @alt = 50
    params = {
      method:         :post,
      action:         :observation,
      api_key:        @api_key.key,
      date:           "20120626",
      "notes[Cap]":   "scaly",
      "notes[Gills]": "inky\n",
      "notes[Veil]":  "",
      "notes[Stipe]": "  smooth  ",
      notes:          "These are notes.\nThey look like this.\n",
      location:       "USA, California, Albion",
      latitude:       "39.229°N",
      longitude:      "123.770°W",
      altitude:       "50m",
      has_specimen:   "yes",
      name:           "Coprinus comatus",
      vote:           "2",
      projects:       @proj.id,
      species_lists:  @spl.id,
      thumbnail:      @img2.id,
      images:         "#{@img1.id},#{@img2.id}"
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
    assert_equal("Burbank, California, USA", obs.where)
    assert_objs_equal(locations(:burbank), obs.location)

    # API no longer pays attention to user's location format preference!  This
    # is supposed to make it more consistent for apps.  It would be a real
    # problem because apps don't have access to the user's prefs, so they have
    # no way of knowing how to pass in locations on the behalf of the user.
    User.update(rolf.id, location_format: :scientific)
    assert_equal(:scientific, rolf.reload.location_format)

    # params[:location] = "USA, California, Somewhere Else"
    params[:location] = "Somewhere Else, California, USA"
    api = API.execute(params)
    assert_no_errors(api, "Errors while posting observation")
    obs = Observation.last
    assert_nil(obs.location_id)
    assert_equal("Somewhere Else, California, USA", obs.where)

    params[:location] = "Burbank, California, USA"
    api = API.execute(params)
    assert_no_errors(api, "Errors while posting observation")
    obs = Observation.last
    assert_equal("Burbank, California, USA", obs.where)
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
    assert_api_fail(params.merge(has_specimen: "no", collection_number: "1"))
    assert_api_fail(params.merge(has_specimen: "no", accession_number: "1"))
    assert_api_fail(params.merge(has_specimen: "yes", herbarium: "bogus"))

    assert_api_pass(params.merge(has_specimen: "yes"))

    obs = Observation.last
    spec = HerbariumRecord.last
    assert_objs_equal(rolf.personal_herbarium, spec.herbarium)
    assert_equal("Peltigera: MO #{obs.id}", spec.herbarium_label)
    assert_obj_list_equal([obs], spec.observations)

    nybg = herbaria(:nybg_herbarium)
    assert_api_pass(params.merge(has_specimen: "yes", herbarium: nybg.code,
                                 collection_number: "12345"))

    obs = Observation.last
    spec = HerbariumRecord.last
    assert_objs_equal(nybg, spec.herbarium)
    assert_equal("Peltigera: Rolf Singer 12345", spec.herbarium_label)
    assert_obj_list_equal([obs], spec.observations)
  end

  def test_patching_observations
    rolfs_obs = observations(:coprinus_comatus_obs)
    marys_obs = observations(:detailed_unknown_obs)
    assert(rolfs_obs.can_edit?(rolf))
    assert(!marys_obs.can_edit?(rolf))
    params = {
      method:                     :patch,
      action:                     :observation,
      api_key:                    @api_key.key,
      id:                         rolfs_obs.id,
      set_date:                   "2012-12-12",
      set_location:               'Burbank\, California\, USA',
      set_has_specimen:           "no",
      set_is_collection_location: "no"
    }
    assert_api_fail(params.remove(:api_key))
    assert_api_fail(params.merge(id: marys_obs.id))
    assert_api_fail(params.merge(set_date: ""))
    assert_api_fail(params.merge(set_location: ""))
    assert_api_pass(params)
    rolfs_obs.reload
    assert_equal(Date.parse("2012-12-12"), rolfs_obs.when)
    assert_objs_equal(locations(:burbank), rolfs_obs.location)
    assert_equal("Burbank, California, USA", rolfs_obs.where)
    assert_equal(false, rolfs_obs.specimen)
    assert_equal(false, rolfs_obs.is_collection_location)

    params = {
      method:        :patch,
      action:        :observation,
      api_key:       @api_key.key,
      id:            rolfs_obs.id,
      set_latitude:  "12.34",
      set_longitude: "-56.78",
      set_altitude:  "901"
    }
    assert_api_fail(params.remove(:set_latitude))
    assert_api_fail(params.remove(:set_longitude))
    assert_api_pass(params)
    rolfs_obs.reload
    assert_in_delta(12.34, rolfs_obs.lat, 0.0001)
    assert_in_delta(-56.78, rolfs_obs.long, 0.0001)
    assert_in_delta(901, rolfs_obs.alt, 0.0001)

    params = {
      method:  :patch,
      action:  :observation,
      api_key: @api_key.key,
      id:      rolfs_obs.id
    }
    assert_api_pass(params.merge(
      :set_notes          => "wow!",
      :"set_notes[Cap]"   => "red",
      :"set_notes[Ring]"  => "none",
      :"set_notes[Gills]" => ""
    ))
    rolfs_obs.reload
    assert_equal({ Cap: "red", Ring: "none", Other: "wow!" }, rolfs_obs.notes)
    assert_api_pass(params.merge(:"set_notes[Cap]" => ""))
    rolfs_obs.reload
    assert_equal({ Ring: "none", Other: "wow!" }, rolfs_obs.notes)

    rolfs_img = (rolf.images - rolfs_obs.images).first
    marys_img = mary.images.first
    assert_api_fail(params.merge(set_thumbnail: ""))
    assert_api_fail(params.merge(set_thumbnail: marys_img.id))
    assert_api_pass(params.merge(set_thumbnail: rolfs_img.id))
    rolfs_obs.reload
    assert_objs_equal(rolfs_img, rolfs_obs.thumb_image)
    assert(rolfs_obs.images.include?(rolfs_img))
    imgs = rolf.images.map(&:id).map(&:to_s).join(",")
    assert_api_fail(params.merge(add_images: marys_img.id))
    assert_api_pass(params.merge(add_images: imgs))
    rolfs_obs.reload
    assert_objs_equal(rolfs_img, rolfs_obs.thumb_image)
    assert_obj_list_equal(rolf.images, rolfs_obs.images, :sort)
    assert_api_pass(params.merge(remove_images: rolfs_img.id))
    rolfs_obs.reload
    assert(rolfs_obs.thumb_image != rolfs_img)
    assert_objs_equal(rolfs_obs.images.first, rolfs_obs.thumb_image)
    imgs = rolf.images[2..6].map(&:id).map(&:to_s).join(",")
    imgs += ",#{marys_img.id}"
    assert_api_pass(params.merge(remove_images: imgs))
    rolfs_obs.reload
    assert_obj_list_equal(rolf.images - rolf.images[2..6] - [rolfs_img],
                          rolfs_obs.images, :sort)

    proj = projects(:bolete_project)
    proj.user_group.users << rolf
    rolf.reload
    assert(!proj.observations.include?(rolfs_obs))
    assert(proj.observations.include?(marys_obs))
    assert(rolfs_obs.can_edit?(rolf))
    assert(marys_obs.can_edit?(rolf))
    assert(rolfs_obs.user == rolf)
    assert(marys_obs.user == mary)
    assert_api_pass(params.merge(id: rolfs_obs.id, set_date: "2013-01-01"))
    assert_api_pass(params.merge(id: marys_obs.id, set_date: "2013-01-01"))
    assert_equal(Date.parse("2013-01-01"), rolfs_obs.reload.when)
    assert_equal(Date.parse("2013-01-01"), marys_obs.reload.when)
    assert_api_pass(params.merge(id: rolfs_obs.id, add_to_project: proj.id))
    assert_api_fail(params.merge(id: marys_obs.id, add_to_project: proj.id))
    assert(Project.find(proj.id).observations.include?(rolfs_obs))
    assert(Project.find(proj.id).observations.include?(marys_obs))
    assert_api_pass(params.merge(id: rolfs_obs.id, remove_from_project: proj.id))
    assert_api_fail(params.merge(id: marys_obs.id, remove_from_project: proj.id))
    assert(!Project.find(proj.id).observations.include?(rolfs_obs))
    assert(Project.find(proj.id).observations.include?(marys_obs))

    spl1 = species_lists(:unknown_species_list)
    spl2 = species_lists(:query_first_list)
    assert(spl1.can_edit?(rolf))
    assert(!spl2.can_edit?(rolf))
    assert_api_pass(params.merge(add_to_species_list: spl1.id))
    assert_api_fail(params.merge(add_to_species_list: spl2.id))
    assert(spl1.reload.observations.include?(rolfs_obs))
    assert(!spl2.reload.observations.include?(rolfs_obs))
    assert_api_pass(params.merge(remove_from_species_list: spl1.id))
    assert_api_fail(params.merge(remove_from_species_list: spl2.id))
    assert(!spl1.reload.observations.include?(rolfs_obs))
    assert(!spl2.reload.observations.include?(rolfs_obs))
  end

  def test_deleting_observations
    rolfs_obs = rolf.observations.sample
    marys_obs = mary.observations.sample
    params = {
      method:  :delete,
      action:  :observation,
      api_key: @api_key.key
    }
    assert_api_fail(params.merge(id: marys_obs.id))
    assert_api_pass(params.merge(id: rolfs_obs.id))
    assert_not_nil(Observation.safe_find(marys_obs.id))
    assert_nil(Image.safe_find(rolfs_obs.id))
  end

  # -----------------------------
  #  :section: Project Requests
  # -----------------------------

  def test_getting_projects
    params = { method: :get, action: :project }

    proj = Project.all.sample
    assert_api_pass(params.merge(id: proj.id))
    assert_api_results([proj])

    projs = Project.where("year(created_at) = 2008")
    assert_not_empty(projs)
    assert_api_pass(params.merge(created_at: "2008"))
    assert_api_results(projs)

    projs = Project.where("year(updated_at) = 2008 and
                           month(updated_at) = 9")
    assert_not_empty(projs)
    assert_api_pass(params.merge(updated_at: "2008-09"))
    assert_api_results(projs)

    projs = Project.where(user: dick)
    assert_not_empty(projs)
    assert_api_pass(params.merge(user: "dick"))
    assert_api_results(projs)

    projs = Project.all.select { |p| p.images.any? }
    assert_not_empty(projs)
    assert_api_pass(params.merge(has_images: "yes"))
    assert_api_results(projs)

    projs = Project.all.select { |p| p.observations.any? }
    assert_not_empty(projs)
    assert_api_pass(params.merge(has_observations: "yes"))
    assert_api_results(projs)

    projs = Project.all.select { |p| p.species_lists.any? }
    assert_not_empty(projs)
    assert_api_pass(params.merge(has_species_lists: "yes"))
    assert_api_results(projs)

    Comment.create!(user: katrina, target: proj, summary: "blah")
    projs = Project.all.select { |p| p.comments.any? }
    assert_not_empty(projs)
    assert_api_pass(params.merge(has_comments: "yes"))
    assert_api_results(projs)

    with    = Project.where("summary is not null and summary != ''")
    without = Project.where("summary is null or summary = ''")
    assert_not_empty(with)
    assert_not_empty(without)
    assert_api_pass(params.merge(has_summary: "yes"))
    assert_api_results(with)
    assert_api_pass(params.merge(has_summary: "no"))
    assert_api_results(without)

    projs = Project.where("title like '%bolete%'")
    assert_not_empty(projs)
    assert_api_pass(params.merge(title_has: "bolete"))
    assert_api_results(projs)

    projs = Project.where("summary like '%article%'")
    assert_not_empty(projs)
    assert_api_pass(params.merge(summary_has: "article"))
    assert_api_results(projs)

    assert_api_pass(params.merge(comments_has: "blah"))
    assert_api_results([proj])
  end

  def test_creating_projects
    @title   = "minimal project"
    @summary = ""
    @admins  = [rolf]
    @members = [rolf]
    @user    = rolf
    params = {
      method:  :post,
      action:  :project,
      api_key: @api_key.key,
      title:   @title
    }
    assert_api_fail(params.remove(:api_key))
    assert_api_fail(params.remove(:title))
    assert_api_pass(params)
    assert_last_project_correct

    @title   = "maximal project"
    @summary = "to do things"
    @admins  = [rolf, mary]
    @members = [rolf, mary, dick]
    params = {
      method:  :post,
      action:  :project,
      api_key: @api_key.key,
      title:   @title,
      summary: @summary,
      admins:  "mary",
      members: "dick"
    }
    assert_api_pass(params)
    assert_last_project_correct
  end

  def test_patching_projects
    proj = projects(:eol_project)
    assert_user_list_equal([rolf, mary], proj.admin_group.users)
    assert_user_list_equal([rolf, mary, katrina], proj.user_group.users)
    assert_empty(proj.images)
    assert_empty(proj.observations)
    assert_empty(proj.species_lists)
    params = {
      method:  :patch,
      action:  :project,
      api_key: @api_key.key,
      id:      proj.id
    }

    assert_api_fail(params)
    assert_api_fail(params.remove(:api_key))
    @api_key.update_attributes!(user: katrina)
    assert_api_fail(params.merge(set_title: "new title"))
    @api_key.update_attributes!(user: rolf)
    assert_api_fail(params.merge(set_title: ""))
    assert_api_pass(params.merge(set_title: "new title"))
    assert_equal("new title", proj.reload.title)
    assert_api_pass(params.merge(set_summary: "new summary"))
    assert_equal("new summary", proj.reload.summary)

    assert_api_pass(params.merge(add_admins: "dick, roy"))
    assert_user_list_equal([rolf, mary, dick, roy],
                           proj.reload.admin_group.users)
    assert_user_list_equal([rolf, mary, katrina],
                           proj.reload.user_group.users)
    assert_api_pass(params.merge(remove_admins: "dick, roy"))
    assert_user_list_equal([rolf, mary],
                           proj.reload.admin_group.users)
    assert_user_list_equal([rolf, mary, katrina],
                           proj.reload.user_group.users)

    assert_api_pass(params.merge(add_members: "dick, roy"))
    assert_user_list_equal([rolf, mary],
                           proj.reload.admin_group.users)
    assert_user_list_equal([rolf, mary, katrina, dick, roy],
                           proj.reload.user_group.users)
    assert_api_pass(params.merge(remove_members: "dick, roy"))
    assert_user_list_equal([rolf, mary],
                           proj.reload.admin_group.users)
    assert_user_list_equal([rolf, mary, katrina],
                           proj.reload.user_group.users)

    imgs = mary.images.first.id
    assert_api_fail(params.merge(add_images: imgs))
    imgs = rolf.images[0..1].map(&:id).map(&:to_s).join(",")
    assert_api_pass(params.merge(add_images: imgs))
    assert_obj_list_equal(rolf.images[0..1], proj.reload.images)
    assert_api_pass(params.merge(remove_images: imgs))
    assert_empty(proj.reload.images)

    obses = mary.observations.first.id
    assert_api_fail(params.merge(add_observations: obses))
    obses = rolf.observations[0..1].map(&:id).map(&:to_s).join(",")
    assert_api_pass(params.merge(add_observations: obses))
    assert_obj_list_equal(rolf.observations[0..1], proj.reload.observations)
    assert_api_pass(params.merge(remove_observations: obses))
    assert_empty(proj.reload.observations)

    spls = mary.species_lists.first.id
    assert_api_fail(params.merge(add_species_lists: spls))
    spls = rolf.species_lists[0..1].map(&:id).map(&:to_s).join(",")
    assert_api_pass(params.merge(add_species_lists: spls))
    assert_obj_list_equal(rolf.species_lists[0..1], proj.reload.species_lists)
    assert_api_pass(params.merge(remove_species_lists: spls))
    assert_empty(proj.reload.species_lists)
  end

  def test_deleting_projects
    proj = projects(:eol_project)
    params = {
      method:  :delete,
      action:  :project,
      api_key: @api_key.key,
      id:      proj.id
    }
    # No DELETE requests should be allowed at all.
    assert_api_fail(params)
  end

  # ------------------------------
  #  :section: Sequence Requests
  # ------------------------------

  def test_getting_sequences
    params = { method: :get, action: :sequence }

    seq = Sequence.all.sample
    assert_api_pass(params.merge(id: seq.id))
    assert_api_results([seq])

    seqs = Sequence.where("date(created_at) = '2017-01-01'")
    assert_not_empty(seqs)
    assert_api_pass(params.merge(created_at: "2017-01-01"))
    assert_api_results(seqs)

    seqs = Sequence.where("year(updated_at) = 2017 and
                           month(updated_at) = 2")
    assert_not_empty(seqs)
    assert_api_pass(params.merge(updated_at: "2017-02"))
    assert_api_results(seqs)

    obs = observations(:locally_sequenced_obs)
    obs.update_attributes!(user: mary)
    obs.sequences.each { |s| s.update_attributes!(user: mary) }
    seqs = Sequence.where(user: mary)
    assert_not_empty(seqs)
    assert_api_pass(params.merge(user: "mary"))
    assert_api_results(seqs)

    seqs = Sequence.where(locus: ["ITS1F", "ITS4", "ITS5"])
    assert_not_empty(seqs)
    assert_api_pass(params.merge(locus: "its1f,its4,its5"))
    assert_api_results(seqs)

    seqs = Sequence.where(archive: ["GenBank", "UNITE"])
    assert_not_empty(seqs)
    assert_api_pass(params.merge(archive: "genbank,unite"))
    assert_api_results(seqs)

    seqs = Sequence.where(accession: "KT968605")
    assert_not_empty(seqs)
    assert_api_pass(params.merge(accession: "KT968605"))
    assert_api_results(seqs)

    seqs = Sequence.where("locus like '%its%'")
    assert_not_empty(seqs)
    assert_api_pass(params.merge(locus_has: "ITS"))
    assert_api_results(seqs)

    seqs = Sequence.where("accession like '%kt%'")
    assert_not_empty(seqs)
    assert_api_pass(params.merge(accession_has: "KT"))
    assert_api_results(seqs)

    seqs = Sequence.where("notes like '%formatted%'")
    assert_not_empty(seqs)
    assert_api_pass(params.merge(notes_has: "formatted"))
    assert_api_results(seqs)

    # Make sure all observations have at least one sequence for the rest.
    Observation.all.each do |obs|
      next if obs.sequences.any?
      Sequence.create!(observation: obs, user: obs.user, locus: "ITS1F",
                       archive: "GenBank", accession: "MO#{obs.id}")
    end

    obses = Observation.where("year(`when`) >= 2012 and year(`when`) <= 2014")
    assert_not_empty(obses)
    assert_api_pass(params.merge(obs_date: "2012-2014"))
    assert_api_results(obses.map(&:sequences).flatten.sort_by(&:id))

    obses = Observation.where(user: dick)
    assert_not_empty(obses)
    assert_api_pass(params.merge(observer: "dick"))
    assert_api_results(obses.map(&:sequences).flatten.sort_by(&:id))

    obses = Observation.where(name: names(:fungi))
    assert_not_empty(obses)
    assert_api_pass(params.merge(name: "Fungi"))
    assert_api_results(obses.map(&:sequences).flatten.sort_by(&:id))

    Observation.create!(user: rolf, when: Time.now, where: locations(:burbank),
                        name: names(:lactarius_alpinus))
    Observation.create!(user: rolf, when: Time.now, where: locations(:burbank),
                        name: names(:lactarius_alpigenes))
    obses = Observation.where(name: names(:lactarius_alpinus).synonyms)
    assert(obses.length > 1)
    assert_api_pass(params.merge(synonyms_of: "Lactarius alpinus"))
    assert_api_results(obses.map(&:sequences).flatten.sort_by(&:id))

    obses = Observation.where(name: Name.where("text_name like 'Agaricus%'"))
    assert(obses.length > 1)
    assert_api_pass(params.merge(children_of: "Agaricus"))
    assert_api_results(obses.map(&:sequences).flatten.sort_by(&:id))

    obses = Observation.where(location: locations(:burbank))
    assert(obses.length > 1)
    assert_api_pass(params.merge(location: 'Burbank\, California\, USA'))
    assert_api_results(obses.map(&:sequences).flatten.sort_by(&:id))

    obses = HerbariumRecord.where(herbarium: herbaria(:nybg_herbarium)).
            map(&:observations).flatten.sort_by(&:id)
    assert(obses.length > 1)
    assert_api_pass(params.merge(herbarium: "The New York Botanical Garden"))
    assert_api_results(obses.map(&:sequences).flatten.sort_by(&:id))

    rec = herbarium_records(:interesting_unknown)
    obses = rec.observations.sort_by(&:id)
    assert(obses.length > 1)
    assert_api_pass(params.merge(herbarium_record: rec.id))
    assert_api_results(obses.map(&:sequences).flatten.sort_by(&:id))

    proj = projects(:one_genus_two_species_project)
    obses = proj.observations.sort_by(&:id)
    assert(obses.length > 1)
    assert_api_pass(params.merge(project: proj.id))
    assert_api_results(obses.map(&:sequences).flatten.sort_by(&:id))

    spl = species_lists(:one_genus_three_species_list)
    obses = spl.observations.sort_by(&:id)
    assert(obses.length > 1)
    assert_api_pass(params.merge(species_list: spl.id))
    assert_api_results(obses.map(&:sequences).flatten.sort_by(&:id))

    obses = Observation.where(vote_cache: 3)
    assert(obses.length > 1)
    assert_api_pass(params.merge(confidence: "3.0"))
    assert_api_results(obses.map(&:sequences).flatten.sort_by(&:id))

    obses = Observation.where("`lat` >= 34 and `lat` <= 35 and
                               `long` >= -119 and `long` <= -118")
    locs  = Location.where("south >= 34 and north <= 35 and west >= -119 and
                            east <= -118 and west <= east")
    obses = (obses + locs.map(&:observations)).flatten.uniq.sort_by(&:id)
    assert_not_empty(obses)
    assert_api_fail(params.merge(south: 34, east: -118, west: -119))
    assert_api_fail(params.merge(north: 35, east: -118, west: -119))
    assert_api_fail(params.merge(north: 35, south: 34, west: -119))
    assert_api_fail(params.merge(north: 35, south: 34, east: -118))
    assert_api_pass(params.merge(north: 35, south: 34, east: -118, west: -119))
    assert_api_results(obses.map(&:sequences).flatten.sort_by(&:id))

    obses = Observation.where(is_collection_location: false)
    assert(obses.length > 1)
    assert_api_pass(params.merge(is_collection_location: "no"))
    assert_api_results(obses.map(&:sequences).flatten.sort_by(&:id))

    with    = Observation.where.not(thumb_image_id: nil)
    without = Observation.where(thumb_image_id: nil)
    assert(with.length > 1)
    assert(without.length > 1)
    assert_api_pass(params.merge(has_images: "yes"))
    assert_api_results(with.map(&:sequences).flatten.sort_by(&:id))
    assert_api_pass(params.merge(has_images: "no"))
    assert_api_results(without.map(&:sequences).flatten.sort_by(&:id))

    genus = Name.ranks[:Genus]
    group = Name.ranks[:Group]
    names = Name.where("rank <= #{genus} or rank = #{group}")
    with    = Observation.where(name: names)
    without = Observation.where.not(name: names)
    assert(with.length > 1)
    assert(without.length > 1)
    assert_api_pass(params.merge(has_name: "yes"))
    assert_api_results(with.map(&:sequences).flatten.sort_by(&:id))
    assert_api_pass(params.merge(has_name: "no"))
    assert_api_results(without.map(&:sequences).flatten.sort_by(&:id))

    with    = Observation.where(specimen: true)
    without = Observation.where(specimen: false)
    assert(with.length > 1)
    assert(without.length > 1)
    assert_api_pass(params.merge(has_specimen: "yes"))
    assert_api_results(with.map(&:sequences).flatten.sort_by(&:id))
    assert_api_pass(params.merge(has_specimen: "no"))
    assert_api_results(without.map(&:sequences).flatten.sort_by(&:id))

    no_notes = Observation.no_notes_persisted
    with    = Observation.where("notes != ?", no_notes)
    without = Observation.where("notes = ?", no_notes)
    assert(with.length > 1)
    assert(without.length > 1)
    assert_api_pass(params.merge(has_obs_notes: "yes"))
    assert_api_results(with.map(&:sequences).flatten.sort_by(&:id))
    assert_api_pass(params.merge(has_obs_notes: "no"))
    assert_api_results(without.map(&:sequences).flatten.sort_by(&:id))

    obses = Observation.where("notes like '%:substrate:%'").
            reject { |o| o.notes[:substrate].blank? }
    assert(obses.length > 1)
    assert_api_pass(params.merge(has_notes_field: "substrate"))
    assert_api_results(obses.map(&:sequences).flatten.sort_by(&:id))

    obses = Observation.where("notes like '%orphan%'")
    assert(obses.length > 1)
    assert_api_pass(params.merge(obs_notes_has: "orphan"))
    assert_api_results(obses.map(&:sequences).flatten.sort_by(&:id))
  end

  def test_creating_sequences
    rolfs_obs  = observations(:coprinus_comatus_obs)
    marys_obs  = observations(:detailed_unknown_obs)
    @obs       = rolfs_obs
    @locus     = "ITS1F"
    @bases     = "gattcgatcgatcgatcatctcgatgcatgactctcgatgcatctac"
    @archive   = "UNITE"
    @accession = "NY123456"
    @notes     = "these are notes"
    @user      = rolf
    params = {
      method:      :post,
      action:      :sequence,
      api_key:     @api_key.key,
      observation: rolfs_obs.id,
      locus:       @locus,
      bases:       @bases,
      archive:     @archive,
      accession:   @accession,
      notes:       @notes
    }
    assert_api_fail(params.remove(:api_key))
    assert_api_fail(params.remove(:observation))
    assert_api_fail(params.remove(:locus))
    assert_api_fail(params.remove(:observation))
    assert_api_fail(params.remove(:archive))
    assert_api_fail(params.remove(:accession))
    assert_api_pass(params.merge(observation: marys_obs.id))
    assert_api_fail(params.merge(archive: "bogus"))
    assert_api_fail(params.merge(bases: "funky stuff!"))
    assert_api_pass(params)
    assert_last_sequence_correct
    assert_api_fail(params)
    @accession += "b"
    @bases     += "b"
    assert_api_fail(params.merge(accession: @accession))
    assert_api_fail(params.merge(bases: @bases))
    assert_api_pass(params.merge(accession: @accession, bases: @bases))
    assert_last_sequence_correct

    @locus     = "MSU1"
    @bases     = "gtctatcagtcgacagcatgcgccactgctaacacg"
    @archive   = nil
    @accession = nil
    @notes     = nil
    params = {
      method:      :post,
      action:      :sequence,
      api_key:     @api_key.key,
      observation: rolfs_obs.id
    }
    assert_api_fail(params)
    assert_api_fail(params.merge(locus: @locus))
    assert_api_pass(params.merge(locus: @locus, bases: @bases))
    assert_last_sequence_correct

    @locus     = "LSU"
    @bases     = nil
    @archive   = "GenBank"
    @accession = "AR09876"
    @notes     = nil
    params = {
      method:      :post,
      action:      :sequence,
      api_key:     @api_key.key,
      observation: rolfs_obs.id
    }
    assert_api_fail(params)
    assert_api_fail(params.merge(locus: @locus))
    assert_api_fail(params.merge(locus: @locus, archive: @archive))
    assert_api_pass(params.merge(locus: @locus, archive: @archive,
                                 accession: @accession))
    assert_last_sequence_correct
  end

  def test_patching_sequences
    seq        = sequences(:alternate_archive)
    @user      = dick
    @obs       = seq.observation
    @locus     = "NEWITS"
    @bases     = "gtac"
    @archive   = "GenBank"
    @accession = "XX123456"
    @notes     = "new notes"
    params = {
      method:        :patch,
      action:        :sequence,
      api_key:       @api_key.key,
      id:            seq.id,
      set_locus:     @locus,
      set_bases:     @bases,
      set_archive:   @archive,
      set_accession: @accession,
      set_notes:     @notes
    }
    assert_api_fail(params)
    @api_key.update_attributes!(user: dick)
    assert_api_fail(params.merge(set_locus: ""))
    assert_api_fail(params.merge(set_archive: "bogus"))
    assert_api_fail(params.merge(set_archive: ""))
    assert_api_fail(params.merge(set_accession: ""))
    assert_api_pass(params)
    assert_last_sequence_correct(seq.reload)
  end

  def test_deleting_sequences
    seq = dick.sequences.sample
    params = {
      method:  :delete,
      action:  :sequence,
      api_key: @api_key.key,
      id:      seq.id
    }
    assert_api_fail(params)
    assert_not_nil(Sequence.safe_find(seq.id))
    @api_key.update_attributes!(user: dick)
    assert_api_pass(params)
    assert_nil(Sequence.safe_find(seq.id))
  end

  # ---------------------------------
  #  :section: SpeciesList Requests
  # ---------------------------------

  def test_getting_species_lists
    params = { method: :get, action: :species_list }

    spl = SpeciesList.all.sample
    assert_api_pass(params.merge(id: spl.id))
    assert_api_results([spl])

    spls = SpeciesList.where("date(created_at) = '2012-07-06'")
    assert_not_empty(spls)
    assert_api_pass(params.merge(created_at: "2012-07-06"))
    assert_api_results(spls)

    spls = SpeciesList.where("year(updated_at) = 2008")
    assert_not_empty(spls)
    assert_api_pass(params.merge(updated_at: "2008"))
    assert_api_results(spls)

    spls = SpeciesList.where(user: rolf)
    assert_not_empty(spls)
    assert_api_pass(params.merge(user: "rolf"))
    assert_api_results(spls)

    spls = SpeciesList.where("`when` >= '2006-03-01' and
                              `when` <= '2006-03-02'")
    assert_not_empty(spls)
    assert_api_pass(params.merge(date: "2006-03-01-2006-03-02"))
    assert_api_results(spls)

    obses = Observation.where(name: names(:fungi))
    spls = obses.map(&:species_lists).flatten.uniq.sort_by(&:id)
    assert_not_empty(spls)
    assert_api_pass(params.merge(name: "Fungi"))
    assert_api_results(spls)

    obs1 = Observation.create!(user: rolf, when: Time.now,
                               where: locations(:burbank),
                               name: names(:lactarius_alpinus))
    obs2 = Observation.create!(user: rolf, when: Time.now,
                               where: locations(:burbank),
                               name: names(:lactarius_alpigenes))
    obs1.species_lists << species_lists(:first_species_list)
    obs2.species_lists << species_lists(:first_species_list)
    obs2.species_lists << species_lists(:another_species_list)
    obses = Observation.where(name: names(:lactarius_alpinus).synonyms)
    spls = obses.map(&:species_lists).flatten.uniq.sort_by(&:id)
    assert(spls.length > 1)
    assert_api_pass(params.merge(synonyms_of: "Lactarius alpinus"))
    assert_api_results(spls)

    obses = Observation.where(name: Name.where("text_name like 'Agaricus%'"))
    spls = obses.map(&:species_lists).flatten.uniq.sort_by(&:id)
    assert_not_empty(spls)
    assert_api_pass(params.merge(children_of: "Agaricus"))
    assert_api_results(spls)

    spls = SpeciesList.where(location: locations(:no_mushrooms_location))
    assert_not_empty(spls)
    assert_api_pass(params.merge(location: 'No Mushrooms'))
    assert_api_results(spls)

    proj1 = projects(:bolete_project)
    proj2 = projects(:two_list_project)
    spls = [proj1, proj2].map(&:species_lists).flatten.uniq.sort_by(&:id)
    assert_not_empty(spls)
    assert_api_pass(params.merge(project: "#{proj1.id}, #{proj2.id}"))
    assert_api_results(spls)

    with    = SpeciesList.where("COALESCE(notes,'') != ''")
    without = SpeciesList.where("COALESCE(notes,'') = ''")
    assert(with.length > 1)
    assert(without.length > 1)
    assert_api_pass(params.merge(has_notes: "yes"))
    assert_api_results(with)
    assert_api_pass(params.merge(has_notes: "no"))
    assert_api_results(without)

    Comment.create!(user: dick, target: spl, summary: "test",
                    comment: "double dare you to reiterate this comment!")
    assert_api_pass(params.merge(has_comments: "yes"))
    assert_api_results([spl])

    spls = SpeciesList.where("title like '%mysteries%'")
    assert_not_empty(spls)
    assert_api_pass(params.merge(title_has: "mysteries"))
    assert_api_results(spls)

    spls = SpeciesList.where("notes like '%skunk%'")
    assert_not_empty(spls)
    assert_api_pass(params.merge(notes_has: "skunk"))
    assert_api_results(spls)

    assert_api_pass(params.merge(comments_has: "double dare"))
    assert_api_results([spl])
  end

  def test_creating_species_lists
    @user     = rolf
    @title    = "Maximal New Species List"
    @date     = Date.parse("2017-11-17")
    @location = locations(:burbank)
    @where    = locations(:burbank).name
    @notes    = "some notes"
    params = {
      method:   :post,
      action:   :species_list,
      api_key:  @api_key.key,
      title:    @title,
      date:     "2017-11-17",
      location: @location.id,
      notes:    @notes
    }
    assert_api_fail(params.remove(:api_key))
    assert_api_fail(params.remove(:title))
    assert_api_fail(params.merge(title: SpeciesList.first.title))
    assert_api_fail(params.merge(location: "bogus location"))
    assert_api_pass(params)
    assert_last_species_list_correct

    @title    = "Minimal New Species List"
    @date     = Date.today
    @location = Location.unknown
    @where    = Location.unknown.name
    @notes    = nil
    params = {
      method:   :post,
      action:   :species_list,
      api_key:  @api_key.key,
      title:    @title
    }
    assert_api_pass(params)
    assert_last_species_list_correct

    @title    = "New Species List with Undefined Location"
    @date     = Date.today
    @location = nil
    @where    = "Bogus, Arkansas, USA"
    @notes    = nil
    params = {
      method:   :post,
      action:   :species_list,
      api_key:  @api_key.key,
      title:    @title,
      location: @where
    }
    assert_api_pass(params)
    assert_last_species_list_correct
  end

  def test_patching_species_lists
    rolfs_spl = species_lists(:first_species_list)
    marys_spl = species_lists(:unknown_species_list)
    assert(!marys_spl.can_edit?(rolf))
    @user     = rolf
    @title    = "New Title"
    @date     = Date.parse("2017-11-17")
    @location = locations(:mitrula_marsh)
    @where    = locations(:mitrula_marsh).name
    @notes    = "new notes"
    params = {
      method:       :patch,
      action:       :species_list,
      api_key:      @api_key.key,
      id:           rolfs_spl.id,
      set_title:    @title,
      set_date:     "2017-11-17",
      set_location: @location.display_name,
      set_notes:    @notes
    }
    assert_api_fail(params.remove(:api_key))
    assert_api_fail(params.merge(id: marys_spl.id))
    assert_api_fail(params.merge(set_title: SpeciesList.first.title))
    assert_api_fail(params.merge(set_location: "bogus location"))
    assert_api_fail(params.merge(set_title: ""))
    assert_api_fail(params.merge(set_date: ""))
    assert_api_fail(params.merge(set_location: ""))
    assert_api_pass(params)
    assert_last_species_list_correct(rolfs_spl.reload)
  end

  def test_deleting_species_lists
    rolfs_spl = rolf.species_lists.sample
    marys_spl = mary.species_lists.sample
    params = {
      method:  :delete,
      action:  :species_list,
      api_key: @api_key.key
    }
    assert_api_fail(params.merge(id: marys_spl.id))
    assert_api_pass(params.merge(id: rolfs_spl.id))
    assert_not_nil(SpeciesList.safe_find(marys_spl.id))
    assert_nil(SpeciesList.safe_find(rolfs_spl.id))
  end

  # --------------------------
  #  :section: User Requests
  # --------------------------

  def test_getting_users
    params = { method: :get, action: :user }
    user = User.all.sample
    assert_api_pass(params.merge(id: user.id))
    assert_api_results([user])
  end

  def test_posting_minimal_user
    @login = "stephane"
    @name = ""
    @email = "stephane@grappelli.com"
    @locale = "en"
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
    @locale = "el"
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
    assert_api_fail(params.merge(locale: "xx"))
    assert_api_fail(params.merge(license: "123456"))
    assert_api_fail(params.merge(location: "123456"))
    assert_api_fail(params.merge(image: "123456"))
  end

  def test_patching_users
    params = {
      method:              :patch,
      action:              :user,
      api_key:             @api_key.key,
      id:                  rolf.id,
      set_locale:          "pt",
      set_notes:           "some notes",
      set_mailing_address: "somewhere, USA",
      set_license:         licenses(:publicdomain).id,
      set_location:        locations(:burbank).id,
      set_image:           images(:peltigera_image).id
    }
    assert_api_fail(params.remove(:api_key))
    assert_api_fail(params.merge(set_image: mary.images.first.id))
    assert_api_fail(params.merge(set_locale: ""))
    assert_api_fail(params.merge(set_license: ""))
    assert_api_pass(params)
    rolf.reload
    assert_equal("pt", rolf.locale)
    assert_equal("some notes", rolf.notes)
    assert_equal("somewhere, USA", rolf.mailing_address)
    assert_objs_equal(licenses(:publicdomain), rolf.license)
    assert_objs_equal(locations(:burbank), rolf.location)
    assert_objs_equal(images(:peltigera_image), rolf.image)
  end

  def test_deleting_users
    params = {
      method:  :delete,
      action:  :user,
      api_key: @api_key.key,
      id:      rolf.id
    }
    # No DELETE requests should be allowed at all.
    assert_api_fail(params)
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
    assert_parse(:time, api_test_time("2012-06-25 12:34:56"), nil,
                 default: api_test_time("2012-06-25 12:34:56"))
    assert_parse(:time, api_test_time("2012-06-25 12:34:56"),
                 "20120625123456")
    assert_parse(:time, api_test_time("2012-06-25 12:34:56"),
                 "2012-06-25 12:34:56")
    assert_parse(:time, api_test_time("2012-06-25 12:34:56"),
                 "2012/06/25 12:34:56")
    assert_parse(:time, api_test_time("2012-06-05 02:04:06"),
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

  # rubocop:disable Metrics/LineLength
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
  # rubocop:enable Metrics/LineLength

  def assert_parse_tr(from, to, str)
    from = api_test_time(from)
    to   = api_test_time(to)
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

  # --------------------------
  #  :section: Help Messages
  # --------------------------

  def test_api_key_help
    file = help_messages_file
    File.open(file, "w") { |fh| fh.truncate(0) }

    do_help_test(:get, :api_key, :fail)
    do_help_test(:post, :api_key)
    do_help_test(:patch, :api_key, :fail)
    do_help_test(:delete, :api_key, :fail)

    do_help_test(:get, :comment)
    do_help_test(:post, :comment)
    do_help_test(:patch, :comment)
    do_help_test(:delete, :comment)

    do_help_test(:get, :external_link)
    do_help_test(:post, :external_link)
    do_help_test(:patch, :external_link)
    do_help_test(:delete, :external_link)

    do_help_test(:get, :external_site)
    do_help_test(:post, :external_site, :fail)
    do_help_test(:patch, :external_site, :fail)
    do_help_test(:delete, :external_site, :fail)

    do_help_test(:get, :herbarium)
    do_help_test(:post, :herbarium, :fail)
    do_help_test(:patch, :herbarium, :fail)
    do_help_test(:delete, :herbarium, :fail)

    do_help_test(:get, :image)
    do_help_test(:post, :image)
    do_help_test(:patch, :image)
    do_help_test(:delete, :image)

    do_help_test(:get, :location)
    do_help_test(:post, :location)
    do_help_test(:patch, :location)
    do_help_test(:delete, :location, :fail)

    do_help_test(:get, :name)
    do_help_test(:post, :name)
    do_help_test(:patch, :name)
    do_help_test(:delete, :name, :fail)

    do_help_test(:get, :observation)
    do_help_test(:post, :observation)
    do_help_test(:patch, :observation)
    do_help_test(:delete, :observation)

    do_help_test(:get, :project)
    do_help_test(:post, :project)
    do_help_test(:patch, :project)
    do_help_test(:delete, :project, :fail)

    do_help_test(:get, :sequence)
    do_help_test(:post, :sequence)
    do_help_test(:patch, :sequence)
    do_help_test(:delete, :sequence)

    do_help_test(:get, :species_list)
    do_help_test(:post, :species_list)
    do_help_test(:patch, :species_list)
    do_help_test(:delete, :species_list)

    do_help_test(:get, :user)
    do_help_test(:post, :user)
    do_help_test(:patch, :user)
    do_help_test(:delete, :user, :fail)
  end

  def help_messages_file
    "#{Rails.root}/README_API_HELP_MESSAGES.txt"
  end

  def do_help_test(method, action, fail = false)
    params = {
      method: method,
      action: action,
      help: :me
    }
    params[:api_key] = @api_key.key if method != :get
    api = API.execute(params)
    others = api.errors.reject { |e| e.class.name == "API::HelpMessage" }
    assert_equal(1, api.errors.length, others.map(&:to_s))
    if fail
      assert_equal("API::NoMethodForAction", api.errors.first.class.name)
    else
      assert_equal("API::HelpMessage", api.errors.first.class.name)
      file = help_messages_file
      return unless File.exists?(file)
      File.open(file, "a") do |fh|
        fh.puts "#{method.to_s.upcase} #{action}"
        fh.puts api.errors.first.to_s.gsub(/; /, "\n  ").
          sub(/^Usage: /, "  ").
          sub(/^  query params: */, " query params\n  ").
          sub(/^  update params: */, " update params\n  ").
          gsub(/^(  [^:]*:) */, "\\1\t")
        fh.puts
      end
    end
  end
end
