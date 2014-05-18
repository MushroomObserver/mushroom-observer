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
#      mary = new_user_session('mary')
#
#      # Have Rolf do some stuff.
#      rolf.login!('rolf')
#      rolf.get('/edit_rolfs_stuff')
#      rolf.assert_success
#
#      # Mave Mary do stuff.
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

class IntegrationTestCase < ActionController::IntegrationTest # Test::Unit::TestCase
  include IntegrationExtensions

  attr_accessor :current_session

  # Open a default session.
  def setup
    @current_session = new_session
  end

  # Instantiate a new session.
  def new_session
    session = IntegrationSession.new
    session.test_case = self
    return session
  end

  # Instantiate a new session with user already logged in.
  def new_user_session(user)
    session = new_session
    session.login!(user)
    return session
  end

  # Run an enclosed block of code in a temporary, new session.
  def open_session
    old_session = @current_session
    @current_session = new_session
    result = yield @current_session
    @current_session = old_session
    return result
  end

  # Bind all the actions in the enclosed block of code to another session.
  def in_session(another_session)
    old_session = @current_session
    @current_session = another_session
    result = yield @current_session
    @current_session = old_session
    return result
  end

  # Automatically delegate everything we don't recognize to the current session.
  def method_missing(name, *args, &block)
    @current_session.send(name, *args, &block)
  end

  # Rails has polluted Test::Unit::TestCase with dozens of methods.  We need to
  # override them to get them to delegate properly to the session.  I've tried
  # everything to do this more elegantly, but there is just no choice.  The key
  # problem is that if you ever call a method directly on a session instance,
  # the changes won't be reflected in the parent test case, which is the cause
  # of never-ending headaches.  So here I remove by hand all methods that can
  # potentially be confused between the two and force them instead to delegate
  # to the session instead of running off of cached instance variables in the
  # test case.
  for method in %w(
      assert_template assert_response assert_redirected_to
      assert_generates assert_routing
      assert_tag assert_no_tag
      assert_select assert_select_email assert_select_encoded assert_select_rjs
      assigns cookies flash session
      get post put delete head process
      xhr xml_http_request redirect_to_url
      find_tag find_all_tag css_select html_document
    )
    class_eval <<-EOV, __FILE__, __LINE__
      def #{method}(*args, &block)
        @current_session.send(:#{method}, *args, &block)
      end
    EOV
  end
end
