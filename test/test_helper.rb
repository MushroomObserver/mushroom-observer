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

I18n.enforce_available_locales = true

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
  # def application_setup
  #   Locale.code = :'en' if Locale.code != :'en'
  #   Time.zone = 'America/New_York'
  #   User.current = nil
  # end

  def setup
    # Locale.code = :'en' if Locale.code != :'en'
    Time.zone = 'America/New_York'
    User.current = nil
  end


  # Standard teardown to run after every test.  Just makes sure any
  # images that might have been uploaded are cleared out.
  def teardown
    if File.exists?(IMG_DIR)
      FileUtils.rm_rf(IMG_DIR)
    end
  end
  
  def rolf; users(:rolf); end
  def mary; users(:mary); end
  def junk; users(:junk); end
  def dick; users(:dick); end
  def katrina; users(:katrina); end
  def roy; users(:roy); end
  
  def assert_obj_list_equal(expect, got, msg=nil)
    clean_our_backtrace do
      assert_list_equal(expect, got, msg) {|o| o.nil? ? nil : "#{o.class.name} ##{o.id}"}
    end
  end
  
  # Clean up backtrace of any assertion failures so that it appears as if
  # assertions occurred in the unit test that called the caller.  It strips
  # out everything past and including the method name given, or everything
  # past a method starting with "assert_".
  def clean_our_backtrace(caller=nil, &block)
    yield
  rescue Test::Unit::AssertionFailedError => error
    keepers = []
    for line in error.backtrace
      if line.match(/(\w+)\.rb.*`(\w+)'/)
        file, method = $1, $2
        if method == caller or method.match(/^assert_/)
          keepers.clear
        elsif file == 'setup_and_teardown' and method == 'run_with_callbacks'
          break
        else
          keepers << line
        end
      else
        keepers << line
      end
    end
    error.backtrace.clear
    error.backtrace.push(*keepers)
    raise error
  end

  # Compare two lists by mapping their elements, then sorting.  By default it
  # just maps their elements to strings.
  #
  #   assert_list_equal([rolf,mary], name.authors, &:login)
  #
  def assert_list_equal(expect, got, msg=nil, &block)
    clean_our_backtrace do
      block ||= :to_s.to_proc
      assert_equal(expect.map(&block).sort, got.map(&block).sort, msg)
    end
  end

  # Assert that two User instances are equal.
  def assert_objs_equal(expect, got, *msg)
    clean_our_backtrace do
      assert_equal(
        (expect ? "#{expect.class.name} ##{expect.id}" : "nil"),
        (got ? "#{got.class.name} ##{got.id}" : "nil"),
        *msg
      )
    end
  end

  # Assert that two User instances are equal.
  def assert_users_equal(expect, got, *msg)
    clean_our_backtrace do
      assert_equal(
        (expect ? "#{expect.login} (#{expect.id})" : "nil"),
        (got ? "#{got.login} (#{got.id})" : "nil"),
        *msg
      )
    end
  end

  # Assert that two Name instances are equal.
  def assert_names_equal(expect, got, *msg)
    clean_our_backtrace do
      assert_equal(
        (expect ? "#{expect.search_name} (#{expect.id})" : "nil"),
        (got ? "#{got.search_name} (#{got.id})" : "nil"),
        *msg
      )
    end
  end

  # Compare two lists of User's by comparing their logins.
  #
  #   assert_user_list_equal([rolf,mary], name.authors)
  #
  def assert_user_list_equal(expect, got, msg=nil)
    clean_our_backtrace do
      assert_list_equal(expect, got, msg, &:login)
    end
  end

  # Assert that an ActiveRecord +save+ succeeds, dumping errors if not.
  def assert_save(obj, msg=nil)
    clean_our_backtrace do
      if obj.save
        assert(true)
      else
        msg2 = obj.errors.full_messages.join("; ")
        msg2 = msg + "\n" + msg2 if msg
        assert(false, msg2)
      end
    end
  end

  # Create test image dirs for tests that do image uploads.
  def setup_image_dirs
    if not FileTest.exist?(IMG_DIR)
      FileUtils.cp_r(IMG_DIR.gsub(/test_images$/, 'setup_images'), IMG_DIR)
    end
  end

  # Compare two lists of Name's by comparing their search_names.
  #
  #   assert_name_list_equal([old_name,new_name], old_name.synonym.names)
  #
  def assert_name_list_equal(expect, got, msg=nil)
    clean_our_backtrace do
      assert_list_equal(expect, got, msg, &:search_name)
    end
  end
end
