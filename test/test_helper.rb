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
require 'rails/test_help'
for file in %w(
  general_extensions
  flash_extensions
  controller_extensions
  integration_extensions
  session_extensions
  session_form_extensions
  unit_test_case
  functional_test_case
  integration_test_case
  integration_session
  language_extensions
)
  require File.expand_path(File.dirname(__FILE__) + "/#{file}")
end

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
  #   I18n.locale = :'en' if I18n.locale != :'en'
  #   Time.zone = 'America/New_York'
  #   User.current = nil
  # end

  def setup
    I18n.locale = :'en' if I18n.locale != :'en'
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

  # These used to be automatically instantiated fixtures, e.g., @dick, etc.
  def rolf; users(:rolf); end
  def mary; users(:mary); end
  def junk; users(:junk); end
  def dick; users(:dick); end
  def katrina; users(:katrina); end
  def roy; users(:roy); end

  def assert_obj_list_equal(expect, got, msg=nil)
    assert_list_equal(expect, got, msg) {|o| o.nil? ? nil : "#{o.class.name} ##{o.id}"}
  end

  # Compare two lists by mapping their elements, then sorting.  By default it
  # just maps their elements to strings.
  #
  #   assert_list_equal([rolf,mary], name.authors, &:login)
  #
  def assert_list_equal(expect, got, msg=nil, &block)
    block ||= :to_s.to_proc
    assert_equal(expect.map(&block).sort, got.map(&block).sort, msg)
  end

  # Assert that two User instances are equal.
  def assert_objs_equal(expect, got, *msg)
    assert_equal(
      (expect ? "#{expect.class.name} ##{expect.id}" : "nil"),
      (got ? "#{got.class.name} ##{got.id}" : "nil"),
      *msg
    )
  end

  # Assert that two User instances are equal.
  def assert_users_equal(expect, got, *msg)
    assert_equal(
      (expect ? "#{expect.login} (#{expect.id})" : "nil"),
      (got ? "#{got.login} (#{got.id})" : "nil"),
      *msg
    )
  end

  # Assert that two Name instances are equal.
  def assert_names_equal(expect, got, *msg)
    assert_equal(
      (expect ? "#{expect.search_name} (#{expect.id})" : "nil"),
      (got ? "#{got.search_name} (#{got.id})" : "nil"),
      *msg
    )
  end

  # Compare two lists of User's by comparing their logins.
  #
  #   assert_user_list_equal([rolf,mary], name.authors)
  #
  def assert_user_list_equal(expect, got, msg=nil)
    assert_list_equal(expect, got, msg, &:login)
  end

  # Assert that an ActiveRecord +save+ succeeds, dumping errors if not.
  def assert_save(obj, msg=nil)
    if obj.save
      assert(true)
    else
      msg2 = obj.errors.full_messages.join("; ")
      msg2 = msg + "\n" + msg2 if msg
      assert(false, msg2)
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
    assert_list_equal(expect, got, msg, &:search_name)
  end

  # Test whether the n-1st queued email matches.  For example:
  #
  #   assert_email(0,
  #     :flavor  => 'QueuedEmail::CommentAdd',
  #     :from    => mary,
  #     :to      => rolf,
  #     :comment => @comment_on_minmal_unknown.id
  #   )
  #
  def assert_email(n, args)
    email = QueuedEmail.find(:first, :offset => n)
    assert(email)
    for arg in args.keys
      case arg
      when :flavor
        assert_equal(args[arg].to_s, email.flavor.to_s, "Flavor is wrong")
      when :from
        assert_equal(args[arg].id, email.user_id, "Sender is wrong")
      when :to
        assert_equal(args[arg].id, email.to_user_id, "Recipient is wrong")
      when :note
        assert_equal(args[arg], email.get_note, "Value of note is wrong")
      else
        assert_equal(args[arg], email.get_integer(arg) || email.get_string(arg), "Value of #{arg} is wrong")
      end
    end
  end

  # Assert that a string is same as contents of a given file.  Pass in a block
  # to use as a filter on both contents of response and file.
  #
  #   assert_string_equal_file(@response.body,
  #     "#{path}/expected_response.html",
  #     "#{path}/alternate_expected_response.html") do |str|
  #     str.strip_squeeze.downcase
  #   end
  #
  def assert_string_equal_file(str, *files)
    result = false
    msg    = nil

    # Check string against each file, looking for at least one that matches.
    processed_str  = str
    processed_str  = yield(processed_str) if block_given?
    processed_str.split("\n")
    encoding = processed_str.encoding

    for file in files
      template = File.open(file_name(file), file_format(file)).read
      template = enforce_encoding(encoding, file, template)
      template = yield(template) if block_given?
      if template_match(processed_str, template)
        # Stop soon as we find one that matches.
        result = true
        break
      elsif !msg
        # Write out expected (old) and received (new) files for debugging purposes.
        filename = file_name(file)
        File.open(filename + '.old', "w:#{encoding}") {|fh| fh.write(template)}
        File.open(filename + '.new', "w:#{encoding}") {|fh| fh.write(processed_str)}
        msg = "File #{filename} wrong:\n" +
          `diff #{filename}.old #{filename}.new`
        File.delete(filename + '.old') if File.exists?(filename + '.old')
      end
    end

    if result
      # Clean out old files from previous failure(s).
      for file in files
        new_filename = file_name(file) + '.new'
        File.delete(new_filename) if File.exists?(new_filename)
      end
    else
      assert(false, msg)
    end
  end

  def enforce_encoding(encoding, file, str)
    result = str
    if str.encoding != encoding
      result = str.encode(encoding)
    end
    if file.is_a?(Array) and file[1] == 'ISO-8859-1'
      if file[1] == str.encoding
        print "Re-encoding no longer needed\n"
      end
    end
    result
  end

  def file_name(file); file.is_a?(Array) ? file[0] : file; end
  def file_format(file) file.is_a?(Array) ? "r:#{file[1]}" : 'r'; end

  def template_match(str, template)
    # Ensure that all the lines in template are in str.  Allows additional headers like 'Date' to get added and to vary
    (Set.new(template.split("\n")) - Set.new(str.split("\n"))).length == 0
  end
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
class ApplicationController
  def rescue_action(e)
    raise e
  end
end

require 'test/unit/ui/console/testrunner'

# Apparently bugs in the new version of Test::Unit?  Probably because we're using
# old version of rails...
module Test
  module Unit
    module UI
      module Console
        class TestRunner
          # When running in "show_detail_immediately" and "need_detail_faults"
          # mode it totally screws up the assertion message.
          def output_fault_message(fault)
            output_single(fault.message, fault_color(fault))
          end

          # It no longer prints dots for successful tests.
          alias old_attach_to_mediator attach_to_mediator
          def attach_to_mediator
            old_attach_to_mediator
            @mediator.add_listener(TestResult::FINISHED, &method(:test_finished))
          end
        end
      end
    end
  end
end
