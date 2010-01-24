#
#  = MO Test Suites
#
#  This is the "boot" script for out unit tests.  The important sequence is:
#
#  1) Set environment to "TEST".
#  2) Run config/environment.rb, booting our application and rails.
#  3) Include the rails test extensions (test_help).
#  4) Include out own core extensions (everything else is auto-loaded).
#  5) Load our own test extensions (test_case and controller_test_case).
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
#  action_controller/integration::  ...
#  action_mailer/test_case::        ...
#  active_support/core_ext/test::   ...
#
#  == MO Test Cases
#
#  MO::TestCase::             Generic test case with all our extensions added to it.
#  MO::Model::TestCase::      Test case for models (same as MO::TestCase for now).
#  MO::Controller::TestCase:: Test case for controllers (derives from ActionController::TestCase).
#
#  == Note on New File Name
#
#  This file used to be called +test_helper.rb+, however it turns out that rake
#  would include it once, while all our test units were including it a second
#  time.  We _must_ do the latter, because that's how this file gets included
#  when running tests individually from the command line:
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
require File.expand_path(File.dirname(__FILE__) + '/test_case')
require File.expand_path(File.dirname(__FILE__) + '/controller_test_case')

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

