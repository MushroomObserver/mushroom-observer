# Test typical sessions of basic user who just posts the occasional comment,
# observations, or votes.

require File.dirname(__FILE__) + '/../boot'

class BasicUserTest < IntegrationTestCase

  # -------------------------------
  #  Test basic login heuristics.
  # -------------------------------

#   def test_login
#     # Start at index.
#     get('/')
#     save_path = path
# 
#     # Login.
#     click_on(:label => 'Login', :in => :left_panel)
#     assert_template('account/login')
# 
#     # Try to login without a password.
#     do_form('form[action$=login]') do |form|
#       form.assert_value('login', '')
#       form.assert_value('password', '')
#       form.assert_value('remember_me', true)
#       form.edit_field('login', 'rolf')
#       form.submit('Login')
#     end
#     assert_template('account/login')
#     assert_flash(/unsuccessful/i)
# 
#     # Try again with incorrect password.
#     do_form('form[action$=login]') do |form|
#       form.assert_value('login', 'rolf')
#       form.assert_value('password', '')
#       form.assert_value('remember_me', true)
#       form.edit_field('password', 'boguspassword')
#       form.submit('Login')
#     end
#     assert_template('account/login')
#     assert_flash(/unsuccessful/i)
# 
#     # Try yet again with correct password.
#     do_form('form[action$=login]') do |form|
#       form.assert_value('login', 'rolf')
#       form.assert_value('password', '')
#       form.assert_value('remember_me', true)
#       form.edit_field('password', 'testpassword')
#       form.submit('Login')
#     end
#     assert_template('observer/list_rss_logs')
#     assert_flash(/success/i)
# 
#     # This should only be accessible if logged in.
#     click_on(:label => 'Preferences', :in => :left_panel)
#     assert_template('account/prefs')
# 
#     # Log out and try again.
#     click_on(:label => 'Logout', :in => :left_panel)
#     assert_template('account/logout_user')
#     assert_raises(Test::Unit::AssertionFailedError) do
#       click_on(:label => 'Preferences', :in => :left_panel)
#     end
#     get_via_redirect('/account/prefs')
#     assert_template('account/login')
#   end
# 
#   # ----------------------------
#   #  Test autologin cookies.
#   # ----------------------------
# 
#   def test_autologin
#     login('rolf', 'testpassword', :true)
#     rolf_cookies = cookies.dup
#     rolf_cookies.delete('mo_session')
#     assert_match(/^1/, rolf_cookies['mo_user'])
# 
#     login('mary', 'testpassword', true)
#     mary_cookies = cookies.dup
#     mary_cookies.delete('mo_session')
#     assert_match(/^2/, mary_cookies['mo_user'])
# 
#     login('dick', 'testpassword', false)
#     dick_cookies = cookies.dup
#     dick_cookies.delete('mo_session')
#     assert_equal('', dick_cookies['mo_user'])
# 
#     open_session do
#       self.cookies = rolf_cookies
#       get_via_redirect('/account/prefs')
#       assert_template('account/prefs')
#       assert_users_equal(@rolf, assigns(:user))
#     end
# 
#     open_session do
#       self.cookies = mary_cookies
#       get_via_redirect('/account/prefs')
#       assert_template('account/prefs')
#       assert_users_equal(@mary, assigns(:user))
#     end
# 
#     open_session do
#       self.cookies = dick_cookies
#       get_via_redirect('/account/prefs')
#       assert_template('account/login')
#     end
#   end
# 
#   # ----------------------------------
#   #  Test everything about comments.
#   # ----------------------------------
# 
#   def test_post_comment
#     obs = observations(:detailed_unknown)
#     # (Make sure Katrina doesn't own any comments on this observation yet.)
#     assert_false(obs.comments.any? {|c| c.user == @katrina})
# 
#     summary = 'Test summary'
#     message = 'This is a big fat test!'
#     message2 = 'This may be _Xylaria polymorpha_, no?'
# 
#     # Start by showing the observation...
#     get("/#{obs.id}")
# 
#     # (Make sure there are no edit or destroy controls on existing comments.)
#     assert_select('a[href*=edit_comment], a[href*=destroy_comment]', false)
# 
#     click_on(:label => 'Add Comment', :in => :tabs)
#     assert_template('account/login')
#     current_session.login!('katrina')
#     assert_template('comment/add_comment')
# 
#     # (Make sure the form is for the correct object!)
#     assert_objs_equal(obs, assigns(:object))
#     # (Make sure there is a tab to go back to show_observation.)
#     assert_select("div.tab_sets a[href=/#{obs.id}]")
# 
#     do_form('form[action*=add_comment]') do |form|
#       form.submit
#     end
#     assert_template('comment/add_comment')
#     # (I don't care so long as it says something.)
#     assert_flash(/\S/)
# 
#     do_form('form[action*=add_comment]') do |form|
#       form.edit_field('summary', summary)
#       form.edit_field('comment', message)
#       form.submit
#     end
#     assert_template('observer/show_observation')
#     assert_objs_equal(obs, assigns(:observation))
# 
#     com = Comment.last
#     assert_equal(summary, com.summary)
#     assert_equal(message, com.comment)
# 
#     # (Make sure comment shows up somewhere.)
#     assert_match(summary, response.body)
#     assert_match(message, response.body)
#     # (Make sure there is an edit and destroy control for the new comment.)
#     assert_select("a[href*=edit_comment/#{com.id}]", 1)
#     assert_select("a[href*=destroy_comment/#{com.id}]", 1)
# 
#     # Try changing it.
#     click_on(:label => /edit/i, :href => /.*edit_comment/)
#     assert_template('comment/edit_comment')
#     do_form('form[action*=edit_comment]') do |form|
#       form.assert_value('summary', summary)
#       form.assert_value('comment', message)
#       form.edit_field('comment', message2)
#       form.submit
#     end
#     assert_template('observer/show_observation')
#     assert_objs_equal(obs, assigns(:observation))
# 
#     com.reload
#     assert_equal(summary, com.summary)
#     assert_equal(message2, com.comment)
# 
#     # (Make sure comment shows up somewhere.)
#     assert_match(summary, response.body)
#     assert(response.body.index(message2.tl))
#     # (There should be a link in there to look up Xylaria polymorpha.)
#     assert_select('a[href*=lookup_name]', 1) do |links|
#       url = links.first.attributes['href']
#       assert_equal("#{HTTP_DOMAIN}/observer/lookup_name/Xylaria%20polymorpha",
#                    url)
#     end
# 
#     # I grow weary of this comment.
#     click_on(:label => /destroy/i, :href => /.*destroy_comment/)
#     assert_template('observer/show_observation')
#     assert_objs_equal(obs, assigns(:observation))
#     assert_nil(response.body.index(summary))
#     assert_select('a[href*=edit_comment], a[href*=destroy_comment]', false)
#     assert_nil(Comment.safe_find(com.id))
#   end
# 
#   def test_proposing_names
#     katrina = current_session
#     obs = observations(:detailed_unknown)
#     # (Make sure Katrina doesn't own any comments on this observation yet.)
#     assert_false(obs.comments.any? {|c| c.user == @katrina})
#     # (Make sure the name we are going to suggest doesn't exist yet.)
#     text_name = 'Xylaria polymorpha'
#     assert_nil(Name.find_by_text_name(text_name))
#     fungi = obs.name
# 
#     # Start by showing the observation...
#     get("/#{obs.id}")
# 
#     # (Make sure there are no edit or destroy controls on existing namings.)
#     assert_select('a[href*=edit_naming], a[href*=destroy_naming]', false)
# 
#     click_on(:label => /propose.*name/i)
#     assert_template('account/login')
#     current_session.login!(@katrina)
#     assert_template('observer/create_naming')
# 
#     # (Make sure the form is for the correct object!)
#     assert_objs_equal(obs, assigns(:observation))
#     # (Make sure there is a tab to go back to show_observation.)
#     assert_select("div.tab_sets a[href=/#{obs.id}]")
# 
#     do_form('form[action*=create_naming]') do |form|
#       form.assert_value('reason_1_check', false)
#       form.assert_value('reason_2_check', false)
#       form.assert_value('reason_3_check', false)
#       form.assert_value('reason_4_check', false)
#       form.submit
#     end
#     assert_template('observer/create_naming')
#     # (I don't care so long as it says something.)
#     assert_flash(/\S/)
# 
#     do_form('form[action*=create_naming]') do |form|
#       form.edit_field('name', text_name)
#       form.submit
#     end
#     assert_template('observer/create_naming')
#     assert_select('div.Errors') do |elems|
#       assert_block('Expected error about name not existing yet.') do
#         elems.any? {|e| e.to_s.match(/#{text_name}.*not recognized/i)}
#       end
#     end
# 
#     do_form('form[action*=create_naming]') do |form|
#       # Re-submit to accept name.
#       form.submit
#     end
#     assert_template('observer/create_naming')
#     assert_flash(/confidence/i)
# 
#     do_form('form[action*=create_naming]') do |form|
#       form.assert_value('name', text_name)
#       form.assert_value('reason_1_check', false)
#       form.assert_value('reason_2_check', false)
#       form.assert_value('reason_3_check', false)
#       form.assert_value('reason_4_check', false)
#       form.select(/vote/, /call it that/i)
#       form.submit
#     end
#     assert_template('observer/show_observation')
#     assert_flash(/success/i)
#     assert_objs_equal(obs, assigns(:observation))
# 
#     obs.reload
#     name = Name.find_by_text_name(text_name)
#     naming = Naming.last
#     assert_names_equal(name, naming.name)
#     assert_names_equal(name, obs.name)
#     assert_equal('', name.author.to_s)
# 
#     # (Make sure naming shows up somewhere.)
#     assert_match(text_name, response.body)
#     # (Make sure there is an edit and destroy control for the new naming.)
#     assert_select("a[href*=edit_naming/#{naming.id}]", 1)
#     assert_select("a[href*=destroy_naming/#{naming.id}]", 1)
# 
#     # Try changing it.
#     author = '(Pers.) Grev.'
#     reason = 'Test reason.'
#     click_on(:label => /edit/i, :href => /.*edit_naming/)
#     assert_template('observer/edit_naming')
#     do_form('form[action*=edit_naming]') do |form|
#       form.assert_value('name', text_name)
#       form.edit_field('name', "#{text_name} #{author}")
#       form.edit_field('reason_2_check', true)
#       form.edit_field('reason_2_notes', reason)
#       form.submit
#     end
#     assert_template('observer/show_observation')
#     assert_objs_equal(obs, assigns(:observation))
# 
#     obs.reload
#     name.reload
#     naming.reload
#     assert_equal(author, name.author)
#     assert_names_equal(name, naming.name)
#     assert_names_equal(name, obs.name)
# 
#     # (Make sure author shows up somewhere.)
#     assert_match(author, response.body)
#     # (Make sure reason shows up, too.)
#     assert_match(reason, response.body)
# 
#     click_on(:label => /edit/i, :href => /.*edit_naming/)
#     assert_template('observer/edit_naming')
#     do_form('form[action*=edit_naming]') do |form|
#       form.assert_value('name', "#{text_name} #{author}")
#       form.assert_value('reason_1_check', true)
#       form.assert_value('reason_1_notes', '')
#       form.assert_value('reason_2_check', true)
#       form.assert_value('reason_2_notes', reason)
#       form.assert_value('reason_3_check', false)
#       form.assert_value('reason_3_notes', '')
#     end
#     click_on(:label => /cancel.*show/i)
# 
#     # Have Rolf join in the fun and vote for this naming.
#     rolf = login!(@rolf)
#     get("/#{obs.id}")
#     do_form("form[action=/#{obs.id}]") do |form|
#       form.assert_value("vote_#{naming.id}_value", 0)
#       form.select("vote_#{naming.id}_value", /call it that/i)
#       form.submit
#     end
#     assert_template('observer/show_observation')
#     assert_match(/call it that/i, response.body)
# 
#     # Now Katrina shouldn't be allowed to delete her naming.
#     self.current_session = katrina
#     click_on(:label => /destroy/i, :href => /.*destroy_naming/)
#     assert_flash(/sorry/i)
# 
#     # Have Rolf change his mind.
#     self.current_session = rolf
#     do_form("form[action=/#{obs.id}]") do |form|
#       form.select("vote_#{naming.id}_value", /as if!/i)
#       form.submit
#     end
# 
#     # Now Katrina *can* delete it.
#     self.current_session = katrina
#     click_on(:label => /destroy/i, :href => /.*destroy_naming/)
#     assert_template('observer/show_observation')
#     assert_objs_equal(obs, assigns(:observation))
#     assert_flash(/success/i)
# 
#     # And that's that!
#     obs.reload
#     assert_names_equal(fungi, obs.name)
#     assert_nil(Naming.safe_find(naming.id))
#     assert_not_match(text_name, response.body)
#   end

  def test_posting_observation
    get_with_error_checking('/observer/create_observation')
    assert_template('account/login')
    login!(@katrina)
    assert_template('observer/create_observation')

  end
end
