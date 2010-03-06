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
#    # Most basic test doesn't even need to know about session.
#    def test_simplest
#      get('/controller/action?args=...')
#      assert_template('controller/action')
#      click_on(:label => 'Post Comment')
#      do_form('form.comment') do |form|
#        form.edit_field('message', 'This is a test.')
#        form.submit('Post')
#      end
#    end
#
#    # More complicated session management.
#    def test_multiple_session
#
#      # Rolf's session is current throughout the block.
#      rolf = open_session do
#        get('/login')
#        do_form('form.login') do
#          form.edit_field('login', 'rolf')
#          form.edit_field('password', 'password')
#          form.submit('Login')
#        end
#      end
#
#      # Now create Mary's session; it becomes current.
#      mary = login('mary')
#
#      # The following are identical since Mary's is current.
#      get('/index')
#      mary.get('/index')
#
#      # All assertions and helpers automatically get delegated to the current
#      # session by default.  (This asserts that there are at least 10
#      # "show_object" links on the last page Mary requested.)
#      assert_select('a[href*=show_object]', :minimum => 10)
#
#      # Addressing session explicitly helps when mixing queries.
#      mary.get('/show_object/1')
#      rolf.get('/show_object/2')
#      mary.logout
#
#      # Now that Mary is gone, we can make Rolf's "current".
#      current_session = rolf
#      get('/show_object/3')
#      ...
#    end
#  end
#
################################################################################

class IntegrationTestCase < Test::Unit::TestCase
  include IntegrationExtensions

  attr_accessor :current_session

  # Open a default session.
  def setup
    open_session
  end

  # Instantiate a new session.
  def new_session
    IntegrationSession.new
  end

  # Open new session.  I've redefined this instead of using
  # ActionController::IntegrationTest because I could not figure out which
  # session it was using at any given time.  This makes it more explicit.
  def open_session
    @current_session = new_session
    @current_session.test_case = self
    yield @current_session if block_given?
    @current_session
  end

  # Automatically delegate everything we don't recognize to the current
  # session.
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

################################################################################
#
# These are additional methods that Rails adds to Test::Unit::TestCase,
# either directly or indirectly:
#
#   Boolean
#   _stacktrace
#   `
#   acts_like?
#   assert_deprecated
#   assert_difference
#   assert_dom_equal
#   assert_dom_not_equal
#   assert_emails
#   assert_no_difference
#   assert_no_emails
#   assert_not_deprecated
#   assert_recognizes
#   assert_valid
#   blank?
#   breakpoint
#   build_request_uri
#   clean_backtrace
#   copy_instance_variables_from
#   count_description
#   daemonize
#   dclone
#   debugger
#   decode_b
#   duplicable?
#   enable_warnings
#   enum_for
#   extend_with_included_modules_from
#   extended_by
#   fixture_class_names
#   fixture_class_names?
#   fixture_file_upload
#   fixture_path
#   fixture_path?
#   fixture_table_names
#   fixture_table_names?
#   follow_redirect
#   follow_redirect_with_deprecation
#   follow_redirect_without_deprecation
#   html_escape
#   instance_exec
#   instance_values
#   instance_variable_names
#   load
#   method_missing
#   pre_loaded_fixtures
#   pre_loaded_fixtures?
#   remove_subclasses_of
#   require
#   require_association
#   require_dependency
#   require_library_or_gem
#   require_or_load
#   response_from_page_or_rjs
#   returning
#   run_callbacks
#   run_with_callbacks
#   run_with_callbacks_and_mocha
#   run_without_callbacks
#   send!
#   setup_fixtures
#   silence_stderr
#   silence_stream
#   silence_warnings
#   subclasses_of
#   suppress
#   taguri
#   taguri=
#   teardown_fixtures
#   to_enum
#   to_json
#   to_param
#   to_query
#   to_yaml
#   to_yaml_properties
#   to_yaml_style
#   unescape_rjs
#   unloadable
#   use_instantiated_fixtures
#   use_instantiated_fixtures?
#   use_transactional_fixtures
#   use_transactional_fixtures?
#   with_options
#   with_routing
