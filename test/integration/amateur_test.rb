# encoding: utf-8
# Test typical sessions of amateur user who just posts the occasional comment,
# observations, or votes.

require File.expand_path(File.dirname(__FILE__) + '/../boot')

class AmateurTest < IntegrationTestCase

  # -------------------------------
  #  Test basic login heuristics.
  # -------------------------------

  def test_login
    # Start at index.
    get('/')
    save_path = path

    # Login.
    click(:label => 'Login', :in => :left_panel)
    assert_template('account/login')

    # Try to login without a password.
    open_form do |form|
      form.assert_value('login', '')
      form.assert_value('password', '')
      form.assert_value('remember_me', true)
      form.change('login', 'rolf')
      form.submit('Login')
    end
    assert_template('account/login')
    assert_flash(/unsuccessful/i)

    # Try again with incorrect password.
    open_form do |form|
      form.assert_value('login', 'rolf')
      form.assert_value('password', '')
      form.assert_value('remember_me', true)
      form.change('password', 'boguspassword')
      form.submit('Login')
    end
    assert_template('account/login')
    assert_flash(/unsuccessful/i)

    # Try yet again with correct password.
    open_form do |form|
      form.assert_value('login', 'rolf')
      form.assert_value('password', '')
      form.assert_value('remember_me', true)
      form.change('password', 'testpassword')
      form.submit('Login')
    end
    assert_template('observer/list_rss_logs')
    assert_flash(/success/i)

    # This should only be accessible if logged in.
    click(:label => 'Preferences', :in => :left_panel)
    assert_template('account/prefs')

    # Log out and try again.
    click(:label => 'Logout', :in => :left_panel)
    assert_template('account/logout_user')
    assert_raises(Test::Unit::AssertionFailedError) do
      click(:label => 'Preferences', :in => :left_panel)
    end
    get_via_redirect('/account/prefs')
    assert_template('account/login')
  end

  # ----------------------------
  #  Test autologin cookies.
  # ----------------------------

  def test_autologin
    login('rolf', 'testpassword', :true)
    rolf_cookies = cookies.dup
    rolf_cookies.delete('mo_session')
    assert_match(/^1/, rolf_cookies['mo_user'])

    login('mary', 'testpassword', true)
    mary_cookies = cookies.dup
    mary_cookies.delete('mo_session')
    assert_match(/^2/, mary_cookies['mo_user'])

    login('dick', 'testpassword', false)
    dick_cookies = cookies.dup
    dick_cookies.delete('mo_session')
    assert_equal('', dick_cookies['mo_user'])

    open_session do
      self.cookies = rolf_cookies
      get_via_redirect('/account/prefs')
      assert_template('account/prefs')
      assert_users_equal(@rolf, assigns(:user))
    end

    open_session do
      self.cookies = mary_cookies
      get_via_redirect('/account/prefs')
      assert_template('account/prefs')
      assert_users_equal(@mary, assigns(:user))
    end

    open_session do
      self.cookies = dick_cookies
      get_via_redirect('/account/prefs')
      assert_template('account/login')
    end
  end

  # ----------------------------------
  #  Test everything about comments.
  # ----------------------------------

  def test_post_comment
    obs = observations(:detailed_unknown)
    # (Make sure Katrina doesn't own any comments on this observation yet.)
    assert_false(obs.comments.any? {|c| c.user == @katrina})

    summary = 'Test summary'
    message = 'This is a big fat test!'
    message2 = 'This may be _Xylaria polymorpha_, no?'

    # Start by showing the observation...
    get("/obs/#{obs.id}")

    # (Make sure there are no edit or destroy controls on existing comments.)
    assert_select('a[href*=edit_comment], a[href*=destroy_comment]', false)

    click(:label => 'Add Comment')
    assert_template('account/login')
    current_session.login!('katrina')
    assert_template('comment/add_comment')

    # (Make sure the form is for the correct object!)
    assert_objs_equal(obs, assigns(:target))
    # (Make sure there is a tab to go back to show_observation.)
    assert_select("div#left_tabs a[href=/obs/#{obs.id}]")

    open_form do |form|
      form.submit
    end
    assert_template('comment/add_comment')
    # (I don't care so long as it says something.)
    assert_flash(/\S/)

    open_form do |form|
      form.change('summary', summary)
      form.change('comment', message)
      form.submit
    end
    assert_template('observer/show_observation')
    assert_objs_equal(obs, assigns(:observation))

    com = Comment.last
    assert_equal(summary, com.summary)
    assert_equal(message, com.comment)

    # (Make sure comment shows up somewhere.)
    assert_match(summary, response.body)
    assert_match(message, response.body)
    # (Make sure there is an edit and destroy control for the new comment.)
    assert_select("a[href*=edit_comment/#{com.id}]", 1)
    assert_select("a[href*=destroy_comment/#{com.id}]", 1)

    # Try changing it.
    click(:label => /edit/i, :href => /edit_comment/)
    assert_template('comment/edit_comment')
    open_form do |form|
      form.assert_value('summary', summary)
      form.assert_value('comment', message)
      form.change('comment', message2)
      form.submit
    end
    assert_template('observer/show_observation')
    assert_objs_equal(obs, assigns(:observation))

    com.reload
    assert_equal(summary, com.summary)
    assert_equal(message2, com.comment)

    # (Make sure comment shows up somewhere.)
    assert_match(summary, response.body)
    assert(response.body.index(message2.tl))
    # (There should be a link in there to look up Xylaria polymorpha.)
    assert_select('a[href*=lookup_name]', 1) do |links|
      url = links.first.attributes['href']
      assert_equal("#{HTTP_DOMAIN}/observer/lookup_name/Xylaria%20polymorpha",
                   url)
    end

    # I grow weary of this comment.
    click(:label => /destroy/i, :href => /destroy_comment/)
    assert_template('observer/show_observation')
    assert_objs_equal(obs, assigns(:observation))
    assert_nil(response.body.index(summary))
    assert_select('a[href*=edit_comment], a[href*=destroy_comment]', false)
    assert_nil(Comment.safe_find(com.id))
  end

  # --------------------------------------
  #  Test proposing and voting on names.
  # --------------------------------------

  def test_proposing_names
    katrina = current_session
    obs = observations(:detailed_unknown)
    # (Make sure Katrina doesn't own any comments on this observation yet.)
    assert_false(obs.comments.any? {|c| c.user == @katrina})
    # (Make sure the name we are going to suggest doesn't exist yet.)
    text_name = 'Xylaria polymorpha'
    assert_nil(Name.find_by_text_name(text_name))
    fungi = obs.name

    # Start by showing the observation...
    get("/obs/#{obs.id}")

    # (Make sure there are no edit or destroy controls on existing namings.)
    assert_select('a[href*=edit_naming], a[href*=destroy_naming]', false)

    click(:label => /propose.*name/i)
    assert_template('account/login')
    current_session.login!(@katrina)
    assert_template('observer/create_naming')

    # (Make sure the form is for the correct object!)
    assert_objs_equal(obs, assigns(:observation))
    # (Make sure there is a tab to go back to show_observation.)
    assert_select("div#left_tabs a[href=/obs/#{obs.id}]")

    open_form do |form|
      form.assert_value('reason_1_check', false)
      form.assert_value('reason_2_check', false)
      form.assert_value('reason_3_check', false)
      form.assert_value('reason_4_check', false)
      form.submit
    end
    assert_template('observer/create_naming')
    # (I don't care so long as it says something.)
    assert_flash(/\S/)

    open_form do |form|
      form.change('name', text_name)
      form.submit
    end
    assert_template('observer/create_naming')
    assert_select('div.Warnings') do |elems|
      assert_block('Expected error about name not existing yet.') do
        elems.any? {|e| e.to_s.match(/#{text_name}.*not recognized/i)}
      end
    end

    open_form do |form|
      # Re-submit to accept name.
      form.submit
    end
    assert_template('observer/create_naming')
    assert_flash(/confidence/i)

    open_form do |form|
      form.assert_value('name', text_name)
      form.assert_value('reason_1_check', false)
      form.assert_value('reason_2_check', false)
      form.assert_value('reason_3_check', false)
      form.assert_value('reason_4_check', false)
      form.select(/vote/, /call it that/i)
      form.submit
    end
    assert_template('observer/show_observation')
    assert_flash(/success/i)
    assert_objs_equal(obs, assigns(:observation))

    obs.reload
    name = Name.find_by_text_name(text_name)
    naming = Naming.last
    assert_names_equal(name, naming.name)
    assert_names_equal(name, obs.name)
    assert_equal('', name.author.to_s)

    # (Make sure naming shows up somewhere.)
    assert_match(text_name, response.body)
    # (Make sure there is an edit and destroy control for the new naming.)
    assert_select("a[href*=edit_naming/#{naming.id}]", 1)
    assert_select("a[href*=destroy_naming/#{naming.id}]", 1)

    # Try changing it.
    author = '(Pers.) Grev.'
    reason = 'Test reason.'
    click(:label => /edit/i, :href => /edit_naming/)
    assert_template('observer/edit_naming')
    open_form do |form|
      form.assert_value('name', text_name)
      form.change('name', "#{text_name} #{author}")
      form.change('reason_2_check', true)
      form.change('reason_2_notes', reason)
      form.submit
    end
    assert_template('observer/show_observation')
    assert_objs_equal(obs, assigns(:observation))

    obs.reload
    name.reload
    naming.reload
    assert_equal(author, name.author)
    assert_names_equal(name, naming.name)
    assert_names_equal(name, obs.name)

    # (Make sure author shows up somewhere.)
    assert_match(author, response.body)
    # (Make sure reason shows up, too.)
    assert_match(reason, response.body)

    click(:label => /edit/i, :href => /edit_naming/)
    assert_template('observer/edit_naming')
    open_form do |form|
      form.assert_value('name', "#{text_name} #{author}")
      form.assert_value('reason_1_check', true)
      form.assert_value('reason_1_notes', '')
      form.assert_value('reason_2_check', true)
      form.assert_value('reason_2_notes', reason)
      form.assert_value('reason_3_check', false)
      form.assert_value('reason_3_notes', '')
    end
    click(:label => /cancel.*show/i)

    # Have Rolf join in the fun and vote for this naming.
    rolf = login!(@rolf)
    get("/obs/#{obs.id}")
    open_form do |form|
      form.assert_value("vote_#{naming.id}_value", 0)
      form.select("vote_#{naming.id}_value", /call it that/i)
      form.submit
    end
    assert_template('observer/show_observation')
    assert_match(/call it that/i, response.body)

    # Now Katrina shouldn't be allowed to delete her naming.
    self.current_session = katrina
    click(:label => /destroy/i, :href => /destroy_naming/)
    assert_flash(/sorry/i)

    # Have Rolf change his mind.
    self.current_session = rolf
    open_form do |form|
      form.select("vote_#{naming.id}_value", /as if!/i)
      form.submit
    end

    # Now Katrina *can* delete it.
    self.current_session = katrina
    click(:label => /destroy/i, :href => /destroy_naming/)
    assert_template('observer/show_observation')
    assert_objs_equal(obs, assigns(:observation))
    assert_flash(/success/i)

    # And that's that!
    obs.reload
    assert_names_equal(fungi, obs.name)
    assert_nil(Naming.safe_find(naming.id))
    assert_not_match(text_name, response.body)
  end

  # ------------------------------------------------------
  #  Test posting, editing, and destroying observations.
  # ------------------------------------------------------
  
  def test_posting_observation_rewrite
    @expectations = {
      :observation => observations(:amateur_observation),
      :image => images(:amateur_image),
      :location => locations(:burbank),
      :vote => votes(:amateur_vote)
    }
    katrina = regular_user(@expectations)
    katrina.login_required(@katrina, 'observer/create_observation')
    
    observation_fields = katrina.fills_in_form(observation_form_defaults, observation_form_no_location)
    katrina.evaluate_no_location
    
    observation_fields = katrina.fills_in_form(observation_fields, observation_form_location,
      [['image_0_image', "#{RAILS_ROOT}/test/fixtures/images/Coprinus_comatus.jpg"]])
    katrina.evaluate_new_location_observation

    katrina.fills_in_form(location_form_defaults)
    katrina.evaluate_new_location
    katrina.evaluate_show_observation
    
    katrina.click(:label => /edit observation/i)
    katrina.fills_in_form(edit_observation_form_defaults(katrina.new_observation), observation_form_change_location)
    katrina.evaluate_change_location
    
    rolf = regular_user(@expectations)
    rolf.get('/')
    rolf.evaluate_observation_on_index

    katrina.click(:label => /destroy/i, :href => /destroy_observation/)
    katrina.evaluate_destruction
  
    rolf.get('/')
    rolf.evaluate_orphan
  end
  
  def regular_user(expectations)
    open_session do |sess|
      def sess.set_expectations(expectations)
        @expectations = expectations
      end
      sess.set_expectations(expectations)
      
      def sess.login_required(user, page)
        get(page)
        assert_template('account/login')
        login!(user)
        assert_template(page)
      end
      
      def sess.reload_results
        @new_observation = Observation.last
        @new_image = Image.last
        @new_location = Location.last
      end
      
      def sess.new_observation
        @new_observation
      end
      
      def sess.fills_in_form(expected, new_values={}, images=[])
        open_form do |form|
          for key, value in expected
            form.assert_value(key, value)
          end
          for key, value in new_values
            form.change(key, value)
          end
          setup_image_dirs
          for id, filename in images
            form.upload(id, filename, 'image/jpeg')
          end
          form.submit
        end
        expected.merge(new_values)
      end

      def sess.evaluate_observation_on_index
        reload_results
        assert_select("a[href^=/obs/#{@new_observation.id}?]", :minimum => 1)
      end

      def sess.evaluate_destruction
        assert_flash_success
        assert_flash(/destroyed/i)
        assert_template('observer/list_observations')
      end
      
      def sess.evaluate_orphan
        assert_select("a[href^=/#{@new_observation.id}?]", 0)
        assert_select('a[href*=show_rss_log]') do |elems|
          assert(elems.any? {|e| e.to_s.match(/deleted.*item/mi)} )
        end
      end

      def sess.evaluate_no_location
        assert_template('observer/create_observation')
        assert_flash(/where|location/i)
      end

      def sess.evaluate_new_location_observation
        assert_flash(/success/i)
        assert_flash(/uploaded/i)
        assert_flash(/created observation/i)
        assert_flash(/created proposed name/i)
        assert_template('location/create_location')

        reload_results
        assert_users_equal(@expectations[:observation].user, @new_observation.user)
        assert(@new_observation.created > Time.now - 1.minute)
        assert(@new_observation.modified > Time.now - 1.minute)
        assert_dates_equal(@expectations[:observation].when, @new_observation.when)
        assert_equal(@expectations[:observation].where, @new_observation.where)
        assert_nil(@new_observation.location)
        assert_gps_equal(@new_observation.lat, @expectations[:observation].lat)
        assert_gps_equal(@new_observation.long, @expectations[:observation].long)
        assert_names_equal(@expectations[:observation].name, @new_observation.name)
        assert_equal(@expectations[:observation].is_collection_location, @new_observation.is_collection_location)
        assert_equal(@expectations[:observation].specimen, @new_observation.specimen)
        assert_equal(@expectations[:observation].notes, @new_observation.notes)
        assert_obj_list_equal([@new_image], @new_observation.images)
        assert_dates_equal(@expectations[:image].when, @new_image.when)
        assert_equal(@expectations[:image].copyright_holder, @new_image.copyright_holder)
        assert_equal(@expectations[:image].notes, @new_image.notes)
        assert(assigns(:location))
      end
    
      def sess.evaluate_new_location
        assert_flash(/success/i)
        assert_flash(/created location/i)
        assert_template('observer/show_observation')
        
        reload_results
        assert_equal(@expectations[:observation].where, @new_location.name)
        assert_equal(@new_observation.location_id, @new_location.id)
        assert_match(EXPECTED_PASADENA_GPS['location_north'], @new_location.north.to_s)
        assert_match(EXPECTED_PASADENA_GPS['location_west'], @new_location.west.to_s)
        assert_match(EXPECTED_PASADENA_GPS['location_east'], @new_location.east.to_s)
        assert_match(EXPECTED_PASADENA_GPS['location_south'], @new_location.south.to_s)
      end
  
      def sess.evaluate_show_observation
        # Make sure important bits show up somewhere on page.
        assert_match(@new_observation.when.web_date, response.body)
        for token in @new_observation.location.name.split(', ') # USA ends up as <span class=\"caps\">USA</span>, so just search for each component
          assert_match(token, response.body)
        end
        assert_match(:show_observation_seen_at.l, response.body)
        assert_match(/specimen available/, response.body)
        assert_match(@new_observation.notes, response.body)
        assert_match(@new_image.notes, response.body)
        assert_select('a[href*=observations_at_where]', 0)
        assert_select('a[href*=show_location]', 1)
        assert_select('a[href*=show_image]')
      end

      def sess.evaluate_change_location
        assert_flash_success
        assert_template('observer/show_observation')

        reload_results
        assert_objs_equal(@expectations[:location], @new_observation.location)
        assert_equal(@expectations[:location].display_name, @new_observation.place_name)
        assert_select('a[href*=observations_at_where]', 0)
        assert_select('a[href*=show_location]', 1)
      end
    end
  end

  def observation_form_defaults
    local_now = Time.now.in_time_zone
    {
      'observation_when_1i' => local_now.year,
      'observation_when_2i' => local_now.month,
      'observation_when_3i' => local_now.day,
      'observation_place_name' => '',
      'observation_lat' => '',
      'observation_long' => '',
      'name_name' => '',
      'is_collection_location' => true,
      'specimen' => false,
      'observation_notes' => ''
    }
  end

  def observation_form_no_location
    {
      'observation_when_1i' => @expectations[:observation].when.year,
      'observation_when_2i' => @expectations[:observation].when.month,
      'observation_when_3i' => @expectations[:observation].when.day,
      'is_collection_location' => @expectations[:observation].is_collection_location,
      'specimen' => @expectations[:observation].specimen,
      'observation_notes' => @expectations[:observation].notes
    }
  end

  def observation_form_location
    {
      'observation_place_name' => @expectations[:observation].where,
      'observation_lat' => @expectations[:observation].lat,
      'observation_long'=> @expectations[:observation].long,
      'name_name' => ' ' + @expectations[:observation].name.text_name + ' ',
      'vote_value' => @expectations[:vote].value,
      'image_0_when_1i' => @expectations[:image].when.year,
      'image_0_when_2i' => @expectations[:image].when.month,
      'image_0_when_3i' => @expectations[:image].when.day,
      'image_0_copyright_holder' => @expectations[:image].copyright_holder,
      'image_0_notes' => @expectations[:image].notes,
    }
  end

  # Can't make this a fixture since it would then match the location name 'Pasadena, California, USA'
  # All these need to be patterns to match the strings returned by the Google Map API.
  # Note that these tests only work when you have a working Internet connection.
  EXPECTED_PASADENA_GPS = {
    'location_north' => /34.251/,
    'location_west' => /-118.198/,
    'location_east' => /-118.065/,
    'location_south' => /34.119/,
  }

  def location_form_defaults
    {
      'location_display_name' => @expectations[:observation].where,
      'location_high' => '',
      'location_low' => '',
      'location_notes' => ''
    }.merge(EXPECTED_PASADENA_GPS)
  end

  def edit_observation_form_defaults(new_observation)
    {
      'observation_when_1i' => new_observation.when.year,
      'observation_when_2i' => new_observation.when.month,
      'observation_when_3i' => new_observation.when.day,
      'observation_place_name' => new_observation.place_name,
      'observation_lat' => /#{new_observation.lat}/,
      'observation_long' => /#{new_observation.long}/,
      'is_collection_location' => new_observation.is_collection_location,
      'specimen' => new_observation.specimen,
      'observation_notes' => new_observation.notes
    }
  end

  IMAGE_NOTE_ADDITION = "Isn't it grand?"

  def observation_form_change_location
    {
      'observation_place_name' => @expectations[:location].display_name,
    }
  end
end
