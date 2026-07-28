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

  # Assert that there was a notice but no warning or error.
  def assert_flash_success(on_fail: "Should be flash success (level 0).")
    assert_flash(0, on_fail:)
  end

  # Assert that there was warning but no error.
  def assert_flash_warning(
    on_fail: "Should be a flash warning but no error (level 1)"
  )
    assert_flash(1, on_fail:)
  end

  # Assert that there was a error.
  def assert_flash_error(on_fail: "Should be a flash error (level 2).")
    assert_flash(2, on_fail:)
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
  # ONLY when asserting a flash_object_errors(record) validation
  # message -- AbstractModel#formatted_errors composes those as
  # "<Type> <attribute> <message>." (see its source) rather than just
  # resolving one tag, so `expect` alone can't express them. Here
  # they mark the WHOLE `expect` (a bare Symbol) as one object error.
  # For a flash that combines a plain tag with an object error (e.g.
  # a generic "Unable to save changes." followed by the specific
  # field error -- the common flash_object_errors shape), put these
  # same two keys in that one Array entry's own args hash instead:
  # assert_flash([:runtime_unable_to_save_changes,
  #               [:not_a_number, { object_error_type: :name,
  #                                object_error_attribute: :icn_id }]])
  # Leave both nil/omitted for every other call -- the vast majority
  # of flash_notice/flash_warning/flash_error sites need nothing
  # beyond expect/**args.
  def assert_flash(expect, on_fail: "", object_error_type: nil,
                   object_error_attribute: nil, **args)
    if (got = get_last_flash)
      lvl = got[0, 1].to_i
      got = got[1..].gsub(/(\n|<br.?>)+/, "\n")
    end
    on_fail = on_fail.to_s.sub(/\n*$/, "\n")
    args[:object_error_type] = object_error_type if object_error_type
    if object_error_attribute
      args[:object_error_attribute] = object_error_attribute
    end

    if !expect && !got
      # Expected no flash, got no flash — the `assert_no_flash` happy
      # path. No assertion needed; falling through to the `else`
      # branch below ran `assert_equal(nil, nil)` and tripped
      # Minitest's `assert_equal nil, …` deprecation.
      pass
    elsif !expect && got
      assert_nil(
        got,
        "#{on_fail}Shouldn't have been any flash errors. Got #{got.inspect}."
      )
    elsif expect && !got
      assert_nil(expect, "#{on_fail}Expected a flash error.  Got nothing.")
    elsif expect.is_a?(Integer)
      assert_equal(expect, lvl,
                   "#{on_fail}Wrong flash error level. " \
                   "Message: level #{lvl}, #{got.inspect}.")
    elsif expect.is_a?(Symbol) || expect.is_a?(Array)
      text = wrapped_flash_text(expect, args)
      assert_equal(text, got,
                   "#{on_fail}Got the wrong flash error(s). " \
                   "Expected: #{text.inspect}.  Got: #{got.inspect}.")
    else
      raise_bad_flash_expectation(expect)
    end

    clear_flash
  end

  def clear_flash
    @controller.instance_variable_set(:@last_notice, nil)
    session[:notice] = nil
  end

  private

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
    entries = expect.is_a?(Array) ? expect : [[expect, top_level_args]]
    entries.map do |entry|
      tag, tag_args = entry.is_a?(Array) ? entry : [entry, {}]
      tag_args = (tag_args || {}).dup
      type = tag_args.delete(:object_error_type)
      attribute = tag_args.delete(:object_error_attribute)
      if type && attribute
        object_error_text(type, attribute, tag, tag_args)
      else
        "<p>#{tag.t(**tag_args)}</p>"
      end
    end.join
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
