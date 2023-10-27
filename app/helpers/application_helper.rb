# frozen_string_literal: true

#
#  = Application Helpers
#
#  Methods available to all templates in the application:
#
#  css_theme
#  container_class
#
#  --------------------------
#
#  indent                       # in-lined white-space element of n pixels
#  add_header                   # add to html header from within view
#  reload_with_args             # add args to url that got us to this page
#  add_args_to_url              # change params of arbitrary url
#  url_after_delete             # url to return to after deleting object
#  get_next_id
#
module ApplicationHelper
  # All helpers are autoloaded under Zeitwerk

  def css_theme
    if in_admin_mode?
      "Admin"
    elsif session[:real_user_id].present?
      "Sudo"
    elsif browser.bot? || !@user
      MO.default_theme
    elsif MO.themes.member?(controller.action_name)
      # when looking at a theme's info page render it in that theme
      controller.action_name
    elsif @user && @user&.theme.present? &&
          MO.themes.member?(@user.theme)
      @user.theme
    elsif @user
      MO.themes.sample
    end
  end

  # Return a width class for the layout content container.
  # Defaults to :text width, currently the most common. :wide is for forms
  # These classes are MO-defined
  #
  def container_class
    @container ||= :text
    case @container
    when :text
      "container-text"
    when :text_image
      "container-text-image"
    when :wide
      "container-wide"
    else
      "container-full"
    end
  end

  # This can be called to display flash notices either in the page or a modal.
  # Send it an html `id` to be able to find the notices via JS later.
  def flash_notices_html
    return "" unless flash_notices?

    alert_class = case flash_notice_level
                  when 0 then "alert-success"
                  when 1 then "alert-warning"
                  when 2 then "alert-danger"
                  end

    notices = flash_get_notices
    flash_clear

    tag.div(notices, id: "flash_notices",
                     class: class_names("alert mt-3", alert_class))
  end

  # ----------------------------------------------------------------------------

  # Add something to the header from within view.  This can be called as many
  # times as necessary -- the application layout will mash them all together
  # and stick them at the end of the <tt>&gt;head&lt;/tt> section.
  #
  #   <%
  #     add_header(GMap.header)       # adds GMap general header
  #     gmap = make_map(@locations)
  #     add_header(finish_map(gmap))  # adds map-specific header
  #   %>
  #
  def add_header(str)
    @header ||= safe_empty
    @header += str
  end

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
    args = {}

    # Garbage in, garbage out...
    return url unless url.valid_encoding?

    # Parse parameters off of current URL.
    addr, parms = url.split("?")
    (parms ? parms.split("&") : []).each do |arg|
      var, val = arg.split("=")
      next unless var && var != ""

      var = CGI.unescape(var)
      # See note below about precedence in case of redundancy.
      args[var] = val unless args.key?(var)
    end

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
        args[var.to_s] = CGI.escape(val.to_s)
      end
    end

    # Put it back together.
    return addr if args.keys.empty?

    addr + "?" + args.keys.sort.map do |k|
      CGI.escape(k) + "=" + (args[k] || "")
    end.join("&")
  end

  # Returns URL to return to after deleting an object.  Can't just return to
  # the index, because we'd prefer to return to the correct page in the index,
  # but to do that we need to know the id of next object.
  def url_after_delete(object)
    return nil unless object

    id = get_next_id(object)
    args = {
      controller: object.show_controller,
      action: object.index_action
    }
    args[:id] = id if id
    url_for(add_query_param(args))
  end

  def get_next_id(object)
    query = passed_query
    return nil unless query
    return nil unless query.model.to_s == object.class.name

    idx = query.index(object)
    return nil unless idx

    query.result_ids[idx + 1] || query.result_ids[idx - 1]
  end
end
