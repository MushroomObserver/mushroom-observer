# Test typical sessions of amateur user who just posts the occasional comment,
# observations, or votes.

require File.dirname(__FILE__) + '/../boot'

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
    get("/#{obs.id}")

    # (Make sure there are no edit or destroy controls on existing comments.)
    assert_select('a[href*=edit_comment], a[href*=destroy_comment]', false)

    click(:label => 'Add Comment', :in => :tabs)
    assert_template('account/login')
    current_session.login!('katrina')
    assert_template('comment/add_comment')

    # (Make sure the form is for the correct object!)
    assert_objs_equal(obs, assigns(:object))
    # (Make sure there is a tab to go back to show_observation.)
    assert_select("div.tab_sets a[href=/#{obs.id}]")

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
    get("/#{obs.id}")

    # (Make sure there are no edit or destroy controls on existing namings.)
    assert_select('a[href*=edit_naming], a[href*=destroy_naming]', false)

    click(:label => /propose.*name/i)
    assert_template('account/login')
    current_session.login!(@katrina)
    assert_template('observer/create_naming')

    # (Make sure the form is for the correct object!)
    assert_objs_equal(obs, assigns(:observation))
    # (Make sure there is a tab to go back to show_observation.)
    assert_select("div.tab_sets a[href=/#{obs.id}]")

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
    assert_select('div.Errors') do |elems|
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
    get("/#{obs.id}")
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

  def test_posting_observation
    katrina = current_session
    local_now = Time.now.in_time_zone
    date  = local_now - 1.year - 2.months - 3.days
    place = 'Burbank, CA'
    loc   = locations(:burbank)
    name  = names(:coprinus_comatus)
    file  = "#{RAILS_ROOT}/test/fixtures/images/Coprinus_comatus.jpg"
    notes = 'A friend showed me this.'
    img_user = 'Nathan Wilson'
    img_notes = 'A friend took this photo.'
    new_img_notes = img_notes + " Isn't it grand?"
    setup_image_dirs

    get('/observer/create_observation')
    assert_template('account/login')
    current_session.login!(@katrina)
    assert_template('observer/create_observation')

    open_form do |form|
      form.assert_value('observation_when_1i', local_now.year)
      form.assert_value('observation_when_2i', local_now.month)
      form.assert_value('observation_when_3i', local_now.day)
      form.assert_value('observation_place_name', '')
      form.assert_value('name_name', '')
      form.assert_value('is_collection_location', true)
      form.assert_value('specimen', false)
      form.assert_value('observation_notes', '')
      form.select('observation_when_1i', date.year)
      form.select('observation_when_2i', date.strftime('%B'))
      form.select('observation_when_3i', date.day)
      form.uncheck('is_collection_location')
      form.check('specimen')
      form.change('observation_notes', notes)
      form.submit
    end
    assert_template('observer/create_observation')
    assert_flash(/where|location/i)

    open_form do |form|
      form.assert_value('observation_when_1i', date.year)
      form.assert_value('observation_when_2i', date.month)
      form.assert_value('observation_when_3i', date.day)
      form.assert_value('observation_place_name', '')
      form.assert_value('name_name', '')
      form.assert_value('is_collection_location', false)
      form.assert_value('specimen', true)
      form.assert_value('observation_notes', notes)
      form.change('observation_place_name', place)
      form.change('name_name', ' '+name.text_name+' ')
      form.select('vote_value', /promising/i)
      form.select('image_0_when_1i', date.year)
      form.select('image_0_when_2i', date.strftime('%B'))
      form.select('image_0_when_3i', date.day)
      form.change('image_0_copyright_holder', img_user)
      form.change('image_0_notes', img_notes)
      form.upload('image_0_image', file, 'image/jpeg')
      form.submit
    end
    assert_flash(/success/i)
    assert_flash(/uploaded/i)
    assert_flash(/created observation/i)
    assert_flash(/created proposed name/i)
    assert_template('observer/show_observation')

    obs = Observation.last
    img = Image.last
    assert_users_equal(@katrina, obs.user)
    assert(obs.created > Time.now - 1.minute)
    assert(obs.modified > Time.now - 1.minute)
    assert_dates_equal(date, obs.when)
    assert_equal(place, obs.where)
    assert_nil(obs.location)
    assert_names_equal(name, obs.name)
    assert_false(obs.is_collection_location)
    assert_true(obs.specimen)
    assert_equal(notes, obs.notes)
    assert_obj_list_equal([img], obs.images)
    assert_dates_equal(date, img.when)
    assert_equal(img_user, img.copyright_holder)
    assert_equal(img_notes, img.notes)
    assert_objs_equal(obs, assigns(:observation))

    # Make sure important bits show up somewhere on page.
    assert_match(obs.when.web_date, response.body)
    assert_match(obs.where, response.body)
    assert_match(:show_observation_seen_at.l, response.body)
    assert_match(/specimen available/, response.body)
    assert_match(notes, response.body)
    assert_match(img_notes, response.body)
    assert_select('a[href*=observations_at_where]', 1)
    assert_select('a[href*=show_location]', 0)
    assert_select('a[href*=show_image]')

    # Change location to the correct Burbank.
    click(:label => /edit observation/i)
    open_form do |form|
      form.change('place_name', loc.display_name)
      form.change("image_#{img.id}_notes", new_img_notes)
      form.submit
    end
    assert_flash_success
    assert_template('observer/show_observation')

    # Make sure things were changed correctly.
    obs.reload
    img.reload
    assert_objs_equal(loc, obs.location)
    assert_equal(loc.display_name, obs.place_name)
    assert_equal(new_img_notes, img.notes)
    assert_select('a[href*=observations_at_where]', 0)
    assert_select('a[href*=show_location]', 1)

    # Go to site index and make sure it shows up in RSS log.
    rolf = open_session
    rolf.get('/')
    rolf.assert_select("a[href^=/#{obs.id}?]", :minimum => 1)

    # Destroy it now.
    katrina.click(:label => /destroy/i, :href => /destroy_observation/)
    katrina.assert_flash_success
    katrina.assert_flash(/destroyed/i)
    katrina.assert_template('observer/list_observations')

    # Have Rolf reload and make sure log shows up as orphan.
    rolf.get('/')
    rolf.assert_select("a[href^=/#{obs.id}?]", 0)
    rolf.assert_select('a[href*=show_rss_log]') do |elems|
      assert(elems.any? {|e| e.to_s.match(/deleted.*item/mi)} )
    end
  end
end
