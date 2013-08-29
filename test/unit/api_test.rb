# encoding: utf-8

require File.expand_path(File.dirname(__FILE__) + '/../boot.rb')

class Hash
  def remove(*keys)
    reject do |key, val|
      keys.include?(key)
    end
  end
end

class ApiTest < UnitTestCase
  def setup
    @api_key = api_keys(:rolfs_api_key)
  end

  def assert_no_errors(api, msg='API errors')
    clean_our_backtrace do
      assert_block("#{msg}: <\n" + api.errors.map(&:to_s).join("\n") + "\n>") do
        api.errors.empty?
      end
    end
  end

  def assert_api_fail(params)
    clean_our_backtrace do
      assert_block("API request should have failed, params: #{params.inspect}") do
        API.execute(params).errors.any?
      end
    end
  end

  def assert_api_pass(params)
    clean_our_backtrace do
      api = API.execute(params)
      assert_no_errors(api, "API request should have passed, params: #{params.inspect}")
    end
  end

  def assert_parse(method, expect, val, *args)
    @api ||= API.new
    clean_our_backtrace do
      val = val.to_s if val
      begin
        actual = @api.send(method, val, *args)
      rescue API::Error => e
        actual = e
      end
      msg = "Expected: <#{show_val(expect)}>\n" +
            "Got: <#{show_val(actual)}>\n"
      assert_block(msg) do
        if expect.is_a?(Class) and expect <= API::Error
          actual.is_a?(expect)
        else
          actual == expect
        end
      end
    end
  end

  def show_val(val)
    case val
    when NilClass, TrueClass, FalseClass, String, Symbol, Fixnum, Float
      val.inspect
    when Array
      '[' + val.map {|v| show_val(v)}.join(', ') + ']'
    when Hash
      '{' + val.map {|k,v| show_val(k) + ': ' + show_val(v)}.join(', ') + '}'
    else
      "#{val.class}: #{val}"
    end
  end

  def assert_last_observation_correct
    obs = Observation.last
    assert_in_delta(Time.now, obs.created_at, 1.minute)
    assert_in_delta(Time.now, obs.updated_at, 1.minute)
    assert_equal(@date.web_date, obs.when.web_date)
    assert_users_equal(@user, obs.user)
    assert_equal(@specimen, obs.specimen)
    assert_equal(@notes.strip, obs.notes)
    assert_objs_equal(@img2, obs.thumb_image)
    assert_obj_list_equal([@img1, @img2].reject(&:nil?), obs.images)
    assert_objs_equal(@loc, obs.location)
    assert_nil(obs.where)
    assert_equal(@loc.name, obs.place_name)
    assert_equal(@is_col_loc, obs.is_collection_location)
    assert_equal(0, obs.num_views)
    assert_nil(obs.last_view)
    assert_not_nil(obs.rss_log)
    assert_equal(@lat, obs.lat)
    assert_equal(@long, obs.long)
    assert_equal(@alt, obs.alt)
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

  def assert_last_naming_correct
    obs = Observation.last
    naming = Naming.last
    vote = Vote.last
    assert_names_equal(@name, naming.name)
    assert_objs_equal(obs, naming.observation)
    assert_users_equal(@user, naming.user)
    assert_in_delta(@vote, naming.vote_cache, 1) # vote_cache is weird
    assert_in_delta(Time.now, naming.created_at, 1.minute)
    assert_in_delta(Time.now, naming.updated_at, 1.minute)
    assert_equal(1, naming.votes.length)
    assert_objs_equal(vote, naming.votes.first)
  end

  def assert_last_vote_correct
    obs = Observation.last
    naming = Naming.last
    vote = Vote.last
    assert_objs_equal(naming, vote.naming)
    assert_objs_equal(obs, vote.observation)
    assert_users_equal(@user, vote.user)
    assert_equal(@vote, vote.value)
    assert_in_delta(Time.now, vote.created_at, 1.minute)
    assert_in_delta(Time.now, vote.updated_at, 1.minute)
    assert_true(vote.favorite)
  end

  def assert_last_image_correct
    img = Image.last
    assert_users_equal(@user, img.user)
    assert_in_delta(Time.now, img.created_at, 1.minute)
    assert_in_delta(Time.now, img.updated_at, 1.minute)
    assert_equal('image/jpeg', img.content_type)
    assert_equal(@date, img.when)
    assert_equal(@notes.strip, img.notes)
    assert_equal(@copy.strip, img.copyright_holder)
    assert_equal(@user.license, img.license)
    assert_equal(0, img.num_views)
    assert_equal(nil, img.last_view)
    assert_equal(@width, img.width)
    assert_equal(@height, img.height)
    assert_equal(@vote, img.vote_cache)
    assert_equal(true, img.ok_for_export)
    assert_equal(@orig, img.original_name)
    assert_equal(false, img.transferred)
    assert_obj_list_equal([@proj].reject(&:nil?), img.projects)
    assert_obj_list_equal([@obs].reject(&:nil?), img.observations)
    assert_equal(@vote, img.users_vote(@user))
  end

  def assert_last_user_correct
    user = User.last
    assert_equal(@login, user.login)
    assert_equal(@name, user.name)
    assert_equal(@email, user.email)
    assert_equal('', user.password)
    assert_in_delta(Time.now, user.created_at, 1.minute)
    assert_in_delta(Time.now, user.updated_at, 1.minute)
    assert_equal(nil, user.verified)
    assert_equal(nil, user.last_activity)
    assert_equal(nil, user.last_login)
    assert_equal(true, user.created_here)
    assert_equal(false, user.admin)
    assert_equal(0, user.contribution)
    assert_equal(nil, user.bonuses)
    assert_equal(nil, user.alert)
    assert_equal(@locale, user.locale)
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

  def assert_last_api_key_correct
    api_key = ApiKey.last
    assert_in_delta(Time.now, api_key.created_at, 1.minute)
    if @verified
      assert_in_delta(Time.now, api_key.verified, 1.minute)
    else
      assert_nil(api_key.verified)
    end
    assert_equal(nil, api_key.last_used)
    assert_equal(0, api_key.num_uses)
    assert_equal(@app.strip_squeeze, api_key.notes)
    assert_users_equal(@for_user, api_key.user)
  end

