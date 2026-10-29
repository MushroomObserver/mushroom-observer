# frozen_string_literal: true

require("test_helper")

class Language::ExporterTest < UnitTestCase
  attr_accessor :tmp_dir

  def setup
    @official = Language.official
    Language.clear_verbose_messages
    Language.override_input_files
    self.tmp_dir = Rails.root.join("tmp")
    FileUtils.mkdir_p(tmp_dir)
    super
  end

  def teardown
    Language.reset_input_file_override
    super
  end

  def assert_message(msg)
    msg = [msg] + Language.verbose_messages
    msg.join("\n")
  end

  def test_validators
    assert_valid(:validate_tag, "abc")
    assert_valid(:validate_tag, "abc_2")
    assert_valid(:validate_tag, "_A_b_3_")
    assert_invalid(:validate_tag, "one two")
    assert_invalid(:validate_tag, "one[two]")
    assert_invalid(:validate_tag, "pfüssel")
    assert_valid(:validate_string?, "blah")
    assert_invalid(:validate_string?, "yes")
    assert_invalid(:validate_string?, "NO")
    assert_valid(:validate_string?, "one 2 three")
    assert_valid(:validate_string?, "one-two, three!")
    assert_valid(:validate_string?, '"anything goes [here] # wow"')
    assert_valid(:validate_string?, "'anything goes [here] # wow'")
    assert_invalid(:validate_string?, "[:blah]")
    assert_valid(:validate_string?, '"[:blah]"')
    assert_valid(:validate_string?, "tags[:blah]")
    assert_invalid(:validate_string?, "Data: values, are, here")
    assert_valid(:validate_square_brackets, "this is right")
    assert_valid(:validate_square_brackets, "this is [good] right")
    assert_valid(:validate_square_brackets, "this is [:good] right")
    assert_valid(:validate_square_brackets,
                 "this is [:good(var=val,var=val)] right")
    assert_valid(:validate_square_brackets,
                 "this is [:good(var=12345)] right")
    assert_valid(:validate_square_brackets,
                 "this is [:good(var=123.45)] right")
    assert_valid(:validate_square_brackets,
                 "this is [:good(var='abc def')] right")
    assert_valid(:validate_square_brackets,
                 'this is [:good(var="#$@!")] right')
    assert_invalid(:validate_square_brackets,
                   "this is [:missing(val=)] intentionally wrong")
    assert_invalid(:validate_square_brackets,
                   "this is [:unmatched intentionally wrong")
    assert_invalid(:validate_square_brackets,
                   'this is [:bad(val=\'foo")] intentionally wrong')
    assert_invalid(:validate_square_brackets,
                   "this is [:bad(val=%%%)] intentionally wrong")
  end

  def assert_valid(method, str)
    assert_valid_or_invalid(method, str, true, "valid")
  end

  def assert_invalid(method, str)
    assert_valid_or_invalid(method, str, false, "invalid")
  end

  def assert_valid_or_invalid(method, str, expected_val, expected_str)
    msg = assert_message("#{method}: Expected #{str.inspect} to be" \
                         "#{expected_str}.")
    assert_equal(!!expected_val, !!@official.send_private(method, str), msg)
    Language.clear_verbose_messages
  end

  def test_check_export_line
    assert_check_pass(0, 0, "")
    assert_check_pass(0, 0, " \t \n")
    assert_check_pass(0, 0, "# comment\n")
    assert_check_pass(0, 0, "---\n")
    assert_check_pass(0, 0, "abc: abc\n")
    assert_check_pass(0, 0, "abc: 'abc'\n")
    assert_check_pass(0, 0, "'yes': 'yes'\n")
    assert_check_fail(0, 0, "yes: abc\n")
    assert_check_fail(0, 0, "abc:\n")
    assert_check_fail(0, 0, "abc :def\n")
    assert_check_fail(0, 0, "abc: [def]\n")
    assert_check_pass(0, 0, "abc: '[def]'\n")
    assert_check_fail(0, 0, "abc: abc: d\n")
    assert_check_fail(0, 0, "'abc: value\n")
    assert_check_pass(0, 1, "TAG: >\n")
    assert_check_pass(1, 1, "  blah\n")
    assert_check_pass(1, 1, "  any : thing[:goes]\n")
    assert_check_fail(1, 1, "no_indent\n")
    assert_check_fail(1, 0, "abc: abc\n")
    assert_check_pass(1, 0, "\n")
  end

  def test_check_export_tag_def_line_invalid_tag
    @official.init_check_export_line(true, false)
    @official.send_private(:check_export_tag_def_line,
                           "bad tag", "bad tag", +" value")
    pass, = @official.get_check_export_line_status
    assert_false(pass, "Expected invalid tag to fail")
  end

  def test_verbose_puts_message_when_language_verbose
    real_verbose = Language::Exporter.instance_method(:verbose)
    Language.stub(:verbose, true) do
      out, = capture_io { real_verbose.bind_call(@official, "hello") }
      assert_equal("hello\n", out)
    end
  end

  def assert_check_pass(*)
    assert_check_pass_or_fail(true, "pass", *)
  end

  def assert_check_fail(*)
    assert_check_pass_or_fail(false, "fail", *)
  end

  def assert_check_pass_or_fail(expected_val, expected_str,
                                in_tag_start, in_tag_end, str)
    @official.init_check_export_line(true, in_tag_start == 1)
    @official.send_private(:check_export_line, str)
    pass, in_tag = @official.get_check_export_line_status
    msg = assert_message("Expected #{str.inspect} to #{expected_str}.")
    assert_equal(expected_val, pass, msg)
    msg = assert_message(
      "Expected #{str.inspect} to leave in_tag = #{in_tag_end.inspect}"
    )
    assert_equal(in_tag_end == 1, !!in_tag, msg)
    Language.clear_verbose_messages
  end

  def export_check(export_data, message, pass)
    use_test_locales do
      @official.write_export_file_lines(export_data)
      result = @official.send_private(message)
      msg = assert_message(
        "#{export_data}\n should have #{pass ? "passed" : "failed"}"
      )
      assert(pass ? result : !result, msg)
      Language.clear_verbose_messages
    end
  end

  def test_update_export_file
    template = Rails.root.join("test/templates/export_round_trip.yml")
    use_test_locales do
      file = @official.export_file
      FileUtils.copy(template, file)
      @official.update_export_file
      data = File.open(file, "r:utf-8") { |fh| YAML.safe_load(fh) }
      assert(data, "File read failed for #{file}")
    end
  end

  def test_check_export_file_for_duplicates
    export_data = [
      "  tag1: val1\n",
      "  tag2: val2\n",
      "  tag3: val3\n"
    ]
    export_check(export_data, :check_export_file_for_duplicates, true)

    export_data << "  tag1: val4\n"
    export_check(export_data, :check_export_file_for_duplicates, false)
  end

  def test_check_export_file_data
    export_data = [
      "  tag1: >\n",
      "    blah blah blah\n",
      "\n",
      "  tag2: val2\n",
      "  tag3: val3[:tag2]\n"
    ]

    export_check(export_data, :check_export_file_data, true)

    # Value of tag4 will be true, not a String.
    export_data[-1] = "  tag4: yes\n"
    export_check(export_data, :check_export_file_data, false)

    export_data[-1] = "  :tag5: blah\n"
    export_check(export_data, :check_export_file_data, false)

    export_data[-1] = "  tag6: blah[bogus=args=here]\n"
    export_check(export_data, :check_export_file_data, false)
  end

  def test_export_round_trip
    template = Rails.root.join("test/templates/export_round_trip.yml")
    use_test_locales do
      file = @official.export_file
      FileUtils.copy(template, file)
      @official.write_export_file_lines(File.readlines(file, encoding: "utf-8"))
      data = File.open(file, "r:utf-8") { |fh| YAML.safe_load(fh) }
      assert(data, "File read failed for #{file}")

      data.each do |tag, str|
        assert_kind_of(String, tag,
                       "#{file} #{tag}: tag is a #{tag.class} not a String!")
        assert_kind_of(String, str,
                       "#{file} #{tag}: value is a #{str.class} not a String!")
      end

      lines = @official.send_private(:format_export_file, data, data)
      new_data = YAML.safe_load(lines.join)
      seen = {}
      data.each do |tag, old_str|
        if (new_str = new_data[tag])
          old_str = @official.send_private(:clean_string, old_str)
          new_str = @official.send_private(:clean_string, new_str)
          assert_equal(old_str, new_str, "String for #{tag} got garbled.")
        else
          flunk("Missing string for #{tag}.")
        end
        seen[tag] = true
      end
      new_data.keys.reject { |tag| seen[tag] }.each do |tag|
        flunk("Unexpected string for #{tag}.")
      end
    end
  end

  def test_formatting
    check_format(:clean_string, "" => "")
    check_format(:clean_string, "abc def" => "abc def")
    check_format(:clean_string, ' abc \n def ' => "abc\ndef")
    check_format(:escape_string, "" => '""')
    check_format(:escape_string, "'abc'" => "\"'abc'\"")
    check_format(:escape_string, 'a "b" c' => '"a \\"b\\" c"')
    check_format(:format_string, "" => "\"\"\n")
    check_format(:format_string, "abc" => "abc\n")
    check_format(:format_string, ' def "ghi" jkl ' => "def \"ghi\" jkl\n")
    check_format(:format_string, "abc def:" => "\"abc def:\"\n")
    check_format(:format_string, "(abc def)" => "\"(abc def)\"\n")
    check_format(:format_string, "abc (def)" => "abc (def)\n")
    check_format(:format_string, '"abc def"' => "\"\\\"abc def\\\"\"\n")
    check_format(:format_string, "\n" => "\"\"\n")
    check_format(:format_string, "abc\n" => "abc\n")
    check_format(:format_string, "abc\ndef" => "\"abc\\ndef\"\n")
    check_format(:format_string, "'abc'\ndef:" => "\"'abc'\\ndef:\"\n")
  end

  def check_format(method, vals)
    vals.each do |string, expect|
      actual = @official.send_private(method, string)
      assert_equal(expect, actual, "#{method}(#{string.inspect}) is wrong")
    end
  end

  def test_format_export_file
    input_lines = [
      "---\n",
      "\n",
      "# COMMON STRINGS\n",
      "\n",
      "  name: name\n",
      "  NAME: Name\n",
      # (this changed last time)\n",
      "  runtime_error: >\n",
      "    Shit happens.\n",
      "\n"
    ]

    expect_lines = [
      "---\n",
      "\n",
      "# COMMON STRINGS\n",
      "\n",
      "  name: nombre\n",
      "  NAME: Nombre\n",
      # (this changed last time)\n",
      "  runtime_error:  Whatever\n"
    ]

    strings = {
      "name" => "nombre",
      "NAME" => "Nombre",
      "runtime_error" => "Whatever"
    }

    translated = {
      "name" => true,
      "NAME" => true
    }

    use_test_locales do
      @official.write_export_file_lines(input_lines)
      actual_lines = @official.send_private(:format_export_file,
                                            strings, translated)
      assert_equal(expect_lines, actual_lines)
    end
  end

  def test_create_string
    @official.send_private(:create_string, "number", "uno", "one", dick)

    str = TranslationString.find_by(tag: "number", language: @official)
    assert_not_nil(str, "Cannot find TranslationString")
    assert_equal(1, str.version)
    assert_objs_equal(@official, str.language)
    assert_equal("number", str.tag)
    assert_equal("uno", str.text)
    assert(str.updated_at > 1.minute.ago)
    assert_users_equal(dick, str.user)
    assert_equal(1, str.versions.length)

    ver = str.versions.last
    assert_equal(1, ver.version)
    assert_objs_equal(str, ver.translation_string)
    assert_equal("uno", ver.text)
    assert(ver.updated_at > 1.minute.ago)
    assert_equal(dick.id, ver.user_id)
  end

  def test_update_string
    greek = languages(:greek)
    str = translation_strings(:greek_one)
    assert_equal(2, str.version)
    greek.send_private(:update_string, str, "eins", "ένα", katrina)
    str.reload

    assert_equal(3, str.version)
    assert_objs_equal(greek, str.language)
    assert_equal("one", str.tag)
    assert_equal("eins", str.text)
    assert(str.updated_at > 1.minute.ago)
    assert_users_equal(katrina, str.user)
    assert_equal(3, str.versions.length)

    ver = str.versions.last
    assert_equal(3, ver.version)
    assert_objs_equal(str, ver.translation_string)
    assert_equal("eins", ver.text)
    assert(ver.updated_at > 1.minute.ago)
    assert_equal(katrina.id, str.user_id)

    ver = str.versions[1]
    assert_equal(2, ver.version)
    assert_objs_equal(str, ver.translation_string)
    assert_equal("ένα", ver.text)
    assert(ver.updated_at < 1.minute.ago)
    assert_equal(dick.id, ver.user_id)
  end

  def test_translation_strings_hash
    greek = languages(:greek)
    str1 = translation_strings(:greek_one)
    str2 = translation_strings(:greek_two)
    hash = greek.send_private(:translation_strings_hash)
    assert_equal({ "one" => str1, "two" => str2 }, hash)
  end

  def test_translated_strings
    hash = languages(:greek).translated_strings
    assert_equal({ "one" => "ένα", "two" => "δύο" }, hash)
  end

  def test_localization_strings
    hash = languages(:greek).localization_strings
    assert_equal("ένα", hash["one"])
    assert_equal("δύο", hash["two"])
  end

  def test_import_official
    use_test_locales do
      hash = @official.localization_strings
      assert(hash.length >= 9) # Make sure we got something
      @official.write_hash(hash)
      assert_false(@official.import_from_file(dick),
                   "Shouldn't have been any import changes.")
      assert_false(@official.strip, "Shouldn't have been any strip changes.")
      assert_equal(hash, @official.localization_strings)

      hash["two"] = "twolian"
      hash["five"] = "five"
      hash["unknown_locations"] = "bubkes"
      final_hash = hash.dup
      final_hash.delete("twos")

      @official.write_hash(final_hash)
      assert_true(@official.import_from_file(dick),
                  "Should have been two import changes.")
      assert_equal(hash,
                   @official.localization_strings) # Should still have deletes
      assert_true(@official.strip, "Should have been three strip changes.")
      assert_equal(final_hash,
                   @official.localization_strings) # Deletes should be gone

      assert_equal(
        3, @official.translation_strings.count { |str| str.user == dick }
      )
    end
  end

  # Regression (#4807): stripping a tag must also evict its cache entry --
  # Solid Cache has no delete_matched to catch it later, so a stale
  # cached value would otherwise remain resolvable after the DB row
  # backing it is gone.
  def test_strip_evicts_cached_translation
    use_test_locales do
      greek = languages(:greek)
      @official.write_hash(@official.localization_strings)
      bogus_tag = "_bogus_stripped_tag_for_cache_test"
      greek.translation_strings.create!(tag: bogus_tag, text: "stale value",
                                        user: User.admin)
      value = "stale value"
      I18n.backend.store_translations(:el,
                                      { mo: { bogus_tag.to_sym => value } })
      cache_backend = I18n.backend.backends.first

      assert_equal("stale value",
                   cache_backend.send(:lookup, :el, "mo.#{bogus_tag}"))

      assert_true(greek.strip, "Should have stripped the bogus tag")

      assert_nil(TranslationString.find_by(language: greek, tag: bogus_tag))
      assert_nil(cache_backend.send(:lookup, :el, "mo.#{bogus_tag}"),
                 "strip must evict the cache entry too, not just the DB row")
    end
  end

  # Regression test: import_from_file (the path lang:update's
  # import:official step uses to pull in hand-edited en.txt changes)
  # must refresh the cache too, not just the DB row -- unlike the old
  # file-based backend, Solid Cache persists across deploys/restarts,
  # so a stale cached value would otherwise survive indefinitely (a
  # restart used to be what made an en.txt-driven update visible; it
  # no longer is).
  def test_import_official_refreshes_cache
    use_test_locales do
      hash = @official.localization_strings
      @official.write_hash(hash)

      stale_value = "stale cached one"
      I18n.backend.store_translations(:en, { mo: { one: stale_value } })
      cache_backend = I18n.backend.backends.first
      assert_equal(stale_value, cache_backend.send(:lookup, :en, "mo.one"))

      final_hash = hash.dup
      final_hash["one"] = "updated one"
      @official.write_hash(final_hash)

      assert_true(@official.import_from_file(dick),
                  "Should have imported the changed tag")
      assert_equal(
        "updated one", cache_backend.send(:lookup, :en, "mo.one"),
        "import_from_file must refresh the cache, not just the DB"
      )
    end
  end

  def test_import_unofficial
    use_test_locales do
      greek = languages(:greek)

      # Must specify a user to import an unofficial locale!
      assert_raises(RuntimeError) { greek.import_from_file }

      hash = greek.localization_strings

      # This is just the template.
      @official.write_export_file_lines([
                                          "  one: one\n",
                                          "  two: two\n",
                                          "  twos: twos\n",
                                          "  three: three\n",
                                          "  four: four\n"
                                        ])

      greek.write_export_file_lines([
                                      "  five: ignore me\n"
                                    ])
      assert_false(greek.import_from_file(katrina),
                   "Shouldn't have been any import changes.")
      assert_false(greek.strip, "Shouldn't have been any strip changes.")
      assert_equal(hash, greek.localization_strings)

      data = [
        "  one: one\n", # take this because it is a change from original ένα
        "  twos:  twos\n",   # ignore this because unchanged from template
        "  three:  τρία\n",  # take this change even though still indented
        "  four: τέσσερα\n"  # this is correct, it had better take this!
      ]
      greek.write_export_file_lines(data)
      assert_true(greek.import_from_file(katrina),
                  "Should have been some import changes.")
      assert_false(greek.strip, "Shouldn't have been any strip changes.")
      hash["one"] = "one"
      hash["three"] = "τρία"
      hash["four"] = "τέσσερα"
      assert_equal(hash, greek.localization_strings)
    end
  end
end
