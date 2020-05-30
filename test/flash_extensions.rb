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
    @controller.instance_variable_get("@last_notice") || session[:notice]
  end

  # Assert that there was no notice, warning or error.
  def assert_no_flash(msg = "")
    assert_flash(nil, msg)
  end

  # Assert that there was a notice but no warning or error.
  def assert_flash_success(msg = "Should be flash success (level 0).")
    assert_flash(0, msg)
  end

  # Assert that there was warning but no error.
  def assert_flash_warning(
    msg = "Should be a flash warning but no error (level 1)"
  )
    assert_flash(1, msg)
  end

  # Assert that there was a error.
  def assert_flash_error(msg = "Should be a flash error (level 2).")
    assert_flash(2, msg)
  end

  # Assert that an error was rendered or is pending.
  def assert_flash(expect, msg = "")
    if (got = get_last_flash)
      lvl = got[0, 1].to_i
      got = got[1..].gsub(/(\n|<br.?>)+/, "\n")
    end
    msg&.sub(/\n*$/, "\n")
    if !expect && got
      assert(got.nil?,
             "#{msg} Shouldn't have been any flash errors. Got #{got.inspect}.")
    elsif expect && !got
      assert(expect.nil?, "#{msg} Expected a flash error.  Got nothing.")
    elsif expect.is_a?(Integer)
      assert(expect == lvl,
             "#{msg} Wrong flash error level. "\
             "Message: level #{lvl}, #{got.inspect}.")
    elsif expect.is_a?(Regexp)
      assert(got.match(expect),
             "#{msg} Got the wrong flash error(s). " \
             "Expected: #{expect.inspect}.  Got: #{got.inspect}.")
    else
      assert(got == expect,
             "#{msg} Got the wrong flash error(s). " \
             "Expected: #{expect.inspect}.  Got: #{got.inspect}.")
    end
    @controller.instance_variable_set("@last_notice", nil)
    session[:notice] = nil
  end

  # Assert that a flash was rendered or is pending with the expected text.
  def assert_flash_text(expect, msg = "Flash text incorrect")
    got = get_last_flash
    got = got[1..].gsub(/(\n|<br.?>)+/, "\n") if got.present?
    if expect.is_a?(Regexp)
      assert_match(expect, got, msg)
    else
      assert_equal("<p>#{expect}</p>", got, msg)
    end

    @controller.instance_variable_set("@last_notice", nil)
    session[:notice] = nil
  end
end