################################################################################

  def test_basic_gets
    for model in [ Comment, Image, Location, Name, Observation, Project,
                   SpeciesList, User ]
      expected_object = model.find(1)
      api = API.execute(:method => :get, :action => model.type_tag, :id => 1)
      assert_no_errors(api, "Errors while getting #{model} #1")
      assert_obj_list_equal([expected_object], api.results, "Failed to get first #{model}")
    end
  end

  def test_post_minimal_observation
    @user = @rolf
    @name = Name.unknown
    @loc = locations(:unknown_location)
    @img1 = nil
    @img2 = nil
    @spl = nil
    @proj = nil
    @date = Date.today
    @notes = ''
    @vote = Vote.maximum_vote
    @specimen = false
    @is_col_loc = true
    @lat = nil
    @long = nil
    @alt = nil
    params = {
      :method   => :post,
      :action   => :observation,
      :api_key  => @api_key.key,
      :location => 'Anywhere',
    }
    api = API.execute(params)
    assert_no_errors(api, 'Errors while posting observation')
    assert_obj_list_equal([Observation.last], api.results)
    assert_last_observation_correct
    assert_api_fail(params.remove(:location))
  end

  def test_post_maximal_observation
    @user = @rolf
    @name = names(:coprinus_comatus)
    @loc = locations(:albion)
    @img1 = Image.find(1)
    @img2 = Image.find(2)
    @spl = species_lists(:first_species_list)
    @proj = projects(:eol_project)
    @date = Date.parse('20120626')
    @notes = "These are notes.\nThey look like this.\n"
    @vote = 2.0
    @specimen = true
    @is_col_loc = true
    @lat = 39.229
    @long = -123.77
    @alt = 50
    params = {
      :method        => :post,
      :action        => :observation,
      :api_key       => @api_key.key,
      :date          => '20120626',
      :notes         => @notes,
      :location      => 'USA, California, Albion',
      :latitude      => '39.229°N',
      :longitude     => '123.770°W',
      :altitude      => '50m',
      :has_specimen  => 'yes',
      :name          => 'Coprinus comatus',
      :vote          => '2',
      :projects      => @proj.id,
      :species_lists => @spl.id,
      :thumbnail     => @img2.id,
      :images        => "#{@img1.id},#{@img2.id}",
    }
    api = API.execute(params)
    assert_no_errors(api, 'Errors while posting observation')
    assert_obj_list_equal([Observation.last], api.results)
    assert_last_observation_correct
    assert_last_naming_correct
    assert_last_vote_correct
    assert_api_fail(params.remove(:api_key))
    assert_api_fail(params.merge(:api_key => 'this should fail'))
    assert_api_fail(params.merge(:date => 'yesterday'))
    assert_api_pass(params.merge(:location => 'This is a bogus location')) # ???
    assert_api_pass(params.merge(:location => 'New Place, Oregon, USA')) # ???
    assert_api_fail(params.remove(:latitude)) # need to supply both or neither
    assert_api_fail(params.merge(:longitude => 'bogus'))
    assert_api_fail(params.merge(:altitude => 'bogus'))
    assert_api_fail(params.merge(:has_specimen => 'bogus'))
    assert_api_fail(params.merge(:name => 'Unknown name'))
    assert_api_fail(params.merge(:vote => 'take that'))
    assert_api_fail(params.merge(:extra => 'argument'))
    assert_api_fail(params.merge(:thumbnail => '1234567'))
    assert_api_fail(params.merge(:images => '1234567'))
    assert_api_fail(params.merge(:projects => '1234567'))
    assert_api_fail(params.merge(:projects => 2)) # Rolf is not a member of this project
    assert_api_fail(params.merge(:species_lists => '1234567'))
    assert_api_fail(params.merge(:species_lists => 3)) # owned by Mary
  end

  def test_post_observation_with_no_log
    params = {
      :method   => :post,
      :action   => :observation,
      :api_key  => @api_key.key,
      :location => 'Anywhere',
      :name     => 'Agaricus campestris',
      :log      => 'no',
    }
    api = API.execute(params)
    assert_no_errors(api, 'Errors while posting observation')
    obs = Observation.last
    assert_nil(obs.rss_log_id)
  end

  def test_post_observation_scientific_location
    params = {
      :method   => :post,
      :action   => :observation,
      :api_key  => @api_key.key,
    }

    assert_equal(:postal, @rolf.location_format)

    params[:location] = 'New Place, California, USA'
    api = API.execute(params)
    assert_no_errors(api, 'Errors while posting observation')
    obs = Observation.last
    assert_nil(obs.location_id)
    assert_equal('New Place, California, USA', obs.where)

    params[:location] = 'Burbank, California, USA'
    api = API.execute(params)
    assert_no_errors(api, 'Errors while posting observation')
    obs = Observation.last
    assert_nil(obs.where)
    assert_objs_equal(locations(:burbank), obs.location)

    @rolf.update_attribute(:location_format, :scientific)
    assert_equal(:scientific, @rolf.reload.location_format)

    params[:location] = 'USA, California, Somewhere Else'
    api = API.execute(params)
    assert_no_errors(api, 'Errors while posting observation')
    obs = Observation.last
    assert_nil(obs.location_id)
    assert_equal('Somewhere Else, California, USA', obs.where)

    params[:location] = 'Burbank, California, USA'
    api = API.execute(params)
    assert_no_errors(api, 'Errors while posting observation')
    obs = Observation.last
    assert_nil(obs.where)
    assert_objs_equal(locations(:burbank), obs.location)
  end

  def test_posting_minimal_image
    setup_image_dirs
    @user = @rolf
    @proj = nil
    @date = Date.today
    @copy = @user.legal_name
    @notes = ''
    @orig = nil
    @width = 407
    @height = 500
    @vote = nil
    @obs = nil
    params = {
      :method      => :post,
      :action      => :image,
      :api_key     => @api_key.key,
      :upload_file => "#{RAILS_ROOT}/test/fixtures/images/sticky.jpg",
    }
    api = API.execute(params)
    assert_no_errors(api, 'Errors while posting image')
    assert_obj_list_equal([Image.last], api.results)
    assert_last_image_correct
  end

  def test_posting_maximal_image
    setup_image_dirs
    @user = @rolf
    @proj = projects(:eol_project)
    @date = Date.parse('20120626')
    @copy = 'My Friend'
    @notes = "These are notes.\nThey look like this.\n"
    @orig = 'sticky.png'
    @width = 407
    @height = 500
    @vote = 3
    @obs = @user.observations.last
    params = {
      :method        => :post,
      :action        => :image,
      :api_key       => @api_key.key,
      :date          => '20120626',
      :notes         => @notes,
      :copyright_holder => ' My Friend ',
      :license       => @user.license.id,
      :vote          => '3',
      :observations  => @obs.id,
      :projects      => @proj.id,
      :upload_file   => "#{RAILS_ROOT}/test/fixtures/images/sticky.jpg",
      :original_name => @orig,
    }
    api = API.execute(params)
    assert_no_errors(api, 'Errors while posting image')
    assert_obj_list_equal([Image.last], api.results)
    assert_last_image_correct
    assert_api_fail(params.remove(:api_key))
    assert_api_fail(params.remove(:upload_file))
    assert_api_fail(params.merge(:original_name => 'x'*1000))
    assert_api_fail(params.merge(:vote => '-5'))
    assert_api_fail(params.merge(:observations => '11')) # Katrina owns this observation
    assert_api_fail(params.merge(:projects => '2')) # Rolf is not a member of this project
  end

  def test_posting_minimal_user
    @login = 'stephane'
    @name = ''
    @email = 'stephane@grappelli.com'
    @locale = 'en-US'
    @notes = ''
    @license = License.preferred
    @location = nil
    @image = nil
    @address = ''
    @new_key = nil
    params = {
      :method  => :post,
      :action  => :user,
      :api_key => @api_key.key,
      :login   => @login,
      :email   => @email,
    }
    api = API.execute(params)
    assert_no_errors(api, 'Errors while posting image')
    assert_obj_list_equal([User.last], api.results)
    assert_last_user_correct
    assert_api_fail(params)
    params.merge!(:login => 'miles')
    assert_api_fail(params.remove(:api_key))
    assert_api_fail(params.remove(:login))
    assert_api_fail(params.remove(:email))
    assert_api_fail(params.merge(:login => 'x'*1000))
    assert_api_fail(params.merge(:email => 'x'*1000))
    assert_api_fail(params.merge(:email => 'bogus address @ somewhere dot com'))
  end

  def test_posting_maximal_user
    @login = 'stephane'
    @name = 'Stephane Grappelli'
    @email = 'stephane@grappelli.com'
    @locale = 'el-GR'
    @notes = " Here are some notes\nThey look like this!\n "
    @license = (License.find_all_by_deprecated(false) - [License.preferred]).first
    @location = Location.last
    @image = Image.last
    @address = ' I live here '
    @new_key = '  Blah  Blah  Blah  '
    params = {
      :method   => :post,
      :action   => :user,
      :api_key  => @api_key.key,
      :login    => @login,
      :name     => @name,
      :email    => @email,
      :locale   => @locale,
      :notes    => @notes,
      :license  => @license.id,
      :location => @location.id,
      :image    => @image.id,
      :mailing_address  => @address,
      :create_key => @new_key,
    }
    api = API.execute(params)
    assert_no_errors(api, 'Errors while posting image')
    assert_obj_list_equal([User.last], api.results)
    assert_last_user_correct
    params.merge!(:login => 'miles')
    assert_api_fail(params.merge(:name => 'x'*1000))
    assert_api_fail(params.merge(:locale => 'xx-XX'))
    assert_api_fail(params.merge(:license => '123456'))
    assert_api_fail(params.merge(:location => '123456'))
    assert_api_fail(params.merge(:image => '123456'))
  end

  def test_posting_api_key_for_yourself
    email_count = ActionMailer::Base.deliveries.size
    @for_user = @rolf
    @app = '  Mushroom  Mapper  '
    @verified = true
    params = {
      :method  => :post,
      :action  => :api_key,
      :api_key => @api_key.key,
      :app     => @app,
    }
    api = API.execute(params)
    assert_no_errors(api, 'Errors while posting image')
    assert_obj_list_equal([ApiKey.last], api.results)
    assert_last_api_key_correct
    assert_api_fail(params.remove(:api_key))
    assert_api_fail(params.remove(:app))
    assert_equal(email_count, ActionMailer::Base.deliveries.size)
  end

  def test_posting_api_key_for_another_user
    email_count = ActionMailer::Base.deliveries.size
    @for_user = @katrina
    @app = '  Mushroom  Mapper  '
    @verified = false
    params = {
      :method   => :post,
      :action   => :api_key,
      :api_key  => @api_key.key,
      :app      => @app,
      :for_user => @for_user.id,
    }
    api = API.execute(params)
    assert_no_errors(api, 'Errors while posting image')
    assert_obj_list_equal([ApiKey.last], api.results)
    assert_last_api_key_correct
    assert_api_fail(params.remove(:api_key))
    assert_api_fail(params.remove(:app))
    assert_api_fail(params.merge(:app => ''))
    assert_api_fail(params.merge(:for_user => 123456))
    assert_equal(email_count + 1, ActionMailer::Base.deliveries.size)
  end

  def test_unverified_user_rejected
    params = {
      :method   => :post,
      :action   => :observation,
      :api_key  => @api_key.key,
      :location => 'Anywhere',
    }
    @rolf.update_attribute(:verified, nil)
    assert_api_fail(params)
    @rolf.update_attribute(:verified, Time.now)
    assert_api_pass(params)
  end

  def test_unverified_api_key_rejected
    params = {
      :method   => :post,
      :action   => :observation,
      :api_key  => @api_key.key,
      :location => 'Anywhere',
    }
    @api_key.update_attribute(:verified, nil)
    assert_api_fail(params)
    @api_key.verify!
    assert_api_pass(params)
  end

  # ----------------------------
  #  :section: Test Parsers
  # ----------------------------

  def test_parse_boolean
    assert_parse(:parse_boolean, nil, nil)
    assert_parse(:parse_boolean, true, nil, :default => true)
    assert_parse(:parse_boolean, false, '0')
    assert_parse(:parse_boolean, false, '0', :default => true)
    assert_parse(:parse_boolean, false, 'no')
    assert_parse(:parse_boolean, false, 'NO')
    assert_parse(:parse_boolean, false, 'false')
    assert_parse(:parse_boolean, false, 'False')
    assert_parse(:parse_boolean, true, '1')
    assert_parse(:parse_boolean, true, 'yes')
    assert_parse(:parse_boolean, true, 'true')
    assert_parse(:parse_boolean, API::BadParameterValue, 'foo')
    assert_parse(:parse_booleans, nil, nil)
    assert_parse(:parse_booleans, [], nil, :default => [])
    assert_parse(:parse_booleans, [true], '1')
    assert_parse(:parse_booleans, [true,false], '1,0')
  end

  def test_parse_enum
    limit = [:one, :two, :three, :four, :five]
    assert_parse(:parse_enum, nil, nil, :limit => limit)
    assert_parse(:parse_enum, :three, nil, :limit => limit, :default => :three)
    assert_parse(:parse_enum, :two, 'two', :limit => limit)
    assert_parse(:parse_enum, :two, 'Two', :limit => limit)
    assert_parse(:parse_enum, API::BadLimitedParameterValue, '', :limit => limit)
    assert_parse(:parse_enum, API::BadLimitedParameterValue, 'Ten', :limit => limit)
    assert_parse(:parse_enums, nil, nil, :limit => limit)
    assert_parse(:parse_enums, [:one], 'one', :limit => limit)
    assert_parse(:parse_enums, [:one,:two,:three], 'one,two,three', :limit => limit)
    assert_parse(:parse_enum_range, nil, nil, :limit => limit)
    assert_parse(:parse_enum_range, :four, 'four', :limit => limit)
    assert_parse(:parse_enum_range, API::Range.new(:one, :four), 'four-one', :limit => limit)
  end

  def test_parse_string
    assert_parse(:parse_string, nil, nil)
    assert_parse(:parse_string, 'hello', nil, :default => 'hello')
    assert_parse(:parse_string, 'foo', 'foo', :default => 'hello')
    assert_parse(:parse_string, 'foo', " foo\n", :default => 'hello')
    assert_parse(:parse_string, '', '', :default => 'hello')
    assert_parse(:parse_string, 'abcd', 'abcd', :limit => 4)
    assert_parse(:parse_string, API::StringTooLong, 'abcde', :limit => 4)
    assert_parse(:parse_strings, nil, nil)
    assert_parse(:parse_strings, ['foo'], 'foo')
    assert_parse(:parse_strings, ['foo','bar'], 'foo,bar', :limit => 4)
    assert_parse(:parse_strings, API::StringTooLong, 'foo,abcde', :limit => 4)
  end

  def test_parse_integer
    assert_parse(:parse_integer, nil, nil)
    assert_parse(:parse_integer, 42, nil, :default => 42)
    assert_parse(:parse_integer, 1, '1')
    assert_parse(:parse_integer, 0, ' 0 ')
    assert_parse(:parse_integer, -13, '-13')
    assert_parse(:parse_integers, nil, nil)
    assert_parse(:parse_integers, [1], '1')
    assert_parse(:parse_integers, [3,-1,4,-159], '3,-1,4,-159')
    assert_parse(:parse_integers, [1,13], '1,13', :limit => 1..13)
    assert_parse(:parse_integers, API::BadLimitedParameterValue, '0,13', :limit => 1..13)
    assert_parse(:parse_integers, API::BadLimitedParameterValue, '1,14', :limit => 1..13)
    assert_parse(:parse_integer_range, API::Range.new(1,13), '1-13', :limit => 1..13)
    assert_parse(:parse_integer_range, API::Range.new(1,13), '13-1', :limit => 1..13)
    assert_parse(:parse_integer_range, API::BadLimitedParameterValue, '0-13', :limit => 1..13)
    assert_parse(:parse_integer_range, API::BadLimitedParameterValue, '1-14', :limit => 1..13)
    assert_parse(:parse_integer_ranges, nil, nil, :limit => 1..13)
    assert_parse(:parse_integer_ranges, [API::Range.new(1,4), API::Range.new(6,9)], '1-4,6-9', :limit => 1..13)
    assert_parse(:parse_integer_ranges, [1, 4, API::Range.new(6,9)], '1,4,6-9', :limit => 1..13)
  end

  def test_parse_float
    assert_parse(:parse_float, nil, nil)
    assert_parse(:parse_float, -2.71828, nil, :default => -2.71828)
    assert_parse(:parse_float, 0, '0', :default => -2.71828)
    assert_parse(:parse_float, 4, '4')
    assert_parse(:parse_float, -4, '-4')
    assert_parse(:parse_float, 4, '4.0')
    assert_parse(:parse_float, -4, '-4.0')
    assert_parse(:parse_float, 0, '.0')
    assert_parse(:parse_float, 0.123, '.123')
    assert_parse(:parse_float, -0.123, '-.123')
    assert_parse(:parse_float, 123.123, '123.123')
    assert_parse(:parse_float, -123.123, '-123.123')
    assert_parse(:parse_floats, nil, nil)
    assert_parse(:parse_floats, [1.2,3.4], ' 1.20, 3.40 ')
    assert_parse(:parse_float_range, API::Range.new(-3.14,2.72), '2.72 - \\-3.14')
    assert_parse(:parse_float_ranges, [API::Range.new(1,2), 4,5], '1-2,4,5')
    assert_parse(:parse_float, API::BadParameterValue, '')
    assert_parse(:parse_float, API::BadParameterValue, 'one')
    assert_parse(:parse_float, API::BadParameterValue, '+1e5')
  end

  def test_parse_date
    assert_parse(:parse_date, nil, nil)
    assert_parse(:parse_date, Date.parse('2012-06-25'), nil, :default => Date.parse('2012-06-25'))
    assert_parse(:parse_date, Date.parse('2012-06-26'), '20120626')
    assert_parse(:parse_date, Date.parse('2012-06-26'), '2012-06-26')
    assert_parse(:parse_date, Date.parse('2012-06-26'), '2012/06/26')
    assert_parse(:parse_date, Date.parse('2012-06-07'), '2012-6-7')
    assert_parse(:parse_date, API::BadParameterValue, '2012-06/7')
    assert_parse(:parse_date, API::BadParameterValue, '2012 6/7')
    assert_parse(:parse_date, API::BadParameterValue, '6/26/2012')
    assert_parse(:parse_date, API::BadParameterValue, 'today')
  end

  def test_parse_time
    assert_parse(:parse_time, nil, nil)
    assert_parse(:parse_time, DateTime.parse('2012-06-25 12:34:56'), '20120625123456')
    assert_parse(:parse_time, DateTime.parse('2012-06-25 12:34:56'), '2012-06-25 12:34:56')
    assert_parse(:parse_time, DateTime.parse('2012-06-25 12:34:56'), '2012/06/25 12:34:56')
    assert_parse(:parse_time, DateTime.parse('2012-06-05 02:04:06'), '2012/6/5 2:4:6')
    assert_parse(:parse_time, API::BadParameterValue, '201206251234567')
    assert_parse(:parse_time, API::BadParameterValue, '2012/06/25 103456')
    assert_parse(:parse_time, API::BadParameterValue, '2012-06/25 10:34:56')
    assert_parse(:parse_time, API::BadParameterValue, '2012/06/25 10:34:56am')
  end

  def test_parse_date_range
    assert_parse(:parse_date_range, nil, nil)
    assert_parse(:parse_date_range, Date.parse('2012-06-25'), nil, :default => Date.parse('2012-06-25'))
    assert_parse(:parse_date_range, Date.parse('2012-06-26'), '20120626')
    assert_parse(:parse_date_range, Date.parse('2012-06-26'), '2012-06-26')
    assert_parse(:parse_date_range, Date.parse('2012-06-26'), '2012/06/26')
    assert_parse(:parse_date_range, Date.parse('2012-06-07'), '2012-6-7')
    assert_parse(:parse_date_range, API::BadParameterValue, '2012-06/7')
    assert_parse(:parse_date_range, API::BadParameterValue, '2012 6/7')
    assert_parse(:parse_date_range, API::BadParameterValue, '6/26/2012')
    assert_parse(:parse_date_range, API::BadParameterValue, 'today')
    assert_parse(:parse_date_range, API::Range.new(Date.parse('2012-06-01'), Date.parse('2012-06-30')), '201206')
    assert_parse(:parse_date_range, API::Range.new(Date.parse('2012-06-01'), Date.parse('2012-06-30')), '2012-6')
    assert_parse(:parse_date_range, API::Range.new(Date.parse('2012-06-01'), Date.parse('2012-06-30')), '2012/06')
    assert_parse(:parse_date_range, API::Range.new(Date.parse('2012-01-01'), Date.parse('2012-12-31')), '2012')
    assert_parse(:parse_date_range, API::Range.new(6,6), '6')
    assert_parse(:parse_date_range, API::Range.new(613,613), '6/13')
    assert_parse(:parse_date_range, API::Range.new(Date.parse('2011-05-13'), Date.parse('2012-06-15')), '20110513-20120615')
    assert_parse(:parse_date_range, API::Range.new(Date.parse('2011-05-13'), Date.parse('2012-06-15')), '2011-05-13-2012-06-15')
    assert_parse(:parse_date_range, API::Range.new(Date.parse('2011-05-13'), Date.parse('2012-06-15')), '2011-5-13-2012-6-15')
    assert_parse(:parse_date_range, API::Range.new(Date.parse('2011-05-13'), Date.parse('2012-06-15')), '2011/05/13 - 2012/06/15')
    assert_parse(:parse_date_range, API::Range.new(Date.parse('2011-05-01'), Date.parse('2012-06-30')), '201105-201206')
    assert_parse(:parse_date_range, API::Range.new(Date.parse('2011-05-01'), Date.parse('2012-06-30')), '2011-5-2012-6')
    assert_parse(:parse_date_range, API::Range.new(Date.parse('2011-05-01'), Date.parse('2012-06-30')), '2012/06 - 2011/05')
    assert_parse(:parse_date_range, API::Range.new(Date.parse('2011-01-01'), Date.parse('2012-12-31')), '2011-2012')
    assert_parse(:parse_date_range, API::Range.new(Date.parse('2011-01-01'), Date.parse('2012-12-31')), '2012-2011')
    assert_parse(:parse_date_range, API::Range.new(2,5), '2-5')
    assert_parse(:parse_date_range, API::Range.new(10,3, :leave_order), '10-3')
    assert_parse(:parse_date_range, API::Range.new(612,623), '0612-0623')
    assert_parse(:parse_date_range, API::Range.new(1225,101, :leave_order), '12-25-1-1')
  end

  def test_parse_time_range
    assert_parse(:parse_time_range, nil, nil)
    assert_parse(:parse_time_range, DateTime.parse('2012-06-25 12:34:56'), '20120625123456')
    assert_parse(:parse_time_range, DateTime.parse('2012-06-25 12:34:56'), '2012-06-25 12:34:56')
    assert_parse(:parse_time_range, DateTime.parse('2012-06-25 12:34:56'), '2012/06/25 12:34:56')
    assert_parse(:parse_time_range, DateTime.parse('2012-06-05 02:04:06'), '2012/6/5 2:4:6')
    assert_parse(:parse_time_range, API::BadParameterValue, '201206251234567')
    assert_parse(:parse_time_range, API::BadParameterValue, '2012/06/25 103456')
    assert_parse(:parse_time_range, API::BadParameterValue, '2012-06/25 10:34:56')
    assert_parse(:parse_time_range, API::BadParameterValue, '2012/06/25 10:34:56am')
    assert_parse(:parse_time_range, API::Range.new(DateTime.parse('2011-02-24 02:03:01'), DateTime.parse('2011-02-24 02:03:59')), '201102240203')
    assert_parse(:parse_time_range, API::Range.new(DateTime.parse('2011-02-24 02:03:01'), DateTime.parse('2011-02-24 02:03:59')), '2011-2-24 2:3')
    assert_parse(:parse_time_range, API::Range.new(DateTime.parse('2011-02-24 02:03:01'), DateTime.parse('2011-02-24 02:03:59')), '2011/02/24 02:03')
    assert_parse(:parse_time_range, API::Range.new(DateTime.parse('2011-02-24 02:01:01'), DateTime.parse('2011-02-24 02:59:59')), '2011022402')
    assert_parse(:parse_time_range, API::Range.new(DateTime.parse('2011-02-24 02:01:01'), DateTime.parse('2011-02-24 02:59:59')), '2011-2-24 2')
    assert_parse(:parse_time_range, API::Range.new(DateTime.parse('2011-02-24 02:01:01'), DateTime.parse('2011-02-24 02:59:59')), '2011/02/24 02')
    assert_parse(:parse_time_range, API::Range.new(DateTime.parse('2011-02-24 01:01:01'), DateTime.parse('2011-02-24 23:59:59')), '20110224')
    assert_parse(:parse_time_range, API::Range.new(DateTime.parse('2011-02-24 01:01:01'), DateTime.parse('2011-02-24 23:59:59')), '2011-2-24')
    assert_parse(:parse_time_range, API::Range.new(DateTime.parse('2011-02-24 01:01:01'), DateTime.parse('2011-02-24 23:59:59')), '2011/02/24')
    assert_parse(:parse_time_range, API::Range.new(DateTime.parse('2011-02-01 01:01:01'), DateTime.parse('2011-02-28 23:59:59')), '201102')
    assert_parse(:parse_time_range, API::Range.new(DateTime.parse('2011-02-01 01:01:01'), DateTime.parse('2011-02-28 23:59:59')), '2011-2')
    assert_parse(:parse_time_range, API::Range.new(DateTime.parse('2011-02-01 01:01:01'), DateTime.parse('2011-02-28 23:59:59')), '2011/02')
    assert_parse(:parse_time_range, API::Range.new(DateTime.parse('2011-01-01 01:01:01'), DateTime.parse('2011-12-31 23:59:59')), '2011')
    assert_parse(:parse_time_range, API::Range.new(DateTime.parse('2011-05-24 02:03:04'), DateTime.parse('2012-06-25 03:04:05')), '20110524020304-20120625030405')
    assert_parse(:parse_time_range, API::Range.new(DateTime.parse('2011-05-24 02:03:04'), DateTime.parse('2012-06-25 03:04:05')), '2011-5-24 2:3:4-2012-6-25 3:4:5')
    assert_parse(:parse_time_range, API::Range.new(DateTime.parse('2011-05-24 02:03:04'), DateTime.parse('2012-06-25 03:04:05')), '2011/05/24 02:03:04 - 2012/06/25 03:04:05')
    assert_parse(:parse_time_range, API::Range.new(DateTime.parse('2011-05-24 02:03:01'), DateTime.parse('2012-06-25 03:04:59')), '201206250304-201105240203')
    assert_parse(:parse_time_range, API::Range.new(DateTime.parse('2011-05-24 02:03:01'), DateTime.parse('2012-06-25 03:04:59')), '2012-6-25 3:4-2011-5-24 2:3')
    assert_parse(:parse_time_range, API::Range.new(DateTime.parse('2011-05-24 02:03:01'), DateTime.parse('2012-06-25 03:04:59')), '2012/06/25 03:04 - 2011/05/24 02:03')
    assert_parse(:parse_time_range, API::Range.new(DateTime.parse('2011-05-24 02:01:01'), DateTime.parse('2012-06-25 03:59:59')), '2012062503-2011052402')
    assert_parse(:parse_time_range, API::Range.new(DateTime.parse('2011-05-24 02:01:01'), DateTime.parse('2012-06-25 03:59:59')), '2012-6-25 3-2011-5-24 2')
    assert_parse(:parse_time_range, API::Range.new(DateTime.parse('2011-05-24 02:01:01'), DateTime.parse('2012-06-25 03:59:59')), '2012/06/25 03 - 2011/05/24 02')
    assert_parse(:parse_time_range, API::Range.new(DateTime.parse('2011-05-24 01:01:01'), DateTime.parse('2012-06-25 23:59:59')), '20120625-20110524')
    assert_parse(:parse_time_range, API::Range.new(DateTime.parse('2011-05-24 01:01:01'), DateTime.parse('2012-06-25 23:59:59')), '2012-6-25-2011-5-24')
    assert_parse(:parse_time_range, API::Range.new(DateTime.parse('2011-05-24 01:01:01'), DateTime.parse('2012-06-25 23:59:59')), '2012/06/25 - 2011/05/24')
    assert_parse(:parse_time_range, API::Range.new(DateTime.parse('2011-05-01 01:01:01'), DateTime.parse('2012-06-30 23:59:59')), '201206-201105')
    assert_parse(:parse_time_range, API::Range.new(DateTime.parse('2011-05-01 01:01:01'), DateTime.parse('2012-06-30 23:59:59')), '2012-6-2011-5')
    assert_parse(:parse_time_range, API::Range.new(DateTime.parse('2011-05-01 01:01:01'), DateTime.parse('2012-06-30 23:59:59')), '2012/06 - 2011/05')
    assert_parse(:parse_time_range, API::Range.new(DateTime.parse('2011-01-01 01:01:01'), DateTime.parse('2012-12-31 23:59:59')), '2012-2011')
    assert_parse(:parse_time_range, API::Range.new(DateTime.parse('2011-01-01 01:01:01'), DateTime.parse('2012-12-31 23:59:59')), '2011 - 2012')
  end

  def test_parse_latitude
    assert_parse(:parse_latitude, nil, nil)
    assert_parse(:parse_latitude, 45, nil, :default => 45)
    assert_parse(:parse_latitude, 4, '4')
    assert_parse(:parse_latitude, -4, '-4')
    assert_parse(:parse_latitude, 4.1235, '4.1234567')
    assert_parse(:parse_latitude, -4.1235, '-4.1234567')
    assert_parse(:parse_latitude, -4.1235, '4.1234567S')
    assert_parse(:parse_latitude, 12.5822, '12°34\'56"N')
    assert_parse(:parse_latitude, 12.5760, '12 34.56 N')
    assert_parse(:parse_latitude, -12.0094, '12deg 34sec S')
    assert_parse(:parse_latitude, API::BadParameterValue, '12 34.56 E')
    assert_parse(:parse_latitude, API::BadParameterValue, '12 degrees 34.56 minutes')
    assert_parse(:parse_latitude, API::BadParameterValue, '12.56s')
    assert_parse(:parse_latitude, 90.0000, '90d 0s N')
    assert_parse(:parse_latitude, -90.0000, '90d 0s S')
    assert_parse(:parse_latitude, API::BadParameterValue, '90d 1s N')
    assert_parse(:parse_latitude, API::BadParameterValue, '90d 1s S')
    assert_parse(:parse_latitudes, nil, nil)
    assert_parse(:parse_latitudes, [1.2, 3.4], '1.2,3.4')
    assert_parse(:parse_latitude_range, nil, nil)
    assert_parse(:parse_latitude_range, API::Range.new(-12,34), '12S-34N')
    assert_parse(:parse_latitude_range, API::Range.new(-34,12), '12N-34S')
    assert_parse(:parse_latitude_ranges, [API::Range.new(-34,12), 6,7], '12N-34S,6,7')
  end

  def test_parse_longitude
    assert_parse(:parse_longitude, nil, nil)
    assert_parse(:parse_longitude, 45, nil, :default => 45)
    assert_parse(:parse_longitude, 4, '4')
    assert_parse(:parse_longitude, -4, '-4')
    assert_parse(:parse_longitude, 4.1235, '4.1234567')
    assert_parse(:parse_longitude, -4.1235, '-4.1234567')
    assert_parse(:parse_longitude, -4.1235, '4.1234567W')
    assert_parse(:parse_longitude, 12.5822, '12°34\'56"E')
    assert_parse(:parse_longitude, 12.5760, '12 34.56 E')
    assert_parse(:parse_longitude, -12.0094, '12deg 34sec W')
    assert_parse(:parse_longitude, API::BadParameterValue, '12 34.56 S')
    assert_parse(:parse_longitude, API::BadParameterValue, '12 degrees 34.56 minutes')
    assert_parse(:parse_longitude, API::BadParameterValue, '12.56e')
    assert_parse(:parse_longitude, 180.0000, '180d 0s E')
    assert_parse(:parse_longitude, -180.0000, '180d 0s W')
    assert_parse(:parse_longitude, API::BadParameterValue, '180d 1s E')
    assert_parse(:parse_longitude, API::BadParameterValue, '180d 1s W')
    assert_parse(:parse_longitudes, nil, nil)
    assert_parse(:parse_longitudes, [1.2, 3.4], '1.2,3.4')
    assert_parse(:parse_longitude_range, nil, nil)
    assert_parse(:parse_longitude_range, API::Range.new(-12,34), '12W-34E')
    assert_parse(:parse_longitude_range, API::Range.new(12,-34,:leave_order), '12E-34W')
    assert_parse(:parse_longitude_ranges, [API::Range.new(-12,34), 6,7], '12W-34E,6,7')
  end

  def test_parse_altitude
    assert_parse(:parse_altitude, nil, nil)
    assert_parse(:parse_altitude, 123, nil, :default => 123)
    assert_parse(:parse_altitude, 123, '123')
    assert_parse(:parse_altitude, 123, '123 m')
    assert_parse(:parse_altitude, 123, '403 ft')
    assert_parse(:parse_altitude, 123, '403\'')
    assert_parse(:parse_altitude, API::BadParameterValue, 'sealevel')
    assert_parse(:parse_altitude, API::BadParameterValue, '123 FT')
    assert_parse(:parse_altitudes, nil, nil)
    assert_parse(:parse_altitudes, [123], '123')
    assert_parse(:parse_altitudes, [123,456], '123,456m')
    assert_parse(:parse_altitude_range, nil, nil)
    assert_parse(:parse_altitude_range, API::Range.new(12,34), '12-34')
    assert_parse(:parse_altitude_range, API::Range.new(54,76), '76-54')
    assert_parse(:parse_altitude_ranges, nil, nil)
    assert_parse(:parse_altitude_ranges, [API::Range.new(54,76),3,2], '76-54,3,2')
  end

  def test_parse_image
    img1 = Image.find(1)
    img2 = Image.find(2)
    assert_parse(:parse_image, nil, nil)
    assert_parse(:parse_image, img1, nil, :default => img1)
    assert_parse(:parse_image, img1, '1')
    assert_parse(:parse_images, [img2,img1], '2,1')
    assert_parse(:parse_image_range, API::Range.new(img1, img2), '2-1')
    assert_parse(:parse_image, API::BadParameterValue, '')
    assert_parse(:parse_image, API::BadParameterValue, 'name')
    assert_parse(:parse_image, API::ObjectNotFoundById, '12345')
  end

  def test_parse_license
    lic1 = License.find(1)
    lic2 = License.find(2)
    assert_parse(:parse_license, nil, nil)
    assert_parse(:parse_license, lic2, nil, :default => lic2)
    assert_parse(:parse_license, lic2, '2')
    assert_parse(:parse_licenses, [lic2,lic1], '2,1')
    assert_parse(:parse_license_range, API::Range.new(lic1,lic2), '2-1')
    assert_parse(:parse_license, API::BadParameterValue, '')
    assert_parse(:parse_license, API::BadParameterValue, 'name')
    assert_parse(:parse_license, API::ObjectNotFoundById, '12345')
  end

  def test_parse_location
    loc2 = Location.find(2)
    loc5 = Location.find(5)
    assert_parse(:parse_location, nil, nil)
    assert_parse(:parse_location, loc5, nil, :default => loc5)
    assert_parse(:parse_location, loc5, '5')
    assert_parse(:parse_locations, [loc5,loc2], '5,2')
    assert_parse(:parse_location_range, API::Range.new(loc2,loc5), '5-2')
    assert_parse(:parse_location, API::BadParameterValue, '')
    assert_parse(:parse_location, API::ObjectNotFoundByString, 'name')
    assert_parse(:parse_location, API::ObjectNotFoundById, '12345')
    assert_parse(:parse_location, loc2, loc2.name)
    assert_parse(:parse_location, loc2, loc2.scientific_name)
  end

  def test_parse_place_name
    loc2 = Location.find(2)
    loc5 = Location.find(5)
    assert_parse(:parse_place_name, nil, nil)
    assert_parse(:parse_place_name, loc5.name, nil, :default => loc5.name)
    assert_parse(:parse_place_name, loc5.name, '5')
    assert_parse(:parse_place_name, API::BadParameterValue, '')
    assert_parse(:parse_place_name, 'name', 'name')
    assert_parse(:parse_place_name, API::ObjectNotFoundById, '12345')
    assert_parse(:parse_place_name, loc2.name, loc2.name)
    assert_parse(:parse_place_name, loc2.name, loc2.scientific_name)
  end

  def test_parse_name
    name10 = Name.find(10)
    name20 = Name.find(20)
    assert_parse(:parse_name, nil, nil)
    assert_parse(:parse_name, name20, nil, :default => name20)
    assert_parse(:parse_name, name20, '20')
    assert_parse(:parse_name, API::BadParameterValue, '')
    assert_parse(:parse_name, API::ObjectNotFoundById, '12345')
    assert_parse(:parse_name, API::ObjectNotFoundByString, 'Bogus name')
    assert_parse(:parse_name, API::NameDoesntParse, 'yellow mushroom')
    assert_parse(:parse_name, API::AmbiguousName, 'Amanita baccata')
    assert_parse(:parse_name, name10, 'Macrolepiota rhacodes')
    assert_parse(:parse_name, name10, 'Macrolepiota rhacodes (Vittad.) Singer')
    assert_parse(:parse_names, [name20,name10], '20,10')
    assert_parse(:parse_name_range, API::Range.new(name10,name20), '20-10')
  end

  def test_parse_observation
    obs5 = Observation.find(5)
    obs10 = Observation.find(10)
    assert_parse(:parse_observation, nil, nil)
    assert_parse(:parse_observation, obs5, nil, :default => obs5)
    assert_parse(:parse_observation, obs5, '5')
    assert_parse(:parse_observations, [obs10,obs5], '10,5')
    assert_parse(:parse_observation_range, API::Range.new(obs5, obs10), '10-5')
    assert_parse(:parse_observation, API::BadParameterValue, '')
    assert_parse(:parse_observation, API::BadParameterValue, 'name')
    assert_parse(:parse_observation, API::ObjectNotFoundById, '12345')
  end

  def test_parse_project
    proj1 = Project.find(1)
    proj2 = Project.find(2)
    assert_parse(:parse_project, nil, nil)
    assert_parse(:parse_project, proj2, nil, :default => proj2)
    assert_parse(:parse_project, proj2, '2')
    assert_parse(:parse_projects, [proj2,proj1], '2,1')
    assert_parse(:parse_project_range, API::Range.new(proj1,proj2), '2-1')
    assert_parse(:parse_project, API::BadParameterValue, '')
    assert_parse(:parse_project, API::ObjectNotFoundByString, 'name')
    assert_parse(:parse_project, API::ObjectNotFoundById, '12345')
    assert_parse(:parse_project, proj1, proj1.title)
  end

  def test_parse_species_list
    spl1 = SpeciesList.find(1)
    spl2 = SpeciesList.find(2)
    assert_parse(:parse_species_list, nil, nil)
    assert_parse(:parse_species_list, spl2, nil, :default => spl2)
    assert_parse(:parse_species_list, spl2, '2')
    assert_parse(:parse_species_lists, [spl2,spl1], '2,1')
    assert_parse(:parse_species_list_range, API::Range.new(spl1,spl2), '2-1')
    assert_parse(:parse_species_list, API::BadParameterValue, '')
    assert_parse(:parse_species_list, API::ObjectNotFoundByString, 'name')
    assert_parse(:parse_species_list, API::ObjectNotFoundById, '12345')
    assert_parse(:parse_species_list, spl1, spl1.title)
  end

  def test_parse_user
    user1 = User.find(1)
    user2 = User.find(2)
    assert_parse(:parse_user, nil, nil)
    assert_parse(:parse_user, user2, nil, :default => user2)
    assert_parse(:parse_user, user2, '2')
    assert_parse(:parse_users, [user2,user1], '2,1')
    assert_parse(:parse_user_range, API::Range.new(user1,user2), '2-1')
    assert_parse(:parse_user, API::BadParameterValue, '')
    assert_parse(:parse_user, API::ObjectNotFoundByString, 'name')
    assert_parse(:parse_user, API::ObjectNotFoundById, '12345')
    assert_parse(:parse_user, user1, user1.login)
    assert_parse(:parse_user, user1, user1.name)
  end

  def test_parse_object
    limit = [Name, Observation, SpeciesList]
    obs10 = Observation.find(10)
    name20 = Name.find(20)
    spl2 = SpeciesList.find(2)
    assert_parse(:parse_object, nil, nil, :limit => limit)
    assert_parse(:parse_object, obs10, nil, :default => obs10, :limit => limit)
    assert_parse(:parse_object, obs10, 'observation 10', :limit => limit)
    assert_parse(:parse_object, name20, 'name 20', :limit => limit)
    assert_parse(:parse_object, spl2, 'species list 2', :limit => limit)
    assert_parse(:parse_object, spl2, 'species_list 2', :limit => limit)
    assert_parse(:parse_object, spl2, 'Species List 2', :limit => limit)
    assert_parse(:parse_object, API::BadParameterValue, '', :limit => limit)
    assert_parse(:parse_object, API::BadParameterValue, '1', :limit => limit)
    assert_parse(:parse_object, API::BadParameterValue, 'bogus', :limit => limit)
    assert_parse(:parse_object, API::BadLimitedParameterValue, 'bogus 1', :limit => limit)
    assert_parse(:parse_object, API::BadLimitedParameterValue, 'license 1', :limit => limit)
    assert_parse(:parse_object, API::ObjectNotFoundById, 'name 12345', :limit => limit)
    assert_parse(:parse_objects, [obs10, name20], 'observation 10, name 20', :limit => limit)
  end

  def test_check_edit_permission
    @api = API.new
    @api.user = @dick
    proj = @dick.projects_member.first
    assert_not_nil(img_good = proj.images.first)
    assert_not_nil(img_bad = (Image.all - proj.images - @dick.images).first)
    assert_not_nil(obs_good = proj.observations.first)
    assert_not_nil(obs_bad = (Observation.all - proj.observations - @dick.observations).first)
    assert_not_nil(spl_good = proj.species_lists.first)
    assert_not_nil(spl_bad = (SpeciesList.all - proj.species_lists - @dick.species_lists).first)

    args = { :must_have_edit_permission => true }
    assert_parse(:parse_image, img_good, img_good.id, args)
    assert_parse(:parse_image, API::MustHaveEditPermission, img_bad.id, args)
    assert_parse(:parse_observation, obs_good, obs_good.id, args)
    assert_parse(:parse_observation, API::MustHaveEditPermission, obs_bad.id, args)
    assert_parse(:parse_species_list, spl_good, spl_good.id, args)
    assert_parse(:parse_species_list, API::MustHaveEditPermission, spl_bad.id, args)
    assert_parse(:parse_user, @dick, @dick.id, args)
    assert_parse(:parse_user, API::MustHaveEditPermission, '1', args)

    args[:limit] = [Image, Observation, SpeciesList, User]
    assert_parse(:parse_object, img_good, "image #{img_good.id}", args)
    assert_parse(:parse_object, API::MustHaveEditPermission, "image #{img_bad.id}", args)
    assert_parse(:parse_object, obs_good, "observation #{obs_good.id}", args)
    assert_parse(:parse_object, API::MustHaveEditPermission, "observation #{obs_bad.id}", args)
    assert_parse(:parse_object, spl_good, "species list #{spl_good.id}", args)
    assert_parse(:parse_object, API::MustHaveEditPermission, "species list #{spl_bad.id}", args)
    assert_parse(:parse_object, @dick, "user #{@dick.id}", args)
    assert_parse(:parse_object, API::MustHaveEditPermission, 'user 1', args)
  end

  def test_check_project_membership
    @api = API.new
    proj = projects(:eol_project)
    assert_not_nil(admin = proj.admin_group.users.first )
    assert_not_nil(member = (proj.user_group.users - proj.admin_group.users).first )
    assert_not_nil(other = (User.all - proj.admin_group.users - proj.user_group.users).first)

    @api.user = admin
    assert_parse(:parse_project, proj, proj.id, :must_be_admin => true)
    assert_parse(:parse_project, proj, proj.id, :must_be_member => true)

    @api.user = member
    assert_parse(:parse_project, API::MustBeAdmin, proj.id, :must_be_admin => true)
    assert_parse(:parse_project, proj, proj.id, :must_be_member => true)

    @api.user = other
    assert_parse(:parse_project, API::MustBeAdmin, proj.id, :must_be_admin => true)
    assert_parse(:parse_project, API::MustBeMember, proj.id, :must_be_member => true)
  end
end
