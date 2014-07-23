# encoding: utf-8
#
#  = Flash Test Helpers
#
#  Methods in this class are available to all the functional and integration
#  tests.
#
#  get_last_flash::       Retrieve the current list of errors or last set rendered.
#  assert_flash::         Assert that an error was rendered or is pending.
#  assert_no_flash::      Assert that there was no notice, warning or error.
#  assert_flash_success:: Assert that there was a notice but no warning or error.
#  assert_flash_warning:: Assert that there was a warning but no error.
#  assert_flash_error::   Assert that there was an error.
#
################################################################################

module FlashExtensions

  # Get the errors rendered in the last request, or current set of errors if
  # redirected.
  def get_last_flash
    flash[:rendered_notice] || session[:notice]
  end

  # Assert that there was no notice, warning or error.
  def assert_no_flash(msg='')
    assert_flash(nil, msg)
  end

  # Assert that there was a notice but no warning or error.
  def assert_flash_success(msg='')
    assert_flash(0, msg)
  end

  # Assert that there was warning but no error.
  def assert_flash_warning(msg='')
    assert_flash(1, msg)
  end

  # Assert that there was a error.
  def assert_flash_error(msg='')
    assert_flash(2, msg)
  end

  # Assert that an error was rendered or is pending.
  def assert_flash(expect, msg='')
    if got = get_last_flash
      lvl = got[0,1].to_i
      got = got[1..-1].gsub(/(\n|<br.?>)+/, "\n")
    end
    msg.sub(/\n*$/, "\n") if msg
    if !expect && got
      assert_block(msg + "Shouldn't have been any flash errors.  Got #{got.inspect}.") { got.nil? }
    elsif expect && !got
      assert_block(msg + "Expected a flash error.  Got nothing.") { expect.nil? }
    elsif expect.is_a?(Fixnum)
      assert_block(msg + "Wrong flash error level.  Message: #{got.inspect}.") { expect == lvl }
    elsif expect.is_a?(Regexp)
      assert_block(msg + "Got the wrong flash error(s). " +
                         "Expected: #{expect.inspect}.  Got: #{got.inspect}.") { got.match(expect) }
    else
      assert_block(msg + "Got the wrong flash error(s). " +
                         "Expected: #{expect.inspect}.  Got: #{got.inspect}.") { got == expect }
    end
    flash[:rendered_notice] = nil
    session[:notice] = nil
  end
end
