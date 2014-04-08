# encoding: utf-8
#
#  = Base Test Case
#
#  Does some basic site-wide configuration for all the tests.  This is part of
#  the base class that all unit tests must derive from.
#
#  *NOTE*: This must go directly in Test::Unit::TestCase because of how Rails
#  tests work. 
#
################################################################################

ENV["RAILS_ENV"] = "test"
require File.expand_path(File.dirname(__FILE__) + "/../config/environment")
require 'test_help'

class ActiveSupport::TestCase
  # Transactional fixtures accelerate your tests by wrapping each test method
  # in a transaction that's rolled back on completion.  This ensures that the
  # test database remains unchanged so your fixtures don't have to be reloaded
  # between every test method.  Fewer database queries means faster tests.
  #
  # Read Mike Clark's excellent walkthrough at
  #   http://clarkware.com/cgi/blosxom/2005/10/24#Rails10FastTesting
  #
  # Every Active Record database supports transactions except MyISAM tables
  # in MySQL.  Turn off transactional fixtures in this case; however, if you
  # don't care one way or the other, switching from MyISAM to InnoDB tables
  # is recommended.
  #
  # The only drawback to using transactional fixtures is when you actually 
  # need to test transactions.  Since your test is bracketed by a transaction,
  # any transactions started in your code will be automatically rolled back.
  self.use_transactional_fixtures = true

  # Instantiated fixtures are slow, but give you @david where otherwise you
  # would need people(:david).  If you don't want to migrate your existing
  # test cases which use the @david style and don't mind the speed hit (each
  # instantiated fixtures translates to a database query per test method),
  # then set this back to true.
  self.use_instantiated_fixtures  = false

  # Setup all fixtures in test/fixtures/*.(yml|csv) for all tests in alphabetical order.
  #
  # Note: You'll currently still have to declare fixtures explicitly in integration tests
  # -- they do not yet inherit this setting
  fixtures :all

  # Add more helper methods to be used by all tests here...

  # Standard setup to run before every test.  Sets the locale, timezone,
  # and makes sure User doesn't think a user is logged in.
  def application_setup
    I18n.locale = :'en' if I18n.locale != :'en'
    Time.zone = 'America/New_York'
    User.current = nil
  end

  # Standard teardown to run after every test.  Just makes sure any
  # images that might have been uploaded are cleared out.
  def application_teardown
    if File.exists?(IMG_DIR)
      FileUtils.rm_rf(IMG_DIR)
    end
  end
end
