# frozen_string_literal: true

#
#  = Application Helpers
#
#  Methods available to all templates in the application:
#
#  css_theme
#  indent                       # in-lined white-space element of n pixels
#  add_header                   # add to html header from within view
#  reload_with_args             # add args to url that got us to this page
#  add_args_to_url              # change params of arbitrary url
#  get_next_id
#
module ApplicationHelper
  # All helpers are autoloaded under Zeitwerk
  def css_theme(user = nil)
    if in_admin_mode?
      "Admin"
    elsif session[:real_user_id].present?
      "Sudo"
    elsif browser.bot? || !user
      MO.default_theme
    elsif MO.themes.member?(controller.action_name)
      # when looking at a theme's info page render it in that theme
      controller.action_name
    elsif user && user&.theme.present? && MO.themes.member?(user.theme)
      user.theme
    elsif user
      MO.themes.sample
    end
  end

  # This can be called to display flash notices either in the page or a modal.
  # `flash_notices?` `flash_get_notices` `flash_notice_level` and `flash_clear`
  # are defined in ApplicationController::FlashNotices.
  def flash_notices_html
    return "" unless flash_notices?

    notices = flash_get_notices
    level = case flash_notice_level
            when 0 then :success
            when 1 then :warning
            when 2 then :danger
            end
    flash_clear

    render(Components::Alert.new(
             level: level, id: "flash_notices", class: "mt-3"
           )) { notices }
  end

  def render_turbo_stream_flash_messages
    turbo_stream.update("page_flash") { flash_notices_html }
  end

  # Returns a string that indicates the current user/logged_in/admin status.
  # Used as a simple cache key for templates that may have three
  # possible versions of cached HTML
  def user_status_string(user = nil)
    if in_admin_mode?
      "admin_mode"
    elsif browser.bot?
      "robot"
    elsif !user.nil?
      "logged_in"
    else
      "no_user"
    end
  end

  # ----------------------------------------------------------------------------

  # Take URL that got us to this page and add one or more parameters to it.
  # Returns new URL.
  #
  #   link_to("Next Page", reload_with_args(page: 2))
  #
  def reload_with_args(new_args)
    uri = request.url.sub(%r{^\w+:/+[^/]+}, "")
    add_args_to_url(uri, new_args)
  end

  # Take an arbitrary URL and change the parameters. Returns new URL. Should
  # even handle the fancy "/object/id" case. (Note: use +nil+ to mean delete
  # -- i.e. <tt>add_args_to_url(url, old_arg: nil)</tt> deletes the
  # parameter named +old_arg+ from +url+.)
  #
  #   url = url_for(action: "blah", ...)
  #   new_url = add_args_to_url(url, arg1: :val1, arg2: :val2, ...)
  #
  def add_args_to_url(url, new_args)
    new_args = new_args.clone

    # Garbage in, garbage out...
    return url unless url.valid_encoding?

    # Parse parameters off of current URL using Rack to handle nested/array
    # params like q[by_user][]=1&q[by_user][]=2
    addr, parms = url.split("?")
    args = parms ? Rack::Utils.parse_nested_query(parms) : {}

    # Deal with the special "/xxx/id" case.
    if %r{/(\d+)$}.match?(addr)
      new_id = new_args[:id] || new_args["id"]
      addr.sub!(/\d+$/, new_id.to_s) if new_id
      new_args.delete(:id)
      new_args.delete("id")
    end

    # Merge in new arguments, deleting where new values are nil.
    new_args.each_key do |var|
      val = new_args[var]
      if val.nil?
        args.delete(var.to_s)
      elsif val.is_a?(ActiveRecord::Base)
        args[var.to_s] = val.id.to_s
      else
        args[var.to_s] = val.to_s
      end
    end

    # Put it back together using Hash#to_query to properly encode nested params
    return addr if args.empty?

    "#{addr}?#{args.to_query}"
  end
end
