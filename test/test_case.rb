#
#  = Test Helpers
#
#  Methods in this class are available to all the unit and functional tests.
#  There are a bunch of helpers for testing GET/POST request heuristics, and
#  there are a bunch of specialized assertions.
#
#  == Test unit helpers
#  clean_our_backtrace::        Make asserts appear to fail in the test unit.
#  application_setup::          Universal setup: sets locale.
#  application_teardown::       Universal teardown: removes images.
#
#  == General Assertions
#  assert_true::                Make sure something is true.
#  assert_false::               Make sure something is false.
#  assert_names_equal::         Compare two name instances.
#  assert_list_equal::          Compare two lists by mapping and sorting elements.
#  assert_obj_list_equal::      Compare two lists of objects, comparing ids.
#  assert_user_list_equal::     Compare two lists of User's.
#  assert_name_list_equal::     Compare two lists of Name's.
#  assert_string_equal_file::   A string is same as contents of a file.
#  assert_email::               Check the properties of a QueuedEmail.
#  assert_save::                Assert ActiveRecord save succeeds.
#
#  == XML Assertions
#  assert_xml_exists::          An element exists.
#  assert_xml_none::            An element doesn't exist.
#  assert_xml_name::            An element is a certain type.
#  assert_xml_attr::            An element has a certain attribute.
#  assert_xml_text::            An element contains a certain text value.
#  dump_xml::                   Dump out XML tree for diagnostics.
#
################################################################################

