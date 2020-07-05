# frozen_string_literal: true

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

# Code to allow both local and coveralls coverage.  From:
# https://coveralls.zendesk.com/hc/en-us/articles/201769485-Ruby-Rails
require "rails"
require "simplecov"
require "coveralls"

# Coveralls.wear!("rails")
formatters = [SimpleCov::Formatter::HTMLFormatter,
              Coveralls::SimpleCov::Formatter]
SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new(formatters)
SimpleCov.start

# Allow test results to be reported back to runner IDEs.
# Enable progress bar output during the test running.
require "minitest/reporters"
MiniTest::Reporters.use!

require "minitest/autorun"

# Allow stubbing and setting expectations on HTTP, and selective
#  disabling of internet requests.
require "webmock/minitest"

# Disable external requests while allowing localhost
WebMock.disable_net_connect!(allow_localhost: true)

ENV["RAILS_ENV"] ||= "test"
require File.expand_path("../config/environment", __dir__)
require "rails/test_help"

# Enable mocking and stubbing in Ruby (must be required after rails/test_help).
require "mocha/minitest"

%w[
  general_extensions
  flash_extensions
  controller_extensions
  integration_extensions
  language_extensions
  session_extensions
  session_form_extensions

  check_for_unsafe_html
  uploaded_string

  unit_test_case
  functional_test_case
  integration_test_case
].each do |file|
  require File.expand_path(File.dirname(__FILE__) + "/#{file}")
end

# Allow simuluation of user-browser interaction with capybara
require "capybara/rails"

I18n.enforce_available_locales = true

module ActiveSupport
  class TestCase
    ##########################################################################
    #  Transactional fixtures
    ##########################################################################
    # Transactional fixtures accelerate your tests by wrapping each
    # test method in a transaction that's rolled back on completion.
    # This ensures that the test database remains unchanged so your
    # fixtures don't have to be reloaded between every test method.
    # Fewer database queries means faster tests.
    #
    # Read Mike Clark's excellent walkthrough at
    #   http://clarkware.com/cgi/blosxom/2005/10/24#Rails10FastTesting
    #
    # Every Active Record database supports transactions except MyISAM
    # tables in MySQL.  Turn off transactional fixtures in this case;
    # however, if you don't care one way or the other, switching from
    # MyISAM to InnoDB tables is recommended.
    #
    # The only drawback to using transactional fixtures is when you
    # actually need to test transactions.  Since your test is
    # bracketed by a transaction, any transactions started in your
    # code will be automatically rolled back.
    self.use_transactional_tests = true

    # Instantiated fixtures are slow, but give you @david where
    # otherwise you would need people(:david).  If you don't want to
    # migrate your existing test cases which use the @david style and
    # don't mind the speed hit (each instantiated fixtures translates
    # to a database query per test method), then set this back to
    # true.
    self.use_instantiated_fixtures = false
    ##########################################################################

    # Setup all fixtures in test/fixtures/*.(yml|csv) for all tests in
    # alphabetical order.
    #
    # Note: You'll currently still have to declare fixtures explicitly
    # in integration tests -- they do not yet inherit this setting
    self.set_fixture_class locations: Location # I added. necessary? - AN
    self.set_fixture_class 'locations/descriptions' => Location::Description
    self.set_fixture_class names: Name # I added. necessary? - AN
    self.set_fixture_class 'names/descriptions' => Name::Description
    fixtures :all

    # Add more helper methods to be used by all tests here...

    # Standard setup to run before every test.  Sets the locale, timezone,
    # and makes sure User doesn't think a user is logged in.
    def setup
      I18n.locale = :en if I18n.locale != :en
      Time.zone = "America/New_York"
      User.current = nil
      start_timer if false
      clear_logs unless defined?(@@cleared_logs)
      Symbol.missing_tags = []
    end

    # Standard teardown to run after every test.  Just makes sure any
    # images that might have been uploaded are cleared out.
    def teardown
      assert_equal([], Symbol.missing_tags, "Language tag(s) are missing.")
      FileUtils.rm_rf(MO.local_image_files)
      UserGroup.clear_cache_for_unit_tests
      stop_timer if false
    end

    # Record time this test started to run.
    def start_timer
      @@times = {} unless defined?(@@times)
      @@times[method_name] = Time.zone.now
    end

    # Report time this test took to run.
    def end_timer
      ellapsed = Time.zone.now - @@times[method_name]
      puts "\rTIME: #{ellapsed}\t#{self.class.name}::#{method_name}"
    end

    # This will ensure that the logs stay a reasonable size.  If you forget to
    # clear these logs periodically, they can get freaking huge, and that
    # causes this test to take up to several minutes to complete.
    def clear_logs
      %w[development test email-debug process_image].each do |file|
        file = Rails.root.join("log", "#{file}.log")
        next unless File.exist?(file)

        File.truncate(file, 0)
      end
      @@cleared_logs = true
    end
  end
end

# Make the Capybara DSL available in all integration tests
module ActionDispatch
  class IntegrationTest
    include Capybara::DSL
  end
end
