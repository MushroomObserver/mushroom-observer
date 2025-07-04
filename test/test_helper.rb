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

# Code to allow Coveralls exor local coverage reports.  See:
# https://github.com/coverallsapp/github-action/issues/29#issuecomment-701934460
require("rails")
require("simplecov")
require("simplecov-lcov")

module SimpleCov
  class SourceFile
    # 2025-04-11 jdc Monkeypatch to disable excessive coverage warnings.
    # Else we get > 100 false positives because we enabled
    # coverage for .erb files.
    def coverage_exceeding_source_warn
      return unless ENV["SHOW_EXCESS_LINE_WARNING"]

      message = <<~WARNING
        Warning: coverage data provided by Coverage
        [#{coverage_data["lines"].size}]
        exceeds number of lines in #{filename} [#{src.size}]
      WARNING
      warn(message)
    end
  end
end

if ENV["CI"] == "true"
  SimpleCov::Formatter::LcovFormatter.config do |config|
    config.report_with_single_file = true
    config.lcov_file_name = "lcov.info"
  end

  SimpleCov.formatter = SimpleCov::Formatter::LcovFormatter
else
  SimpleCov.formatter = SimpleCov::Formatter::HTMLFormatter
end

SimpleCov.start("rails") do
  # Cover .erb files. https://github.com/simplecov-ruby/simplecov/pull/1037
  enable_coverage_for_eval
end

# Allow test results to be reported back to runner IDEs.
# Enable progress bar output during the test running.
require("minitest/reporters")
Minitest::Reporters.use!

require("minitest/autorun")

# Allow stubbing and setting expectations on HTTP, and selective
#  disabling of internet requests.
require("webmock/minitest")

# Disable external requests while allowing localhost.
WebMock.disable_net_connect!(
  allow_localhost: true,
  allow: [
    "chromedriver.storage.googleapis.com", # in case we install Chrome
    "github.com", # for Firefox
    "objects.githubusercontent.com" # for Firefox
  ]
)

ENV["RAILS_ENV"] ||= "test"
require_relative("../config/environment")
require("rails/test_help")

%w[
  bullet_helper

  general_extensions
  flash_extensions
  controller_extensions
  capybara_session_extensions
  capybara_macros
  language_extensions
  session_extensions
  session_form_extensions

  check_for_unsafe_html
  uploaded_string

  unit_test_case
  functional_test_case
  integration_test_case
  capybara_integration_test_case
].each do |file|
  require_relative(file)
end

I18n.enforce_available_locales = true

# Function for creating a log (trace_tests.out) of the tests called
# that somehow call this function.
def trace_tests
  regex = %r{/test/}
  matches = caller.grep(regex)
  return unless matches

  last_match = matches.last
  trim = last_match[(last_match.index(regex) + 1)..]
  open("trace_tests.out", "a") do |f|
    f.write("#{trim}\n")
  end
end

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    # parallelize(workers: :number_of_processors)

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
    # code will be automatically rolled back. Defaults to true.
    self.use_transactional_tests = true

    # Instantiated fixtures are slow, but give you @david where
    # otherwise you would need people(:david).  If you don't want to
    # migrate your existing test cases which use the @david style and
    # don't mind the speed hit (each instantiated fixtures translates
    # to a database query per test method), then set this back to
    # true. Defaults to false.
    self.use_instantiated_fixtures = false
    ##########################################################################

    # Setup all fixtures in test/fixtures/*.(yml|csv) for all tests in
    # alphabetical order.
    #
    # Note: You'll currently still have to declare fixtures explicitly
    # in integration tests -- they do not yet inherit this setting
    fixtures :all

    # Add more helper methods to be used by all tests here...

    # Standard setup to run before every test.  Sets the locale, timezone,
    # and makes sure User doesn't think a user is logged in.
    def setup
      # Disable cop; there's no block in which to limit the time zone change
      I18n.locale = :en if I18n.locale != :en # rubocop:disable Rails/I18nLocaleAssignment
      # Disable cop; there's no block in which to limit the time zone change
      Time.zone = "America/New_York" # rubocop:disable Rails/TimeZoneAssignment
      User.current = nil
      clear_logs unless defined?(@@cleared_logs)
      Symbol.missing_tags = []
    end

    # Standard teardown to run after every test.  Just makes sure any
    # images that might have been uploaded are cleared out.
    def teardown
      assert_equal([], Symbol.missing_tags, "Language tag(s) are missing.")
      FileUtils.rm_rf(MO.local_image_files)
      UserGroup.clear_cache_for_unit_tests
    end

    # Record time this test started to run.
    def start_timer
      @@times = {} unless defined?(@@times)
      @@times[method_name] = Time.zone.now
    end

    # Report time this test took to run.
    def end_timer
      ellapsed = Time.zone.now - @@times[method_name]
      puts("\rTIME: #{ellapsed}\t#{self.class.name}::#{method_name}")
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