class Test::Unit::TestCase
  fixtures :all

  # Register standard setup and teardown hooks.
  setup    :application_setup
  teardown :application_teardown

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
  self.use_transactional_fixtures = true

  # Instantiated fixtures are slow, but give you @david where otherwise you
  # would need people(:david).  If you don't want to migrate your existing
  # test cases which use the @david style and don't mind the speed hit (each
  # instantiated fixtures translates to a database query per test method),
  # then set this back to true.
  self.use_instantiated_fixtures = false

  # Tell the damned tester not to run test methods in a random order!!!
  # Makes debugging complex interactions absolutely impossible.
  def self.test_order
    :not_random!
  end

  # Handy (if silly) class used to wrap a structure so that its members are
  # available as methods.  Useful to make structs masquerade as objects for
  # testing purposes.  (BlankSlate is in the "builder" vendor package in
  # ActiveSupport -- it defines a superclass with *no* methods at all.)
  class Wrapper < BlankSlate
    def initialize(attributes={}); @attributes = attributes; end
    def inspect; @attributes.inspect.sub(/^\{/, '<Wrapper: ').sub(/\}$/, '>'); end
    def method_missing(name, *args)
      if name.to_s.match(/^(\w+)=$/)
        @attributes[$1.to_sym] = args[0]
      else
        @attributes[name.to_s.to_sym]
      end
    end
  end

  ##############################################################################
  #
  #  :section: Test unit helpers
  #
  ##############################################################################

  # I lifted this from action_controller/assertions.rb.  It cleans up the
  # backtrace so that it appears as if assertions occurred in the unit test
  # that called the assertions in this file.
  def clean_our_backtrace(&block)
    yield
  rescue Test::Unit::AssertionFailedError => error
    helper_path = File.expand_path(File.dirname(__FILE__))
    regexp = Regexp.new(helper_path + '/\w+\.rb')
    error.backtrace.reject! { |line| File.expand_path(line) =~ regexp }
    raise
  end

  # Standard setup to run before every test.
  def application_setup
    # print "RUNNING #{name}\n"
    Locale.code = :'en-US' if Locale.code != :'en-US'
    Time.zone = 'America/New_York'
    User.current = nil
    @rolf, @mary, @junk, @dick, @katrina = User.all
  end

  # Standard teardown to run after every test.
  def application_teardown
    if File.exists?(IMG_DIR)
      FileUtils.rm_rf(IMG_DIR)
    end
  end

  ##############################################################################
  #
  #  :section: General assertions
  #
  ##############################################################################

  # Assert that something is true.
  def assert_true(got, *msg); assert_equal(true, !!got, *msg); end

  # Assert that something is false.
  def assert_false(got, *msg); assert_equal(false, !!got, *msg); end

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

  # Compare two lists by mapping their elements, then sorting.  By default it
  # just maps their elements to strings.
  #
  #   assert_list_equal([@rolf,@mary], name.authors, &:login)
  #
  def assert_list_equal(expect, got, msg=nil, &block)
    clean_our_backtrace do
      block ||= :to_s.to_proc
      assert_equal(expect.map(&block).sort, got.map(&block).sort, msg)
    end
  end

  # Compare two lists of objects of the same type by comparing their ids.
  #
  #   assert_obj_list_equal([img1,img2], obs.images)
  #
  def assert_obj_list_equal(expect, got, msg=nil)
    clean_our_backtrace do
      assert_list_equal(expect, got, msg, &:id)
    end
  end

  # Compare two lists of User's by comparing their logins.
  #
  #   assert_user_list_equal([@rolf,@mary], name.authors)
  #
  def assert_user_list_equal(expect, got, msg=nil)
    clean_our_backtrace do
      assert_list_equal(expect, got, msg, &:login)
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
    clean_our_backtrace do
      result = false
      msg    = nil

      # Check string against each file, looking for at least one that matches.
      body1  = str
      body1  = yield(body1) if block_given?
      for file in files
        body2 = File.open(file) {|fh| fh.read}
        body2 = yield(body2) if block_given?
        if body1 == body2
          # Stop soon as we find one that matches.
          result = true
          break
        elsif !msg
          # Write out expected (old) and received (new) files for debugging purposes.
          File.open(file + '.old', 'w') {|fh| fh.write(body2)}
          File.open(file + '.new', 'w') {|fh| fh.write(body1)}
          msg = "File #{file} wrong:\n" + `diff #{file}.old #{file}.new`
          File.delete(file + '.old') if File.exists?(file + '.old')
        end
      end

      if result
        # Clean out old files from previous failure(s).
        for file in files
          File.delete(file + '.new') if File.exists?(file + '.new')
        end
      else
        assert(false, msg)
      end
    end
  end

  # Test whether the n-1st queued email matches.  For example:
  #
  #   assert_email(0,
  #     :flavor  => 'QueuedEmail::Comment',
  #     :from    => @mary,
  #     :to      => @rolf,
  #     :comment => @comment_on_minmal_unknown.id
  #   )
  #
  def assert_email(n, args)
    clean_our_backtrace do
      email = QueuedEmail.find(:first, :offset => n)
      assert(email)
      for arg in args.keys
        case arg
        when :flavor
          assert_equal(args[arg], email.flavor, "Flavor is wrong")
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

  ##############################################################################
  #
  #  :section:  XML assertions
  #
  ##############################################################################

  # Retrieve the element identified by key, e.g.,
  #
  #   get_xml_element('/root/child/grand-child')
  #
  # If any of the children are numbers, it gets the Nth child at that level.
  #
  def get_xml_element(key)
    assert(@doc, "XML response is nil!")
    key.sub(/^\//,'').split('/').inject(@doc) do |elem, key|
      elem = elem.elements[key.match(/^\d+$/) ? key.to_i : key]
      assert(elem, "XML response missing element \"#{key}\".")
      elem
    end
  end

  # Assert that a given element does NOT exist.
  #
  #   assert_xml_exists('/response', @response.body)
  #
  def assert_xml_exists(key, msg=nil)
    clean_our_backtrace do
      assert(@doc, "XML response is nil!")
      result = key.sub(/^\//,'').split('/').inject(@doc) do |elem, key|
        elem = elem.elements[key.match(/^\d+$/) ? key.to_i : key]
        assert(nil, msg || "XML response should have \"#{key}\".") if !elem
        elem
      end
    end
  end

  # Assert that a given element does NOT exist.
  #
  #   assert_xml_none('/response/errors')
  #
  def assert_xml_none(key, msg=nil)
    clean_our_backtrace do
      assert(@doc, "XML response is nil!")
      result = key.sub(/^\//,'').split('/').inject(@doc) do |elem, key|
        elem = elem.elements[key.match(/^\d+$/) ? key.to_i : key]
        return if !elem
        elem
      end
      assert_nil(result, msg || "XML response shouldn't have \"#{key}\".")
    end
  end

  # Assert that a given element is of the given type.
  #
  #   assert_xml_name('comment', '/response/results/1')
  #
  def assert_xml_name(val, key, msg=nil)
    clean_our_backtrace do
      _assert_xml(val, get_xml_element(key).name,
                  msg || "XML element \"#{key}\" should be a <#{val}>.")
    end
  end

  # Assert that a given element has a given attribute.
  #
  #   assert_xml_attr(1234, '/response/results/1/id')
  #
  def assert_xml_attr(val, key, msg=nil)
    clean_our_backtrace do
      key.match(/^(.*)\/(.*)/)
      key, attr = $1, $2
      _assert_xml(val, get_xml_element(key).attributes[attr],
                  msg || "XML element \"#{key}\" should have attribute \"#{val}\".")
    end
  end

  # Assert that a given element has a given value.
  #
  #   assert_xml_text('rolf', '/response/results/1/login')
  #
  def assert_xml_text(val, key, msg=nil)
    clean_our_backtrace do
      _assert_xml(val, get_xml_element(key).text,
                  msg || "XML element \"#{key}\" should be \"#{val}\".")
    end
  end

  # Private helper method used in XML assertions above:
  #
  #   _assert_xml(10, @doc.elements['/response/results'].attributes['number'])
  #   _assert_xml('rolf', @doc.elements['/response/user/login'].text)
  #   _assert_xml(/\d\d-\d\d-\d\d/, @doc.elements['/response/script_date'].text)
  #
  def _assert_xml(val, str, msg=nil)
    if val.is_a?(Regexp)
      assert(str.to_s.gsub(/^\s+|\s+$/,'').gsub(/\s+/,' ').match(val), msg)
    else
      assert_equal(val.to_s.gsub(/^\s+|\s+$/,'').gsub(/\s+/,' '),
                   str.to_s.gsub(/^\s+|\s+$/,'').gsub(/\s+/,' '), msg)
    end
  end

  # Dump out XML tree.
  def dump_xml(e, indent='')
    print "#{indent}#{e.name}"
    if e.has_attributes?
      attrs = []
      e.attributes.each do |a,v|
        attrs << "#{a}=#{v}"
      end
      print "(#{attrs.join(' ')})"
    end
    if e.has_text? && e.text =~ /\S/
      txt = e.text.gsub(/^\s+|\s+$/, '').gsub(/\s+/, ' ')
      txt = "\"#{txt}\"" if txt.match(' ')
      print " = #{txt}"
    end
    print "\n"
    if e.has_elements?
      e.elements.each do |child|
        dump_xml(child, indent + '  ')
      end
    end
  end
end
