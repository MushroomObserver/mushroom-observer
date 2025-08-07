# frozen_string_literal: true

#
#  = Application Helpers
#
#  Methods available to all templates in the application:
#
#  css_theme
#  default_container_class
#  container_class
#  default_column_classes
#  column_classes
#  default_content_padding
#  content_padding
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

  # This executes in the layout, but AFTER the template!
  def default_container_class
    return if content_for?(:container_class)

    container_class
  end

  # Set a width class for the layout content container.
  # Defaults to :text width, currently the most common. :wide is for forms
  # These classes are MO-defined
  #
  def container_class(container = :text)
    container ||= :text
    content_for(:container_class, flush: true) do
      case container
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
  end

  # This executes in the layout, but AFTER the template!
  def default_column_classes
    return if content_for?(:left_columns)

    column_classes
  end

  # Call in a layout to sync the title-bar columns with the content columns.
  def column_classes(columns = :twelve)
    content_for(:left_columns, flush: true) do
      case columns
      when :nine_three
        class_names("col-xs-12 col-md-9 col-lg-8")
      when :eight_four
        class_names("col-xs-12 col-md-8 col-lg-7")
      when :seven_five
        class_names("col-xs-12 col-md-7")
      when :six
        class_names("col-xs-12 col-md-6 col-lg-8")
      when :six_even # users show
        class_names("col-xs-12 col-lg-6")
      else
        class_names("col-xs-12")
      end
    end

    content_for(:right_columns, flush: true) do
      case columns
      when :nine_three
        class_names("col-xs-12 col-md-3 col-lg-4")
      when :eight_four
        class_names("col-xs-12 col-md-4 col-lg-5")
      when :seven_five
        class_names("col-xs-12 col-md-5")
      when :six
        class_names("col-xs-12 col-md-6 col-lg-4")
      when :six_even
        class_names("col-xs-12 col-lg-6")
      else
        class_names("col-xs-12")
      end
    end
  end

  # This executes in the layout, but AFTER the template!
  def default_content_padding
    return if content_for?(:content_padding)

    content_padding
  end

  # Set content padding to line up with the title. If it needs different padding
  # from the defaults below, call `content_padding(:panels)` or :no_panels
  # in the template. If it's a mixed layout you can set it to :panels and wrap
  # text blocks in the CSS class `content-block`, which will pad them the same.
  def content_padding(content_has = nil)
    # Give defaults per action.
    content_has ||= case action_name
                    when "index", "show"
                      :panels
                    else
                      :no_panels
                    end
    content_for(:content_padding, flush: true) do
      content_has == :no_panels ? "p-3" : ""
    end
  end

  # This can be called to display flash notices either in the page or a modal.
  # `flash_notices?` `flash_get_notices` `flash_notice_level` and `flash_clear`
  # are defined in ApplicationController::FlashNotices.
  def flash_notices_html
    return "" unless flash_notices?

    notices = flash_get_notices
    alert_class = case flash_notice_level
                  when 0 then "alert-success"
                  when 1 then "alert-warning"
                  when 2 then "alert-danger"
                  end
    flash_clear

    render(partial: "application/app/flash_notices",
           locals: { notices:, alert_class: })
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

  def logged_in_status
    User.current ? "logged_in" : "no_user"
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

    addr + "?" + args.keys.sort.map do |k| # rubocop:disable Style/StringConcatenation
      "#{CGI.escape(k)}=#{args[k] || ""}"
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

  def form_submit_text(obj)
    obj_name = obj.class.model_name.singular.upcase.to_sym.t
    if obj.new_record?
      :create_object.t(TYPE: obj_name)
    else
      :update_object.t(TYPE: obj_name)
    end
  end
end
