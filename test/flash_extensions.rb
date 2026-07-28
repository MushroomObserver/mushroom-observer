# frozen_string_literal: true

#
#  = Flash Test Helpers
#
#  Methods in this class are available to all the functional and integration
#  tests.
#
#  get_last_flash::       Retrieve current list of errors or last set rendered.
#  assert_flash::         Assert an error was rendered or is pending.
#  assert_no_flash::      Assert there was no notice, warning or error.
#  assert_flash_success:: Assert there was a notice but no warning or error.
#  assert_flash_warning:: Assert there was a warning but no error.
#  assert_flash_error::   Assert there was an error.
#  assert_flash_text::    Assert flash has particular text
#
################################################################################

module FlashExtensions
  # Get the errors rendered in the last request, or current set of errors if
  # redirected.
  def get_last_flash
    @controller.instance_variable_get(:@last_notice) || session[:notice]
  end

  # Assert that there was no notice, warning or error.
  def assert_no_flash(msg: "")
    assert_flash(nil, msg:)
  end

  # Assert that there was a notice but no warning or error.
  def assert_flash_success(msg: "Should be flash success (level 0).")
    assert_flash(0, msg:)
  end

  # Assert that there was warning but no error.
  def assert_flash_warning(
    msg: "Should be a flash warning but no error (level 1)"
  )
    assert_flash(1, msg:)
  end

  # Assert that there was a error.
  def assert_flash_error(msg: "Should be a flash error (level 2).")
    assert_flash(2, msg:)
  end

  # Assert that an error was rendered or is pending.
  #
  # expect: nil (no flash), an Integer (flash level only), a bare
  # Symbol tag (resolved via .t, with **args as its interpolation
  # args), or an Array of tags for a message built from more than one
  # (each entry either a bare Symbol or a [Symbol, args_hash] pair).
  def assert_flash(expect, msg: "", **args)
    if (got = get_last_flash)
      lvl = got[0, 1].to_i
      got = got[1..].gsub(/(\n|<br.?>)+/, "\n")
    end
    msg = msg.to_s.sub(/\n*$/, "\n")

    if !expect && !got
      # Expected no flash, got no flash — the `assert_no_flash` happy
      # path. No assertion needed; falling through to the `else`
      # branch below ran `assert_equal(nil, nil)` and tripped
      # Minitest's `assert_equal nil, …` deprecation.
      pass
    elsif !expect && got
      assert_nil(
        got,
        "#{msg}Shouldn't have been any flash errors. Got #{got.inspect}."
      )
    elsif expect && !got
      assert_nil(expect, "#{msg}Expected a flash error.  Got nothing.")
    elsif expect.is_a?(Integer)
      assert_equal(expect, lvl,
                   "#{msg}Wrong flash error level. " \
                   "Message: level #{lvl}, #{got.inspect}.")
    elsif expect.is_a?(Symbol) || expect.is_a?(Array)
      text = resolve_flash_tags(expect, args)
      assert_equal(text, got,
                   "#{msg}Got the wrong flash error(s). " \
                   "Expected: #{text.inspect}.  Got: #{got.inspect}.")
    else
      raise_bad_flash_expectation("assert_flash", expect)
    end

    clear_flash
  end

  # Assert that a flash was rendered or is pending with the expected text.
  #
  # expect: a bare Symbol tag (resolved via .t, with **args as its
  # interpolation args), or an Array of tags for a message built from
  # more than one (each entry either a bare Symbol or a
  # [Symbol, args_hash] pair).
  def assert_flash_text(expect, msg: "Flash text incorrect", **args)
    got = get_last_flash
    got = got[1..].gsub(/(\n|<br.?>)+/, "\n") if got.present?

    unless expect.is_a?(Symbol) || expect.is_a?(Array)
      raise_bad_flash_expectation("assert_flash_text", expect)
    end

    text = resolve_flash_tags(expect, args)
    assert_equal("<p>#{text}</p>", got, msg)

    clear_flash
  end

  def clear_flash
    @controller.instance_variable_set(:@last_notice, nil)
    session[:notice] = nil
  end

  private

  def resolve_flash_tags(expect, top_level_args)
    if expect.is_a?(Array)
      expect.map do |entry|
        tag, tag_args = entry.is_a?(Array) ? entry : [entry, {}]
        tag.t(**(tag_args || {}))
      end.join(" ")
    else
      expect.t(**top_level_args)
    end
  end

  def raise_bad_flash_expectation(method, expect)
    raise(ArgumentError.new(
            "#{method} expects a Symbol tag, an Array of tags, an " \
            "Integer level, or nil -- got #{expect.class} " \
            "(#{expect.inspect}). Pass a bare tag symbol (plus " \
            "interpolation args as keywords), not a pre-resolved " \
            "String/Regexp."
          ))
  end
end
