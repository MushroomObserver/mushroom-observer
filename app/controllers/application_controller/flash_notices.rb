# frozen_string_literal: true

# see application_controller.rb
module ApplicationController::FlashNotices
  def self.included(base)
    base.helper_method(
      :flash_notices?, :flash_get_notices, :flash_notice_level,
      :flash_clear, :flash_notice, :flash_warning, :flash_error
    )
  end

  ##############################################################################
  #
  #  :section: Error handling
  #
  #  NOTE: MO doesn't use built-in Rails `flash`, i.e. session[:flash].
  #        We get and set our own session[:notice]. This means the Rails methods
  #        `flash` and `flash_hash` don't return any of our messages.
  #
  #  This is somewhat non-intuitive, so it's worth describing exactly what
  #  happens.  There are two fundamentally different cases:
  #
  #  1. Request is rendered successfully (200).
  #
  #  Errors that occur while processing the action are added to
  #  <tt>session[:notice]</tt>.  They are rendered in the layout, then cleared.
  #  If they weren't cleared, they would carry through to the next action (via
  #  +flash+ mechanism) and get rendered twice (or more!).
  #
  #  2. Request is redirected (302).
  #
  #  Errors that occur while processing the action are added to
  #  <tt>session[:notice]</tt> as before.  Browser is redirected.  This may
  #  happen multiple times before an action finally renders a template.  Once
  #  this finally happens, all the errors that have accumulated in
  #  <tt>session[:notice]</tt> are displayed, then cleared.
  #
  #  *NOTE*: I just noticed that we've been incorrectly using the +flash+
  #  mechanism for this all along.  This can fail if you flash an error,
  #  redirect, then redirect again without rendering any additional error.
  #  If you don't change a flash field it automatically gets cleared.
  #
  ##############################################################################

  # Are there any errors pending?  Returns true or false.
  def flash_notices?
    !session[:notice].nil?
  end
  # helper_method :flash_notices?

  # Get a copy of the errors.  Return as String.
  def flash_get_notices
    # Maybe there is a cleaner way to do this.  session[:notice] should
    # already be html_safe, but the substring marks it as unsafe. Maybe there
    # is a way to test if it's html_safe before, and if so, then it should be
    # okay to remove the first character without making it html_unsafe??
    session[:notice].to_s[1..].html_safe # rubocop:disable Rails/OutputSafety
  end
  # helper_method :flash_get_notices

  # Get current notice level. (0 = notice, 1 = warning, 2 = error)
  def flash_notice_level
    level = session[:notice].to_s[0, 1]
    level == "" ? nil : level.to_i
  end
  # helper_method :flash_notice_level

  # Clear error/warning messages. *NOTE*: This is done automatically by the
  # application layout (app/views/layouts/application.rhtml) every time it
  # renders the latest error messages.
  def flash_clear
    @last_notice = session[:notice] if Rails.env.test?
    session[:notice] = nil
  end
  # helper_method :flash_clear

  # Report an informational message that will be displayed (in green) at the
  # top of the next page the User sees.
  def flash_notice(*strs)
    session[:notice] ||= "0"
    session[:notice] += strs.map { |str| "<p>#{str}</p>" }.join
    true
  end
  # helper_method :flash_notice

  # Report a warning message that will be displayed (in yellow) at the top of
  # the next page the User sees.
  def flash_warning(*)
    flash_notice(*)
    session[:notice][0, 1] = "1" if session[:notice][0, 1] == "0"
    false
  end
  # helper_method :flash_warning

  # Report an error message that will be displayed (in red) at the top of the
  # next page the User sees.
  def flash_error(*)
    flash_notice(*)
    session[:notice][0, 1] = "2" if session[:notice][0, 1] != "2"
    false
  end
  # helper_method :flash_error

  def flash_object_errors(obj)
    return unless obj&.errors && !obj.errors.empty?

    obj.formatted_errors.each { |error| flash_error(error) }
    false
  end

  def save_with_log(user, obj)
    type_sym = obj.class.to_s.underscore.to_sym
    obj.current_user = user if obj.respond_to?(:current_user)
    if obj.save
      notice = if obj.respond_to?(:text_name) && (name = obj.text_name)
                 :runtime_created_name.t(type: type_sym, value: name)
               else
                 :runtime_created_at.t(type: type_sym)
               end
      flash_notice(notice)
      true
    else
      flash_error(:runtime_no_save.t(type: type_sym))
      flash_object_errors(obj)
      false
    end
  end

  def validate_object(obj)
    result = obj.valid?
    flash_object_errors(obj) unless result
    result
  end
end
