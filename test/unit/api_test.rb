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

  def test_post_fully_featured_observation
    @img1 = Image.find(1)
    @img2 = Image.find(2) 
    @loc = locations(:albion)
    @spl = species_lists(:first_species_list)
    @proj = projects(:eol_project)
    @name = names(:coprinus_comatus)
    @notes = "These are notes.\nThey look like this.\n"

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

    # First, make sure it works if everything is correct.
    api = API.execute(params)
    assert_no_errors(api, 'Errors while posting observation')
    assert_obj_list_equal([Observation.last], api.results)
    assert_observation_correct
    assert_naming_correct
    assert_vote_correct

    assert_api_pass(params.remove(:date))
    assert_api_pass(params.remove(:notes))
    assert_api_pass(params.remove(:location))
    assert_api_pass(params.remove(:latitude, :longitude, :altitude))
    assert_api_pass(params.remove(:has_specimen))
    assert_api_pass(params.remove(:name, :vote))
    assert_api_pass(params.remove(:vote))
    assert_api_pass(params.remove(:projects))
    assert_api_pass(params.remove(:species_lists))
    assert_api_pass(params.remove(:thumbnail))
    assert_api_pass(params.remove(:images))
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

  def assert_observation_correct
    obs = Observation.last
    naming = Naming.last
    vote = Vote.last
    assert_in_delta(Time.now, obs.created, 1.minute)
    assert_in_delta(Time.now, obs.modified, 1.minute)
    assert_equal('2012-06-26', obs.when.web_date)
    assert_users_equal(@rolf, obs.user)
    assert_true(obs.specimen)
    assert_equal(@notes.strip, obs.notes)
    assert_objs_equal(@img2, obs.thumb_image)
    assert_obj_list_equal([@img1, @img2], obs.images)
    assert_objs_equal(@loc, obs.location)
    assert_nil(obs.where)
    assert_equal(@loc.name, obs.place_name)
    assert_true(obs.is_collection_location)
    assert_equal(0, obs.num_views)
    assert_nil(obs.last_view)
    assert_not_nil(obs.rss_log)
    assert_equal(39.2290, obs.lat.round(4))
    assert_equal(-123.7700, obs.long.round(4))
    assert_equal(50, obs.alt.round)
    assert_obj_list_equal([@proj], obs.projects)
    assert_obj_list_equal([@spl], obs.species_lists)
    assert_names_equal(@name, obs.name)
    assert_in_delta(2, obs.vote_cache, 1) # vote_cache is weird
    assert_equal(1, obs.namings.length)
    assert_objs_equal(naming, obs.namings.first)
    assert_equal(1, obs.votes.length)
    assert_objs_equal(vote, obs.votes.first)
  end

  def assert_naming_correct
    obs = Observation.last
    naming = Naming.last
    vote = Vote.last
    assert_names_equal(@name, naming.name)
    assert_objs_equal(obs, naming.observation)
    assert_users_equal(@rolf, naming.user)
    assert_in_delta(2, naming.vote_cache, 1) # vote_cache is weird
    assert_in_delta(Time.now, naming.created, 1.minute)
    assert_in_delta(Time.now, naming.modified, 1.minute)
    assert_equal(1, naming.votes.length)
    assert_objs_equal(vote, naming.votes.first)
  end

  def assert_vote_correct
    obs = Observation.last
    naming = Naming.last
    vote = Vote.last
    assert_objs_equal(naming, vote.naming)
    assert_objs_equal(obs, vote.observation)
    assert_users_equal(@rolf, vote.user)
    assert_equal(2.0, vote.value)
    assert_in_delta(Time.now, vote.created, 1.minute)
    assert_in_delta(Time.now, vote.modified, 1.minute)
    assert_true(vote.favorite)
  end
end
