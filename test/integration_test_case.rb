# encoding: utf-8
#
#  = Integration Test Case
#
#  The test case class that all integration tests currently derive from.
#  Includes:
#
#    class YourTest < IntegrationTestCase
#
#      # Most basic test doesn't even need to know about session: all session methods
#      # are automatically delegated to a default session created at setup.
#      def test_simplest
#        get('/controller/action?args=...')
#        assert_template('controller/action')
#        click(:label => 'Post Comment')
#        open_form do |form|
#          form.edit_field('message', 'This is a test.')
#          form.submit('Post')
#        end
#      end
#
#      # More complicated session management.
#      def test_multiple_session
#
#        # Create two sessions: think "browser" - each session represents the
#        # actions of a single user in one or more tabs of a single browser.
#        rolf = login!('rolf')
#        mary = login!('mary')
#
#        # Have Rolf do some stuff.
#        rolf.get('/edit_rolfs_stuff')
#        rolf.assert_success
#
#        # Have Mary do stuff.
#        mary.get('/edit_rolfs_stuff')
#        mary.assert_redirect
#
#        # You can also create anonymous sessions.
#        open_session do
#          get('/show_index')
#          assert_select('span', :text => 'Rolfs Thing', :count => 0)
#        end
#      end
#    end
#
################################################################################

class IntegrationTestCase < ActionDispatch::IntegrationTest # Test::Unit::TestCase
  include SessionExtensions
  include FlashExtensions
  include GeneralExtensions

  # Important to allow integration tests test the CSRF stuff to avoid unpleasant
  # surprises in production mode.
  def setup
    ApplicationController.allow_forgery_protection = true
  end
  def teardown
    ApplicationController.allow_forgery_protection = false
  end

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
