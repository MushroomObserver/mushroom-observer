# frozen_string_literal: true

#  = General Test Helpers
#
#  Methods in this class are available to all the unit, functional and
#  integration tests.
#
#  == Test unit helpers
#  rolf, mary, etc.::           Quick access to User instances.
#  setup_image_dirs::  Create test image dirs for tests that do image uploads.
#
#  == General Assertions
#  assert_fail::                Make sure an assertion fails.
#  assert_true::                Make sure something is true.
#  assert_false::               Make sure something is false.
#  assert_blank::               Make sure something is blank.
#  assert_not_blank::           Make sure something is not blank.
#  assert_not_match::           Make sure a string does NOT match.
#  assert_dates_equal::         Compare two Date/Time/DateTime/TimeWithZone
#                               instances as dates.
#  assert_objs_equal::          Compare two model instances.
#  assert_users_equal::         Compare two user instances.
#  assert_names_equal::         Compare two name instances.
#  assert_arrays_equal:: Compare two lists by mapping and sorting elements.
#  assert_obj_arrays_equal::      Compare two lists of objects, comparing ids.
#  assert_user_arrays_equal::     Compare two lists of User's.
#  assert_name_arrays_equal::     Compare two lists of Name's.
#  assert_gps_equal::           Compare two latitudes or longitudes.
#  assert_email::               Check the properties of a QueuedEmail.
#  assert_save::                Assert ActiveRecord save succeeds.
#  assert_string_equal_file::   A string is same as contents of a file.
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
  # a string that's VERY unlikely to appear anywhere
  # Useful to test that an object doesn't include or isn't equal to something
  ARBITRARY_SHA = "7b2d0b50147a2a6497236a722c9c7a9136d2879c"

  ##############################################################################
  #
  #  :section: Test unit helpers
  #
  ##############################################################################

  def sql_collates_accents?
    sql_sorted = u_and_umlaut_collated_by_sql.pluck(:notes)
    sql_sorted == sql_sorted.sort
  end

  # sql sort of 3 consecutive records whose :notes are, respectively: u, ü, u
  def u_and_umlaut_collated_by_sql
    APIKey.select(:notes).where(key: "sort_test").order(:notes).to_a
  end

  # These used to be automatically instantiated fixtures, e.g., @dick, etc.
  def rolf
    users(:rolf)
  end

  def mary
    users(:mary)
  end

  def junk
    users(:junk)
  end

  def dick
    users(:dick)
  end

  def katrina
    users(:katrina)
  end

  def roy
    users(:roy)
  end

  def lone_wolf
    users(:lone_wolf)
  end

  def use_test_locales(&block)
    Language.alt_locales_path("config/test_locales", &block)
    FileUtils.remove_dir(Rails.root.join("config/test_locales"), force: true)
  end

  # Create test image dirs for tests that do image uploads.
  def setup_image_dirs
    return if FileTest.exist?(MO.local_image_files)

    setup_images = MO.local_image_files.gsub(/test_images$/, "setup_images")
    FileUtils.cp_r(setup_images, MO.local_image_files)
  end

  # This seems to have disappeared from rails.
  def build_message(msg, add)
    msg ? "#{msg}\n#{add}" : add
  end

  ##############################################################################
  #
  #  :section: General assertions
  #
  ##############################################################################

  # Assert that an assertion fails.
  def assert_fail(msg = nil, &block)
    msg ||= "Expected assertion to fail."
    assert_raises(Minitest::Assertion, msg, &block)
  end

  # Assert that something is true.
  def assert_true(value, msg = nil)
    msg ||= "Expected #{value.inspect} to be true."
    assert(value, msg)
  end

  # Assert that something is false.
  def assert_false(value, msg = nil)
    msg ||= "Expected #{value.inspect} to be false."
    assert_not(value, msg)
  end

  # Assert that something is blank.
  def assert_blank(value, msg = nil)
    msg ||= "Expected #{value.inspect} to be blank."
    assert(value.blank?, msg)
  end

  # Assert that something is not blank.
  def assert_not_blank(value, msg = nil)
    msg ||= "Expected #{value.inspect} not to be blank."
    assert_not(value.blank?, msg)
  end

  # Compare two Date/Time/DateTime/TimeWithZone instances.
  def assert_dates_equal(expect, actual, msg = nil)
    expect = expect.strftime("%Y%m%d")
    actual = actual.strftime("%Y%m%d")
    msg = build_message(msg, "Expected <#{expect}> to be <#{actual}>.")
    assert(expect == actual, msg)
  end

  # Assert that two instances are equal.
  def assert_objs_equal(expect, got, *msg)
    assert_equal(fixture_label(expect), fixture_label(got), *msg)
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

  # Compare two arrays by mapping their elements.  By default it
  # just maps their elements to strings.
  #
  #   assert_arrays_equal([rolf,mary], name.authors, &:login)
  #
  def assert_arrays_equal(expect, got, *args, &block)
    block ||= :to_s.to_proc
    expect = expect.to_a.map(&block)
    got    = got.to_a.map(&block)
    if args.first == :sort
      args.shift
      expect.sort!
      got.sort!
    end
    assert_equal(expect, got, args.first)
  end

  # Compare two arrays of objects of the same type by comparing their ids.
  #
  #   assert_obj_arrays_equal([img1,img2], obs.images)
  #
  def assert_obj_arrays_equal(expect, got, *)
    assert_arrays_equal(expect, got, *) { |o| fixture_label(o) }
  end

  # Compare two arrays of User's by comparing their logins.
  #
  #   assert_user_arrays_equal([rolf,mary], name.authors)
  #
  def assert_user_arrays_equal(expect, got, *)
    assert_arrays_equal(expect, got, *, &:login)
  end

  # Compare two arrays of Name's by comparing their search_names.
  #
  #   assert_name_arrays_equal([old_name,new_name], old_name.synonyms)
  #
  def assert_name_arrays_equal(expect, got, *)
    assert_arrays_equal(expect, got, *, &:search_name)
  end

  GPS_CLOSE_ENOUGH = 0.001

  # Compare two latitudes or longitudes.
  #
  #   assert_gps_equal(-123.4567, location.west)
  #
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
  def assert_email(offset, args)
    email = QueuedEmail.offset(offset).first
    assert(email)
    args.each_key do |arg|
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
        assert_equal(args[arg], email.get_integer(arg) || email.get_string(arg),
                     "Value of #{arg} is wrong")
      end
    end
    email
  end

  # Assert that an ActiveRecord +save+ succeeds, dumping errors if not.
  def assert_save(obj, msg = nil)
    return pass if obj.save

    msg2 = obj.errors.full_messages.join("; ")
    msg2 = "#{msg}\n#{msg2}" if msg
    flunk(msg2)
  end

  # This should make diagnostics of failed tests more useful!
  def fixture_label(obj)
    return "" if obj.nil?

    table = obj.class.name.tableize
    if @loaded_fixtures
      @loaded_fixtures[table].fixtures.each do |name, fixture|
        return "<#{name}>" if fixture["id"] == obj.id
      end
    end
    case table
    when "names"
      "Name: #{obj.search_name}"
    when "user"
      "User: #{obj.login}"
    else
      "#{obj.class.name} ##{obj.id}"
    end
  end

  @@fixture_labels = {}
  def get_fixture_label(table, idx)
    @@fixture_labels[table] ||= read_fixture_labels(table) || []
    @@fixture_labels[table][idx]
  end

  def read_fixture_labels(table)
    result = []
    file = Rails.root.join("test/fixtures/#{table}.yml")
    unless File.exist?(file)
      raise("Can't find fixtures file for #{table}! Should be #{file}.")
    end

    last_id = 0
    line_num = 0
    file.readlines.each do |line|
      line_num += 1
      match = line.match(/^(\w+):\s+#\s*(\d+)\s*$/)
      next unless match

      label = match[1]
      id = match[2].to_i
      if id != last_id + 1
        raise("IDs are not consecutive at #{file} line #{line_num}: " \
              "#{id} should be #{last_id + 1}\n")
      end
      result[id - 1] = label
      last_id = id
    end
    result
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
    key.sub(%r{^/}, "").split("/").inject(@doc) do |elem, k|
      elem = elem.elements[/^\d+$/.match?(k) ? key.to_i : k]
      assert(elem, "XML response missing element \"#{k}\".")
      elem
    end
  end

  # Assert that a given element does NOT exist.
  #
  #   assert_xml_exists('/response', @response.body)
  #
  def assert_xml_exists(key, msg = nil)
    assert(@doc, "XML response is nil!")
    key.sub(%r{^/}, "").split("/").inject(@doc) do |elem, k|
      elem = elem.elements[/^\d+$/.match?(key) ? k.to_i : k]
      assert(nil, msg || "XML response should have \"#{k}\".") unless elem
      elem
    end
  end

  # Assert that a given element does NOT exist.
  #
  #   assert_xml_none('/response/errors')
  #
  def assert_xml_none(key, msg = nil)
    assert(@doc, "XML response is nil!")
    result = key.sub(%r{^/}, "").split("/").inject(@doc) do |elem, k|
      elem = elem.elements[/^\d+$/.match?(key) ? k.to_i : k]
      return unless elem

      elem
    end
    assert_nil(result, msg || "XML response shouldn't have \"#{key}\".")
  end

  # Assert that a given element is of the given type.
  #
  #   assert_xml_name('comment', '/response/results/1')
  #
  def assert_xml_name(val, key, msg = nil)
    _assert_xml(val, get_xml_element(key).name,
                msg || "XML element \"#{key}\" should be a <#{val}>.")
  end

  # Assert that a given element has a given attribute.
  #
  #   assert_xml_attr(1234, '/response/results/1/id')
  #
  def assert_xml_attr(val, key, msg = nil)
    key =~ %r{^(.*)/(.*)}
    key = Regexp.last_match(1)
    attr = Regexp.last_match(2)
    _assert_xml(
      val, get_xml_element(key).attributes[attr],
      msg || "XML element \"#{key}\" should have attribute \"#{val}\"."
    )
  end

  # Assert that a given element has a given value.
  #
  #   assert_xml_text('rolf', '/response/results/1/login')
  #
  def assert_xml_text(val, key, msg = nil)
    _assert_xml(val, get_xml_element(key).text,
                msg || "XML element \"#{key}\" should be \"#{val}\".")
  end

  # Private helper method used in XML assertions above:
  #
  #   _assert_xml(10, @doc.elements['/response/results'].attributes['number'])
  #   _assert_xml('rolf', @doc.elements['/response/user/login'].text)
  #   _assert_xml(/\d\d-\d\d-\d\d/, @doc.elements['/response/script_date'].text)
  #
  def _assert_xml(val, str, msg = nil)
    if val.is_a?(Regexp)
      assert(str.to_s.gsub(/^\s+|\s+$/, "").gsub(/\s+/, " ").match(val), msg)
    else
      assert_equal(val.to_s.gsub(/^\s+|\s+$/, "").gsub(/\s+/, " "),
                   str.to_s.gsub(/^\s+|\s+$/, "").gsub(/\s+/, " "), msg)
    end
  end

  # Dump out XML tree.
  def dump_xml(exp, indent = "")
    print("#{indent}#{e.name}")
    if exp.has_attributes?
      attrs = exp.attributes.map do |a, v|
        "#{a}=#{v}"
      end
      print("(#{attrs.join(" ")})")
    end
    if exp.has_text? && exp.text =~ /\S/
      txt = exp.text.gsub(/^\s+|\s+$/, "").gsub(/\s+/, " ")
      txt = "\"#{txt}\"" if txt.match?(" ")
      print(" = #{txt}")
    end
    print("\n")
    return unless exp.has_elements?

    exp.elements.each do |child|
      dump_xml(child, "#{indent}  ")
    end
  end

  ##############################################################################
  #
  #  :section:  css assertions
  #
  ##############################################################################

  def assert_displayed_title(expect, msg = "Wrong page or title")
    if expect.is_a?(Regexp)
      assert_match(expect, css_select("#title").text, msg)
    else
      assert_equal(expect, css_select("#title").text, msg)
    end
  end

  def assert_displayed_filters(expect, msg = "Wrong filters")
    assert_match(expect, css_select("#filters").text, msg)
  end

  ######################################################################
  #
  #  INDEX SORTING
  #  Tests loading index with all available sort orders
  #  Checks that the relevant sort button is active
  #
  def check_index_sorting
    login
    index_sorts.each do |sort_order|
      check_index_sorted_by(sort_order, do_login: false)
    end
  end

  # Can be called independently to test a single sort order
  def check_index_sorted_by(sort_order, do_login: true)
    login if do_login
    get(:index, params: { by: sort_order })

    assert_template("index")
    assert_sorted_by(sort_order.to_s)
  end

  # Checks for a consistently named helper method like "users_index_sorts"
  # otherwise returns empty array.
  def index_sorts
    helpers_defined = @controller.helpers.respond_to?(sorts_helper_method)
    assert(helpers_defined, "#{sorts_helper_method} not defined in helpers")
    return [] unless helpers_defined

    originals = @controller.helpers.send(sorts_helper_method).dup
    originals.map! { |key, _label| key.to_sym }
    originals.delete(:id)
    reverses = originals.dup.map! { |key| :"reverse_#{key}" }
    originals + reverses
  end

  def sorts_helper_method
    @sorts_helper_method ||= :"#{helper_class}_index_sorts"
  end

  # Contributors index uses the same sorts as Users
  def helper_class
    @helper_class ||= case (name = @controller.controller_name)
                      when "contributors"
                        "users"
                      else
                        name
                      end
  end

  def assert_sorted_by(by, text = /.*/,
                       msg = "Wrong index sort, or sort by #{by} not available")
    order_by = by.dup
    reverse = order_by.sub!(/^reverse_/, "") # changes by and returns boolean
    class_name = "#{adjusted_controller_class_name}_by_#{order_by}_link"
    assert_select("#sorts a.#{class_name}[disabled=disabled]", text, msg)
    return unless reverse

    assert_select("#sorts a.#{class_name}[disabled=disabled]",
                  :sort_by_reverse.l, msg)
  end

  # The controller class name for e.g. Locations::DescriptionsController is
  # "locations/descriptions". Need to adjust these to "location_descriptions".
  def adjusted_controller_class_name
    return controller_class_name unless controller_class_name.include?("/")

    names = controller_class_name.split("/")
    names.map!.with_index do |namespace, idx|
      if idx < names.size - 1
        namespace.singularize
      else
        namespace
      end
    end
    names.join("_")
  end

  ##############################################################################
  #
  #  :section:  File contents assertions
  #
  ##############################################################################

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
    str = yield(str) if block_given?
    clean_string!(str)
    encoding = str.encoding

    files.each do |file|
      filename = Array(file).first
      format = file.is_a?(Array) ? "r:#{file[1]}" : "r"
      template = File.open(filename, format).read
      template = enforce_encoding(encoding, template)
      template = ERB.new(template).result # interpolate variables
      template = yield(template) if block_given?
      clean_string!(template)

      if match_ignoring_some_bits(str, template)
        # Stop soon as we find one that matches.
        result = true
        break
      elsif !msg
        # Write out expected (old) and received (new) files for debugging.
        File.open("#{filename}.old", "w:#{encoding}") do |fh|
          fh.write(template)
        end
        File.open("#{filename}.new", "w:#{encoding}") do |fh|
          fh.write(str)
        end
        msg = "File #{filename} wrong:\n" \
              "#{`diff #{filename}.old #{filename}.new`}"
        File.delete("#{filename}.old") if File.exist?("#{filename}.old")
      end
    end

    return assert(false, msg) unless result

    # Clean out old files from previous failure(s).
    files.each do |file|
      filename = Array(file).first
      new_filename = "#{filename}.new"
      File.delete(new_filename) if File.exist?(new_filename)
    end
    pass
  end

  def enforce_encoding(encoding, str)
    return str if str.encoding == encoding

    str.encode(encoding)
  end

  def clean_string!(str)
    str.delete!("\r")
    str.sub!(/\s*\z/, "\n")
  end

  def match_ignoring_some_bits(str, template)
    template.split("\n").each do |line|
      next unless line.include?("IGNORE")

      pattern = Regexp.escape(line).gsub("IGNORE", ".*")
      str.sub!(/^#{pattern}$/, line)
    end
    str == template
  end
end
