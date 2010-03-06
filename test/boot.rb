#
#  = MO Test Suites
#
#  This is the "boot" script for out unit tests.  The important sequence is:
#
#  1) Set environment to "TEST".
#  2) Run config/environment.rb, booting our application and rails.
#  3) Include the rails test extensions (test_help).
#  4) Include out own core extensions (everything else is auto-loaded).
#  5) Load our own test cases and extensions (all the files in this directory).
#  6) Test::Unit magically runs everything in an +atexit+ hook.
#
#  It is, furthermore, worth knowing how and where rails meddles with the
#  standard Test::Unit process.  Its extensions are scattered among all the
#  "frameworks":
#
#  active_support/test_case::       Adds +setup+ and +teardown+ callback support.
#  active_record/fixtures::         Adds +fixtures+ support.
#  action_controller/test_case::    Adds a handy +setup+ callback.
#  action_controller/test_process:: Defines fake request and response classes and much more.
#  action_controller/integration::  Very confusing mix of Session and TestCase, I'm stumped.
#  action_mailer/test_case::        ...
#  active_support/core_ext/test::   ...
#
#  == MO Test Cases
#
#  UnitTestCase::        Used by unit tests, just derives from Test::Unit::TestCase.
#  FunctionalTestCase::  Used by functional tests, derives from ActionController::TestCase.
#  IntegrationTestCase:: Used by integration tests, similar to ActionController::IntegrationTest.
#  IntegrationSession::  Used by integration tests, derived from ActionController::Integration::Session
#
#  == MO Test Extensions
#
#  GeneralExtensions::     Generally useful MO-specific assertions.
#  ControllerExtensions::  Several additional helpers used by functional tests.
#  FlashExtensions::       Encapsulates flash error mechanism (used by functional and integration tests).
#  IntegrationExtensions:: Some high-level integration test helpers.
#  SessionExtensions::     Several very handy extensions to the Rails integration tester.
#
#  == Notes
#
#  The Rails integration test case did not allow us to subclass the test
#  session class, and did not give us proper control over things like cookies.
#  So I've rewritten it minimally.  It did very little to start with, so this
#  was actually the easiest way to go.  See the notes on IntegrationTestCase
#  for better documentation of the (few) differences.
#
#  Beware, Rails has polluted Test::Unit::TestCase with a bunch of
#  controller-related stuff.  This all comes from ActionController::TestProcess
#  module.
#
#  Also note that this file used to be called +test_helper.rb+.  However it
#  turns out that rake would include it once, while all our test units were
#  including it a second time.  We _must_ do the latter, because that's how
#  this file gets included when running tests individually from the command
#  line: 
#
#    ruby -Ilib:test test/units/api_test.rb
#
#  Ergo, the former must go.  Thus, I renamed it to something rake doesn't know
#  about.  The problem was it was registering our application-wide setup and
#  teardown callbacks twice, with highly erratic and unpleasant results.
#
################################################################################

ENV['RAILS_ENV'] = 'test'
require File.expand_path(File.dirname(__FILE__) + '/../config/environment')
require 'test_help'
require 'extensions'

# Load all of our test cases and extensions.
for file in %w(
  general_extensions
  flash_extensions
  controller_extensions
  integration_extensions
  session_extensions
  test_case
  unit_test_case
  functional_test_case
  integration_test_case
  integration_session
)
  require File.expand_path(File.dirname(__FILE__) + "/#{file}")
end

# Used to test image uploads.  The normal "live" params[:upload] is
# essentially a file with a "content_type" field added to it.  This is
# meant to take its place.
class FilePlus < File
  attr_accessor :content_type
  def size
    File.size(path)
  end
end

# Create subclasses of StringIO that has a content_type member to replicate the
# dynamic method addition that happens in Rails cgi.rb.
class StringIOPlus < StringIO
  attr_accessor :content_type
end

# Re-raise errors caught by the controller.
class ApplicationController; def rescue_action(e) raise e end; end

