# frozen_string_literal: true

#
#  = Flash Test Helpers
#
#  Methods in this class are available to all the functional and integration
#  tests.
#
#  get_last_flash::       Retrieve current list of errors or last set rendered.
#  assert_flash::         Assert an error was rendered or is pending, or
#                         that its text matches a tag (or tags).
#  assert_no_flash::      Assert there was no notice, warning or error.
#  assert_flash_success:: Assert there was a notice but no warning or error.
#  assert_flash_warning:: Assert there was a warning but no error.
#  assert_flash_error::   Assert there was an error.
#
################################################################################

module FlashExtensions
  # Get the errors rendered in the last request, or current set of errors if
  # redirected.
  def get_last_flash
    @controller.instance_variable_get(:@last_notice) || session[:notice]
  end

  # Assert that there was no notice, warning or error.
  def assert_no_flash(on_fail: "")
    assert_flash(nil, on_fail:)
  end

  # Assert that there was a notice but no warning or error, optionally
  # also asserting its content (same `expect`/**args as assert_flash).
  def assert_flash_success(expect = nil,
                           on_fail: "Should be flash success (level 0).",
                           **args)
    assert_flash_at_level(0, expect, on_fail:, **args)
  end

  # Assert that there was warning but no error, optionally also
  # asserting its content (same `expect`/**args as assert_flash).
  def assert_flash_warning(
    expect = nil,
    on_fail: "Should be a flash warning but no error (level 1)", **args
  )
    assert_flash_at_level(1, expect, on_fail:, **args)
  end

  # Assert that there was an error, optionally also asserting its
  # content (same `expect`/**args as assert_flash).
  def assert_flash_error(expect = nil,
                         on_fail: "Should be a flash error (level 2).",
                         **args)
    assert_flash_at_level(2, expect, on_fail:, **args)
  end

  # Shared by assert_flash_success/warning/error. Checks the level
  # directly (without consuming the flash) so a subsequent content
  # check can still see it -- assert_flash(expect, ...) itself calls
  # clear_flash at the end, so chaining two full assert_flash calls
  # would have the first one wipe the flash before the second could
  # read it.
  def assert_flash_at_level(level, expect, on_fail:, **args)
    if expect
      if (got = get_last_flash)
        lvl = got[0, 1].to_i
        assert_equal(
          level, lvl,
          "#{on_fail}Wrong flash level. Message: level #{lvl}, " \
          "#{got.inspect}."
        )
      end
      assert_flash(expect, on_fail:, **args)
    else
      assert_flash(level, on_fail:)
    end
  end

  # Assert that an error was rendered or is pending.
  #
  # expect: nil (no flash), an Integer (flash level only), a bare
  # Symbol tag (resolved via .t, with **args as its interpolation
  # args), or an Array of tags for a message built from more than one
  # (each entry either a bare Symbol or a [Symbol, args_hash] pair).
  # on_fail: description shown by MiniTest if the assertion fails --
  # not the expected flash content itself (that's `expect`/`args`).
  #
  # object_error_type/object_error_attribute: pass BOTH together, and
  # ONLY on a bare-Symbol `expect` asserting a flash_object_errors(record)
  # validation message whose tag doesn't already read as a complete
  # sentence -- AbstractModel#formatted_errors then composes it as
  # "<Type> <attribute> <message>." (see its source) instead of using
  # the resolved tag as-is, so `expect` alone can't express it:
  # assert_flash(:not_a_number, object_error_type: :name,
  #                             object_error_attribute: :icn_id)
  # wrapped_flash_text raises if these show up inside an Array entry --
  # that shape means a generic tag is being flashed alongside the
  # object error, which is a production redundancy to fix, not a case
  # to encode here. Leave both nil/omitted for every other call -- the
  # vast majority of flash_notice/flash_warning/flash_error sites need
  # nothing beyond expect/**args.
  def assert_flash(expect, on_fail: "", object_error_type: nil,
                   object_error_attribute: nil, **args)
    validate_object_error_kwargs(expect, object_error_type,
                                 object_error_attribute)
    if (got = get_last_flash)
      lvl = got[0, 1].to_i
      got = got[1..].gsub(/(\n|<br.?>)+/, "\n")
    end
    on_fail = on_fail.to_s.sub(/\n*$/, "\n")
    args[:object_error_type] = object_error_type if object_error_type
    if object_error_attribute
      args[:object_error_attribute] = object_error_attribute
    end

    expected, actual, msg = flash_comparison(expect, got, lvl, on_fail, args)
    assert_equal_even_if_nil(expected, actual, msg)

    clear_flash
  end

  # The four `assert_flash` cases don't all compare `expect` against
  # the same thing (an Integer means "compare to the flash level", a
  # Symbol/Array means "compare to the rendered text") -- so pick the
  # right (expected, actual, message) triple here, then the caller
  # runs one nil-aware `assert_equal_even_if_nil` for all of them.
  def flash_comparison(expect, got, lvl, on_fail, args)
    if !expect && !got
      [expect, got, nil] # both nil -- the assert_no_flash happy path
    elsif !expect && got
      [expect, got,
       "#{on_fail}Shouldn't have been any flash errors. Got #{got.inspect}."]
    elsif expect && !got
      [expect, got, "#{on_fail}Expected a flash error.  Got nothing."]
    elsif expect.is_a?(Integer)
      [expect, lvl,
       "#{on_fail}Wrong flash error level. " \
       "Message: level #{lvl}, #{got.inspect}."]
    elsif expect.is_a?(Symbol) || expect.is_a?(Array)
      text = wrapped_flash_text(expect, args)
      [text, got,
       "#{on_fail}Got the wrong flash error(s). " \
       "Expected: #{text.inspect}.  Got: #{got.inspect}."]
    else
      raise_bad_flash_expectation(expect)
    end
  end

  def clear_flash
    @controller.instance_variable_set(:@last_notice, nil)
    session[:notice] = nil
  end

  private

  # object_error_type:/object_error_attribute: must be passed together
  # (a lone one silently degrades to a plain-tag comparison instead of
  # the intended composite -- fail fast instead) and only make sense
  # on a bare-Symbol `expect` (top-level kwargs are otherwise silently
  # dropped, since an Array's entries carry their own args).
  def validate_object_error_kwargs(expect, type, attribute)
    if type.nil? ^ attribute.nil?
      raise(
        "object_error_type: and object_error_attribute: must be " \
        "passed together, or not at all."
      )
    end
    return unless expect.is_a?(Array) && (type || attribute)

    raise(
      "object_error_type:/object_error_attribute: only apply to a " \
      "bare-Symbol expect -- an Array expect can't express them (that " \
      "shape means a generic tag is being flashed alongside the " \
      "object error, which is a production bug to fix, not something " \
      "to assert -- see wrapped_flash_text's own raise)."
    )
  end

  # flash_notice/flash_warning/flash_error each wrap every message they're
  # given in its own "<p>...</p>" -- whether from one call with several
  # args or several accumulated calls across a request -- with no
  # separator between blocks. An Array here means "these tags each fired
  # their own flash call, in this order", so each gets its own <p> block
  # rather than being joined into one (there's no current call site that
  # needs the single-call multi-tag-in-one-string shape, e.g.
  # account_controller.rb's signup flash -- not currently asserted
  # against by any test).
  def wrapped_flash_text(expect, top_level_args)
    is_array = expect.is_a?(Array)
    entries = is_array ? expect : [[expect, top_level_args]]
    entries.map do |entry|
      tag, tag_args = entry.is_a?(Array) ? entry : [entry, {}]
      tag_args = (tag_args || {}).dup
      type = tag_args.delete(:object_error_type)
      attribute = tag_args.delete(:object_error_attribute)
      if type && attribute
        raise_object_error_combined_with_array if is_array
        object_error_text(type, attribute, tag, tag_args)
      else
        "<p>#{tag.t(**tag_args)}</p>"
      end
    end.join
  end

  # object_error_type:/object_error_attribute: only make sense on the
  # WHOLE expected flash (a bare Symbol `expect`) -- see this record's
  # own validation errors, in full, with nothing else. Seeing them
  # inside an Array entry means a generic tag is being flashed
  # alongside a flash_object_errors(record) message, which is always a
  # production redundancy (the specific error already says everything
  # the generic one implied) -- fix the controller's rescue/flash
  # handler instead, the way NamesController#reload_name_form_on_error
  # was fixed, rather than encoding the redundancy here.
  def raise_object_error_combined_with_array
    raise(
      "object_error_type:/object_error_attribute: inside an assert_flash " \
      "Array entry usually means a generic tag is being flashed " \
      "alongside a flash_object_errors(record) validation message -- " \
      "that's a production bug to fix (see " \
      "NamesController#reload_name_form_on_error for the fix), not " \
      "something to encode in the test."
    )
  end

  # Mirrors AbstractModel#formatted_errors' exact formula for a single
  # validation error: a complete-sentence message (starts uppercase,
  # e.g. from `errors.add(:base, :some_tag)`) stands alone; otherwise
  # it's prefixed with the object type and attribute name.
  def object_error_text(type, attribute, tag, tag_args)
    message = tag.t(**(tag_args || {}))
    message = "#{type.ti} #{attribute.l} #{message}." unless
      /^[A-Z]/.match?(message)
    "<p>#{message}</p>"
  end

  def raise_bad_flash_expectation(expect)
    raise(ArgumentError.new(
            "assert_flash expects a Symbol tag, an Array of tags, an " \
            "Integer level, or nil -- got #{expect.class} " \
            "(#{expect.inspect}). Pass a bare tag symbol (plus " \
            "interpolation args as keywords), not a pre-resolved " \
            "String/Regexp."
          ))
  end
end
