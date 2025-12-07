# frozen_string_literal: true

require("test_helper")

# helpers for API2Test and subclass tests
module API2Extensions
  def setup
    @api_key = api_keys(:rolfs_api_key)
    super
  end

  # --------------------
  #  :section: Helpers
  # --------------------

  def aor(*)
    API2::OrderedRange.new(*)
  end

  def date(str)
    Date.parse(str)
  end

  # This method renamed from "time"
  # minitest 5.11.1 throws ArgumentError with "time".
  def api_test_time(str)
    DateTime.parse("#{str} UTC")
  end

  def assert_no_errors(api, msg = "API2 errors")
    msg = "#{msg}: <\n#{api.errors.map(&:to_s).join("\n")}\n>"
    assert(api.errors.empty?, msg)
  end

  def assert_api_fail(params)
    @api = API2.execute(params)
    msg = "API2 request should have failed, params: #{params.inspect}"
    assert(@api.errors.any?, msg)
  end

  def assert_api_pass(params)
    @api = API2.execute(params)
    msg = "API2 request should have passed, params: #{params.inspect}"
    assert_no_errors(@api, msg)
  end

  def assert_api_results(expect)
    msg = "API2 results wrong.\nQuery args: #{@api.query.params.inspect}\n" \
          "Query sql: #{@api.query.sql}"
    assert_obj_arrays_equal(expect, @api.results, :sort, msg)
  end

  def assert_parse(*)
    assert_parse_general(:parse, *)
  end

  def assert_parse_a(*)
    assert_parse_general(:parse_array, *)
  end

  def assert_parse_r(*)
    assert_parse_general(:parse_range, *)
  end

  def assert_parse_rs(*)
    assert_parse_general(:parse_ranges, *)
  end

  def assert_parse_general(method, type, expect, val, *)
    @api ||= API2.new
    val = val.to_s if val
    begin
      actual = @api.send(method, type, val, *)
    rescue API2::Error => e
      actual = e
    end
    msg = "Expected: <#{show_val(expect)}>\n" \
          "Got: <#{show_val(actual)}>\n"
    if expect.is_a?(Class) && expect <= API2::Error
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
      "[#{val.map { |v| show_val(v) }.join(", ")}]"
    when Hash
      "{#{val.map { |k, v| "#{show_val(k)}: #{show_val(v)}" }.join(", ")}}"
    else
      "#{val.class}: #{val}"
    end
  end

  def assert_last_api_key_correct
    api_key = APIKey.last
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
    assert_obj_arrays_equal([@obs], num.observations)
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
    assert_obj_arrays_equal([@obs], rec.observations)
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
    assert_equal_even_if_nil(@vote, img.vote_cache)
    assert_equal(true, img.ok_for_export)
    assert_equal_even_if_nil(@orig, img.original_name)
    assert_equal(false, img.transferred)
    assert_obj_arrays_equal([@proj].compact, img.projects)
    assert_obj_arrays_equal([@obs].compact, img.observations)
    assert_equal_even_if_nil(@vote, img.users_vote(@user))
  end

  def assert_last_location_correct
    loc = Location.last
    assert_in_delta(Time.zone.now, loc.created_at, 1.minute)
    assert_in_delta(Time.zone.now, loc.updated_at, 1.minute)
    assert_users_equal(@user, loc.user)
    assert_equal(@name, loc.display_name)
    assert_in_delta(@north, loc.north, MO.box_epsilon)
    assert_in_delta(@south, loc.south, MO.box_epsilon)
    assert_in_delta(@east, loc.east, MO.box_epsilon)
    assert_in_delta(@west, loc.west, MO.box_epsilon)
    assert_in_delta(@high, loc.high, MO.box_epsilon) if @high
    assert_nil(loc.high) unless @high
    assert_in_delta(@low, loc.low, MO.box_epsilon) if @low
    assert_nil(loc.low) unless @low
    assert_equal(@notes, loc.notes) if @notes
    assert_nil(loc.notes) unless @notes
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
    assert_last_reasons_correct(naming) if @reasons
  end

  def assert_last_reasons_correct(naming)
    naming.reasons_array.each do |reason|
      expect = @reasons[reason.num]
      if expect.nil?
        assert_false(reason.used?)
      else
        assert_true(reason.used?)
        assert_equal(expect.to_s, reason.notes.to_s)
      end
    end
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
    assert_obj_arrays_equal([@img1, @img2].compact,
                            obs.images.reorder(id: :asc))
    assert_equal(@loc.name, obs.where)
    assert_objs_equal(@loc, obs.location)
    assert_equal(@loc.name, obs.place_name)
    assert_equal(@is_col_loc, obs.is_collection_location)
    assert_equal(0, obs.num_views)
    assert_nil(obs.last_view)
    assert_not_nil(obs.rss_log)
    assert(@lat == obs.lat)
    assert(@long == obs.lng)
    assert(@alt == obs.alt)
    assert_obj_arrays_equal([@proj].compact,
                            obs.projects.reorder(id: :asc))
    assert_obj_arrays_equal([@spl].compact,
                            obs.species_lists.reorder(id: :asc))
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
    assert_user_arrays_equal(@admins, proj.admin_group.users)
    assert_user_arrays_equal(@members, proj.user_group.users)
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

  # Used to be we could just used assert_equal, but now it complains that that
  # assertion will soon no longer work if expect is nil.  We can change it to
  # just assert(expect == actual), but that doesn't show as nice diagnostics
  # when it fails.  So I'm restoring the old behavior of assert_equal here.
  # This should probably move into a more general set of extensions, but for
  # now this is the only place it is used.  -JPH 20220519
  def assert_equal_even_if_nil(expect, actual)
    if expect.nil?
      assert_nil(actual)
    else
      assert_equal(expect, actual)
    end
  end

  def do_basic_get_test(model, *args)
    expected_object = args.empty? ? model.first : model.where(*args).first
    api = API2.execute(
      method: :get,
      action: model.type_tag,
      id: expected_object.id
    )
    assert_no_errors(api, "Errors while getting first #{model}")
    assert_obj_arrays_equal([expected_object], api.results,
                            "Failed to get first #{model}")
  end
end
