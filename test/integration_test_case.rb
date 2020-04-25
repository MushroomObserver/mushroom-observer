# frozen_string_literal: true

#  = Integration Test Case
#
#  The test case class that all integration tests currently derive from.
#  Includes:
#
#    class YourTest < IntegrationTestCase
#
#      # Most basic test doesn't even need to know about session: all session
#      # methods are automatically delegated to a default session created at
#      # setup.
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

class IntegrationTestCase < ActionDispatch::IntegrationTest
  include GeneralExtensions
  include SessionExtensions
  include FlashExtensions
  include IntegrationExtensions

  # Important to allow integration tests test the CSRF stuff to avoid unpleasant
  # surprises in production mode.
  def setup
    ApplicationController.allow_forgery_protection = true

    # This should be automatically removed at the beginning of each test,
    # but for some reason it is not nil before the very first test run.
    # If it is not removed, then all sessions opened in your test will have
    # the identical session instance, breaking some tests. This is probably
    # a bug in rails, but as of 20190101 it is required.
    @integration_session = nil

    # Treat Rails html requests as coming from non-robots.
    # If it's a bot, controllers often do not serve the expected content.
    # The requester looks like a bot to the `browser` gem because the User Agent
    # in the request is blank. I don't see an easy way to change that. -JDC
    Browser::Generic.any_instance.stubs(:bot?).returns(false)
  end

  def teardown
    ApplicationController.allow_forgery_protection = false
  end
end
