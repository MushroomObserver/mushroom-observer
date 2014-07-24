# encoding: utf-8
#
#  = Integration Test Case
#
#  The test case class that all integration tests currently derive from.
#  Includes:
#
#  1. A few high-level helpers for logging in users, etc.
#
#  The vast majority of the "action" happens at the session level.  Please
#  see IntegrationSession and SessionExtensions for more documentation.
#
#  == Differences With Rails's Version
#
#  This is a 100% rewrite of the (minimal) ActionController::IntegrationTest.
#  Both this and Rails's version allow for multiple session to be opened
#  simultaneously.  The primary difference is that Rails's caches the results
#  of queries... sometimes.  This version makes it more explicit, and tries to
#  delegate *all* methods to the appropriate session without relying on caches
#  at all.  See the comments below +method_missing+ for more information.
#
#  All the same assertions and helpers are available to this test case as were
#  available under Rails's.  A default session is still automatically opened in
#  +setup+ in case you don't really care about managing sessions explicitly.
#  There is still the concept of a "default" or "current" session, allowing
#  you to call methods directly on +self+ in your unit integration tests without
#  explicitly stating which session you mean for every single assertion and
#  action.
#
#  However, our version allows you to explicitly set which session is current.
#  It allows you to change the cookies and session directly.  It will never get
#  "out of sync" if you mix direct and indirect calls on the current session.
#  And it won't (to within reason!) silently screw up if you accidentally
#  forget to specify the session.  Lastly, it instantiates sessions as a
#  subclass of ActionController::Integration::Session called (very creatively)
#  IntegrationSession -- something Rails's integration test case wouldn't allow
#  us to do, either.
#
#  == Simple Example
#
#  class YourTest < IntegrationTestCase
#
#    # Most basic test doesn't even need to know about session: all session methods
#    # are automatically delegated to a default session created at setup.
#    def test_simplest
#      get('/controller/action?args=...')
#      assert_template('controller/action')
#      click(:label => 'Post Comment')
#      open_form do |form|
#        form.edit_field('message', 'This is a test.')
#        form.submit('Post')
#      end
#    end
#
#    # More complicated session management.
#    def test_multiple_session
#
#      # Create two sessions: think "browser" - each session represents the
#      # actions of a single user in one or more tabs of a single browser.
#      rolf = new_session
#      mary = login!('mary')
#
#      # Have Rolf do some stuff.
#      rolf.login!('rolf')
#      rolf.get('/edit_rolfs_stuff')
#      rolf.assert_success
#
#      # Have Mary do stuff.
#      mary.get('/edit_rolfs_stuff')
#      mary.assert_redirect
#
#      # Bind a block of code to a given session.
#      in_session(rolf) do
#        click(:label => 'Destroy It')
#        assert_flash_success
#      end
#
#      # You can also create anonymous sessions.
#      open_session do
#        get('/show_index')
#        assert_select('span', :text => 'Rolfs Thing', :count => 0)
#      end
#
#      # Lastly, you can nest things.
#      in_session(rolf) do
#        get('/rolfs_page')
#        mary.get('marys_page')
#        open_session do
#          login('dick')
#          in_session('mary')
#            get('/mary_is_now_confused')
#          end
#          logout # dick
#        end
#        post('/rolfs_page')
#      end
#    end
#  end
#
################################################################################

class IntegrationTestCase < ActionDispatch::IntegrationTest # Test::Unit::TestCase
  include SessionExtensions
  include FlashExtensions
  include GeneralExtensions

  def login(login, password='testpassword', remember_me=true)
    login = login.login if login.is_a?(User)
    open_session do |sess|
      sess.get('/account/login')
      sess.open_form do |form|
        form.change('login', login)
        form.change('password', password)
        form.change('remember_me', remember_me)
        form.submit('Login')
      end
      sess
    end
  end

  # Login the given user, testing to make sure it was successful.
  def login!(user, *args)
    sess = login(user, *args)
    sess.assert_flash(/success/i)
    user = User.find_by_login(user) if user.is_a?(String)
    assert_users_equal(user, sess.assigns(:user), "Wrong user ended up logged in!")
    sess
  end
end
