# frozen_string_literal: true

#
#  = Flash Integration Test Helpers
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

module FlashIntegrationExtensions
  # Get the errors rendered in the last request, or current set of errors if
  # redirected.
  def get_full_flash
    # puts "-" * 80
    # puts "We are in flash_extensions get_full_flash"
    # puts "@last_notice"
    # pp @controller.instance_variable_get("@last_notice")
    # puts "session[:notice]"
    # pp session[:notice]
    # puts "-" * 80
    got = session[:notice]
    # if needed: ActionController::Base.helpers.strip_tags(string)
    # session[:notice]
  end

  def get_flash_level
    got = session[:notice]
    if got
      got[0, 1].to_i
    end
  end

  # This is necessary because the session[:notice] never gets cleared by test,
  # even though it is cleared by our flash_clear in layouts/application
  def get_last_flash
    # if !got.present?
    got = session[:notice]
    # end
    if got.present?
      # puts "unprocessed got"
      # pp got
      # This regex gets the contents of the last paragraph tag
      got = got.match(/.*<p>([^<]*)<\/p>/)
      # puts "processed got"
      # pp got
      # byebug
      got = got[1]
      # puts "got[1]"
      # pp got
    end
    got
    # if needed: ActionController::Base.helpers.strip_tags(string)
    # session[:notice]
  end

  # Assert that there was no notice, warning or error.
  def assert_no_flash(msg = "")
    puts "-" * 80
    puts "We are in flash_extensions assert_no_flash"
    puts "-" * 80
    assert_flash(nil, msg)
  end

  # Assert that there was a notice but no warning or error.
  def assert_flash_success(msg = "Should be flash success (level 0).")
    puts "-" * 80
    puts "We are in flash_extensions assert_flash_success"
    puts "-" * 80
    assert_flash(0, msg)
  end

  # Assert that there was warning but no error.
  def assert_flash_warning(
    msg = "Should be a flash warning but no error (level 1)"
  )
    puts "-" * 80
    puts "We are in flash_extensions assert_flash_warning"
    puts "-" * 80
    assert_flash(1, msg)
  end

  # Assert that there was a error.
  def assert_flash_error(msg = "Should be a flash error (level 2).")
    puts "-" * 80
    puts "We are in flash_extensions assert_flash_error"
    puts "-" * 80
    assert_flash(2, msg)
  end

  # Assert that an error was rendered or is pending.
  # Regex is here (<p>[^<p>]+<\/p>$)
  def assert_flash(expect, msg = "")
    puts "-" * 80
    puts "We are in flash_extensions assert_flash"
    puts "-" * 80
    if (session[:notice])
      # lvl = got[0, 1].to_i
      lvl = get_flash_level
      # got = got[1..].gsub(/(\n|<br.?>)+/, "\n")
      got = get_last_flash
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
    # @controller.instance_variable_set("@last_notice", nil)
    # session[:notice] = nil
  end

  # Seems to be a duplicate. Delete?
  # Assert that a flash was rendered or is pending with the expected text.
  def assert_flash_text(expect, msg = "Flash text incorrect")
    puts "-" * 80
    puts "We are in flash_extensions assert_flash_text"
    puts "-" * 80
    # got = get_full_flash
    # got = got[1..] if got.present?
    # got = got[1..].gsub(/(\n|<br.?>)+/, "\n") if got.present?
    # got = got[1..].match(/(<p>[^<p>]+<\/p>$)/) if got.present?
    # got = got[1];
    # got = get_last_flash(got) if got.present?
    # puts "got"
    # pp got
    # byebug
    got = get_last_flash

    if expect.is_a?(Regexp)
      assert_match(expect, got, msg)
    else
      # assert_equal("<p>#{expect}</p>", got, msg)
      # Now that we're grabbing the contents of the <p>
      assert_equal(expect, got, msg)
    end

    # @controller.instance_variable_set("@last_notice", nil)
    # session[:notice] = nil
  end
end
