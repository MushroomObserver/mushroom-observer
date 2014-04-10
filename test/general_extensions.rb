# encoding: utf-8
#
#  = General Test Helpers
#
#  Methods in this class are available to all the unit, functional and
#  integration tests.
#
#  == Test unit helpers
#  clean_our_backtrace::        Make asserts appear to fail in the test unit.
#  setup_image_dirs::           Create test image dirs for tests that do image uploads.
#
#  == General Assertions
#  assert_fail::                Make sure an assertion fails.
#  assert_true::                Make sure something is true.
#  assert_false::               Make sure something is false.
#  assert_blank::               Make sure something is blank.
#  assert_not_blank::           Make sure something is not blank.
#  assert_not_match::           Make sure a string does NOT match.
#  assert_dates_equal::         Compare two Date/Time/DateTime/TimeWithZone instances as dates.
#  assert_objs_equal::          Compare two model instances.
#  assert_users_equal::         Compare two user instances.
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

module GeneralExtensions

  ##############################################################################
  #
  #  :section: Test unit helpers
  #
  ##############################################################################

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

  # Create test image dirs for tests that do image uploads.
  def setup_image_dirs
    if not FileTest.exist?(IMG_DIR)
      FileUtils.cp_r(IMG_DIR.gsub(/test_images$/, 'setup_images'), IMG_DIR)
    end
  end

  ##############################################################################
  #
  #  :section: General assertions
  #
  ##############################################################################

  # Assert that an assertion fails.
  def assert_fail(msg=nil, &block)
    clean_our_backtrace do
      msg ||= 'Expected assertion to fail.'
      assert_raises(Test::Unit::AssertionFailedError, msg, &block)
    end
  end

  # Assert that something is true.
  def assert_true(value, msg=nil)
    clean_our_backtrace do
      msg ||= "Expected #{value.inspect} to be true."
      assert_block(msg) { value }
    end
  end

  # Assert that something is false.
  def assert_false(value, msg=nil)
    clean_our_backtrace do
      msg ||= "Expected #{value.inspect} to be false."
      assert_block(msg) { not value }
    end
  end

  # Assert that something is blank.
  def assert_blank(value, msg=nil)
    clean_our_backtrace do
      msg ||= "Expected #{value.inspect} to be blank."
      assert_block(msg) { value.blank? }
    end
  end

  # Assert that something is not blank.
  def assert_not_blank(value, msg=nil)
    clean_our_backtrace do
      msg ||= "Expected #{value.inspect} not to be blank."
      assert_block(msg) { not value.blank? }
    end
  end

  # Exactly the opposite of +assert_match+ (and essentially copied verbatim
  # from Test::Unit::Assertions source).
  def assert_not_match(expect, actual, msg=nil)
    clean_our_backtrace do
      expect = Regexp.new(expect) if expect.is_a?(String)
      msg = build_message(msg, "Expected <?> not to match <?>.", actual, expect)
      assert_block(msg) { actual !~ expect }
    end
  end

  # Compare two Date/Time/DateTime/TimeWithZone instances.
  def assert_dates_equal(expect, actual, msg=nil)
    clean_our_backtrace do
      expect = expect.strftime('%Y%m%d')
      actual = actual.strftime('%Y%m%d')
      msg = build_message(msg, 'Expected <?> to be <?>.', expect, actual)
      assert_block(msg) { expect == actual }
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

  # Compare two lists of objects of the same type by comparing their ids.
  #
  #   assert_obj_list_equal([img1,img2], obs.images)
  #
  def assert_obj_list_equal(expect, got, msg=nil)
    clean_our_backtrace do
      assert_list_equal(expect, got, msg) {|o| o.nil? ? nil : "#{o.class.name} ##{o.id}"}
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

  # Compare two lists of Name's by comparing their search_names.
  #
  #   assert_name_list_equal([old_name,new_name], old_name.synonym.names)
  #
  def assert_name_list_equal(expect, got, msg=nil)
    clean_our_backtrace do
      assert_list_equal(expect, got, msg, &:search_name)
    end
  end

  GPS_CLOSE_ENOUGH = 0.001

  def assert_gps_equal(expected, value)
    assert((expected.to_f - value.to_f).abs < GPS_CLOSE_ENOUGH)
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
    clean_our_backtrace do
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
