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

# SimpleCov runs by default in parallel mode
require("simplecov")
require("simplecov-lcov")

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
  # An always empty file which is always reported as a coverage decrease
  add_filter("/channels/application_cable/channel.rb")

  # Custom RuboCop cops are lint-time tooling — loaded and exercised by
  # RuboCop, never by the Rails test suite. The "rails" profile's
  # track_files("{app,lib}/**/*.rb") otherwise pulls them into the report
  # as a permanent ~0% coverage drag.
  add_filter("/lib/rubocop/")
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
  component_test_case
  mailer_test_case
  functional_test_case
  integration_test_case
  capybara_integration_test_case
].each do |file|
  require_relative(file)
end

# Load any custom test support helpers (e.g. test/support/*.rb)
Dir[File.join(__dir__, "support", "*.rb")].each { |f| require f }

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
    # Run tests in parallel with specified workers.
    # `PARALLEL_WORKERS` env var overrides the CPU-count default
    # (used by system tests to cap at the Maps API port whitelist
    # of 3000–3003 — see `ApplicationSystemTestCase`).
    # Threshold can be set via PARALLEL_TEST_THRESHOLD environment variable
    # Default is 50 (Rails default) if not set
    threshold = ENV["PARALLEL_TEST_THRESHOLD"]&.to_i || 50
    parallel_workers =
      ENV["PARALLEL_WORKERS"].presence&.to_i || :number_of_processors
    parallelize(workers: parallel_workers, threshold: threshold)

    # Set up worker-specific database for parallel testing
    parallelize_setup do |worker|
      # Set TEST_ENV_NUMBER so database.yml picks the right database
      ENV["TEST_ENV_NUMBER"] = worker.to_s

      # Configure SimpleCov for this worker with unique command name
      # This allows SimpleCov to merge results from multiple parallel workers
      SimpleCov.command_name("#{SimpleCov.command_name}-#{worker}")

      # Clear ALL connection pools (primary, cache, etc.) after fork --
      # same fix as config/puma.rb's on_worker_boot, same root cause.
      # `parallelize` forks via Kernel#fork (see
      # ActiveSupport::Testing::Parallelization::Worker#start), same as
      # Puma clustering, so it inherits the same Trilogy
      # @owner-thread-mismatch hazard: #4807's I18n backend builds its
      # SolidCache::Store once at boot, *before* this fork, so every
      # worker process shares that connection's Trilogy handle until
      # cleared here. Without this, the cache connection's internal
      # mutex is owned by a thread that doesn't exist in the child --
      # queries against it either raise Trilogy::SynchronizationError
      # or hang forever in Monitor#synchronize waiting on a lock no
      # thread will ever release.
      ActiveRecord::Base.connection_handler.clear_all_connections!

      # Reset I18n's memoized available-locales set after fork, for the
      # same reason as the connection-pool clear above: `@@available_
      # locales_set` (i18n gem's Config#available_locales_set) is a
      # process-wide class variable, memoized lazily via `||=` on first
      # use. If anything computes it in the parent process pre-fork --
      # e.g. while the `languages` table is still empty, before any
      # worker's own fixtures exist -- every forked worker inherits
      # that same frozen (locale-incomplete) set via copy-on-write, and
      # `||=` means no worker ever recomputes it. Symptom: every
      # non-English locale raises I18n::InvalidLocale in every worker,
      # since DbFallback#available_locales (Language.pluck(:locale))
      # never got a chance to contribute them. Clearing here forces a
      # fresh computation the first time a test actually needs it --
      # by which point fixtures are loaded and the connection above is
      # already valid for this worker.
      I18n.config.clear_available_locales_set
    end

    parallelize_teardown do |_worker|
      # Trigger coverage result generation for this worker
      # SimpleCov will automatically merge results from all workers
      SimpleCov.result
    end

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

    # Standard setup to run before every test. Sets the locale,
    # timezone, and clears Symbol.missing_tags so the teardown
    # assertion only sees tags raised by the test that just ran.
    #
    # Registered as a `setup do` callback rather than `def setup`
    # so it runs unconditionally — many test classes override
    # `def setup` without calling `super`, which previously
    # bypassed these resets and let global state (most notably
    # I18n.locale and Symbol.missing_tags) leak between tests
    # within a parallel worker. See #4238.
    setup do
      # rubocop:disable Rails/I18nLocaleAssignment
      I18n.locale = :en if I18n.locale != :en
      # rubocop:enable Rails/I18nLocaleAssignment
      # rubocop:disable Rails/TimeZoneAssignment
      Time.zone = "America/New_York"
      # rubocop:enable Rails/TimeZoneAssignment
      clear_logs unless defined?(@@cleared_logs)
      Symbol.missing_tags = []
      # Functional/integration tests reset this via ApplicationController's
      # own before_action on every get/post; this covers unit tests that
      # call UserGroup.all_users/reviewers/one_user directly, with no
      # request to trigger that reset.
      UserGroup.reset_request_cache
    end

    # Standard teardown to run after every test.  Just makes sure any
    # images that might have been uploaded are cleared out.
    def teardown
      assert_equal([], Symbol.missing_tags,
                   "Language tag(s) are missing. Run `bin/rails " \
                   "lang:update` and re-run this test before concluding " \
                   "this is a pre-existing/unrelated failure.")
      FileUtils.rm_rf(MO.local_image_files)
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
      paths = %w[development test process_image].map do |name|
        Rails.root.join("log", "#{name}.log")
      end
      paths << MO.email_debug_log_path
      paths.each do |path|
        next unless File.exist?(path)

        File.truncate(path, 0)
      end
      @@cleared_logs = true
    end
  end
end
