# frozen_string_literal: true

#
#  = Application Controller Base Class
#
#  This is the base class for all the application's controllers.  It contains
#  all the important application-wide filters and lots of helper methods.
#  Anything that appears here is available to every controller and view.
#
#  == Filters
#
#  autologin::          Determine which if any User is logged in.
#  set_locale::         Determine which language is requested.
#
#  == Methods
#  *NOTE*: Methods in parentheses are "private" helpers; you are encouraged to
#  use the public ones instead.
#
#  ==== User authentication
#  autologin::              (filter: determine which user is logged in)
#  login_for_ajax::         (filter: minimal version of autologin for ajax)
#  check_permission::       Make sure current User is the right one.
#  check_permission!::      Same, but flashes "denied" message, too.
#  reviewer?::              Is the current User a reviewer?
#  in_admin_mode?::         Is the current User in admin mode?
#  unshown_notifications?:: Are there pending Notification's of a given type?
#  autologin_cookie_set::   (set autologin cookie)
#  clear_autologin_cookie:: (clear autologin cookie)
#  session_user_set::       (store user in session -- id only)
#  session_user::           (retrieve user from session)
#
#  ==== Internationalization
#  all_locales::            Array of available locales for which we have
#                           translations.
#  set_locale::             (filter: determine which locale is requested)
#  set_timezone::           (filter: Set timezone from cookie set by client's
#                            browser.)
#  sorted_locales_from_request_header::
#                           (parse locale preferences from request header)
#  valid_locale_from_request_header::
#                           (choose locale that best matches request header)
#
#  ==== Error handling
#  flash_notices?::         Are there any errors pending?
#  flash_get_notices::      Get list of errors.
#  flash_notice_level::     Get current notice level.
#  flash_clear::            Clear error messages.
#  flash_notice::           Add a success message.
#  flash_warning::          Add a warning message.
#  flash_error::            Add an error message.
#  flash_object_errors::    Add all errors for a given instance.
#
#  ==== Name validation
#  construct_approved_names:: Creates a list of names if they've been approved.
#  construct_approved_name::  (helper)
#
#  ==== Searching
#  clear_query_in_session:: Clears out Query stored in session below.
#  store_query_in_session:: Stores Query in session for use by
#                           create_species_list.
#  query_from_session::     Gets Query that was stored in the session above.
#  query_params::           Parameters to add to link_to, etc. for passing
#                           Query around.
#  query_params_set::       Make +query_params+ refer to a given Query.
#  pass_query_params::      Tell +query_params+ to pass-through the Query
#                            given to this action.
#  find_query::             Find a given Query or return nil.
#  find_or_create_query::   Find appropriate Query or create as necessary.
#  create_query::           Create a new Query from scratch.
#  redirect_to_next_object:: Find next object from a Query and redirect to its
#                            show page.
#
#  ==== Indexes
#  show_index_of_objects::  Show paginated set of Query results as a list.
#  add_sorting_links::      Create sorting links for index pages.
#  find_or_goto_index::     Look up object by id, displaying error and
#                           redirecting on failure.
#  goto_index::             Redirect to a reasonable fallback (index) page
#                           in case of error.
#  paginate_letters::       Paginate an Array by letter.
#  paginate_numbers::       Paginate an Array normally.
#
#  ==== Memory usage
#  extra_gc::               (filter: calls <tt>ObjectSpace.garbage_collect</tt>)
#
#  ==== Other stuff
#  disable_link_prefetching::    (filter: prevents prefetching of destroy
#                                 methods)
#  update_view_stats::           Called after each show_object request.
#  calc_layout_params::          Gather User's list layout preferences.
#  catch_errors_and_log_request_stats::
#                                (filter: catches errors for integration tests)
#  default_thumbnail_size::      Default thumbnail size: :thumbnail or :small.
#  default_thumbnail_size_set::  Change default thumbnail size for current user.
#
class ApplicationController < ActionController::Base
  require "extensions"
  require "login_system"
  require "csv"
  include LoginSystem

  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  around_action :catch_errors_and_log_request_stats
  before_action :kick_out_excessive_traffic
  before_action :kick_out_robots
  before_action :create_view_instance_variable
  before_action :verify_authenticity_token
  before_action :fix_bad_domains
  before_action :autologin
  before_action :redirect_anonymous_users
  before_action :set_locale
  before_action :set_timezone
  before_action :refresh_translations
  before_action :track_translations
  # before_action :extra_gc
  # after_action  :extra_gc

  # Make show_name_helper available to nested partials
  helper :show_name

  # Disable all filters except set_locale.
  # (Used to streamline API and Ajax controllers.)
  def self.disable_filters
    skip_before_action(:redirect_anonymous_users)
    skip_before_action(:create_view_instance_variable)
    skip_before_action(:verify_authenticity_token)
    skip_before_action(:fix_bad_domains)
    skip_before_action(:autologin)
    skip_before_action(:set_timezone)
    skip_before_action(:refresh_translations)
    skip_before_action(:track_translations)
    before_action(:disable_link_prefetching)
    before_action { User.current = nil }
  end

  # Disables Bullet tester for one action. Use this in your controller:
  #   around_action :skip_bullet, if: -> { defined?(Bullet) }, only: [ ... ]
  def skip_bullet
    Bullet.n_plus_one_query_enable = false
    yield
  ensure
    Bullet.n_plus_one_query_enable = true
  end

  ## @view can be used by classes to access view specific features like render
  def create_view_instance_variable
    @view = view_context
  end

  # Utility for extracting nested params where any level might be nil
  def param_lookup(path, default = nil)
    result = params
    path.each do |arg|
      result = result[arg]
      break if result.nil?
    end
    if result.nil?
      default
    else
      block_given? ? yield(result) : result
    end
  end

  # Kick out agents responsible for excessive traffic.
  def kick_out_excessive_traffic
    return true unless IpStats.blocked?(request.remote_ip)
    return true if params[:controller] == "account" &&
                   params[:action] == "login"
    return true if session[:user_id].present?

    logger.warn("BLOCKED #{request.remote_ip}")
    msg = "We have noticed a lot of server-intensive traffic from this IP" \
          "address (#{request.remote_ip}). There may be better ways of" \
          "doing what you are trying to do. Please contact the webmaster" \
          "(#{MO.webmaster_email_address}) so that we can talk about it." \
          "So that we can best help you, please: \n" \
          "- include a copy of this message; \n" \
          "- tell how you generally use Mushroom Observer; \n" \
          "- tell us what you were doing when you received this message."
    render(plain: msg,
           status: :too_many_requests,
           layout: false)
    false
  end

  # Physically eject robots unless they're looking at accepted pages.
  def kick_out_robots
    return true unless browser.bot?
    return true if Robots.authorized?(browser.ua) &&
                   Robots.action_allowed?(
                     controller: params[:controller],
                     action: params[:action]
                   )

    render(plain: "Robots are not allowed on this page.",
           status: :forbidden,
           layout: false)
    false
  end

  # Make sure user is logged in and has posted something -- i.e., not a spammer.
  def require_successful_user
    return true if @user&.successful_contributor?

    flash_warning(:unsuccessful_contributor_warning.t)
    redirect_back_or_default(controller: :observer, action: :index)
    false
  end

  # Enable this to test other layouts...
  layout :choose_layout
  def choose_layout
    change = params[:user_theme].to_s
    change_theme_to(change) if change.present?
    layout = session[:layout].to_s
    layout = "application" if layout.blank?
    layout
  end

  def change_theme_to(change)
    if MO.themes.member?(change)
      if @user
        @user.theme = change
        @user.save
      else
        session[:theme] = change
      end
    else
      session[:layout] = change
    end
  end

  # Catch errors for integration tests, and report stats re completed request.
  def catch_errors_and_log_request_stats
    clear_user_globals
    stats = request_stats
    yield
    IpStats.log_stats(stats)
    logger.warn(request_stats_log_message(stats))
  rescue StandardError => e
    raise(@error = e)
  end

  def request_stats
    {
      time: Time.current,
      controller: params[:controller],
      action: params[:action],
      api_key: params[:api_key],
      robot: browser.bot? ? "robot" : "user",
      ip: request.try(&:remote_ip),
      url: request.try(&:url),
      ua: browser.try(&:ua)
    }
  end

  def request_stats_log_message(stats)
    "TIME: #{Time.current - stats[:time]} #{status} " \
    "#{stats[:controller]} #{stats[:action]} " \
    "#{stats[:robot]} #{stats[:ip]}\t#{stats[:url]}\t#{stats[:ua]}"
  end

  private :request_stats, :request_stats_log_message

  # Update Globalite with any recent changes to translations.
  def refresh_translations
    Language.update_recent_translations
  end

  # Keep track of localization strings so users can edit them (sort of) in situ.
  def track_translations
    @language = Language.find_by(locale: I18n.locale)
    if @user && @language &&
       (!@language.official || reviewer?)
      Language.track_usage(flash[:tags_on_last_page])
    else
      Language.ignore_usage
    end
  end

  # Need to pass list of tags used in this action to next page if redirecting.
  def redirect_to(*args)
    flash[:tags_on_last_page] = Language.save_tags if Language.tracking_usage
    if args.member?(:back)
      redirect_back(fallback_location: "/")
    else
      super
    end
  end

  # Redirect from www.mo.org to mo.org.
  #
  # This would be much easier to check if HTTP_HOST != MO.domain, but if this
  # ever were to break we'd get into an infinite loop too easily that way.
  # I think this is a lot safer.  MO.bad_domains would be something like:
  #
  #   MO.bad_domains = [
  #     'www.mushroomobserver.org',
  #     'mushroomobserver.com',
  #   ]
  #
  # The importance of this is that browsers are storing different cookies
  # for the different domains, even though they are all getting routed here.
  # This is particularly problematic when a fully-specified link in, say,
  # a comment's body is different.  This results in you having to re-login
  # when you click on these embedded links.
  #
  def fix_bad_domains
    if (request.method == "GET") &&
       MO.bad_domains.include?(request.env["HTTP_HOST"])
      redirect_to("#{MO.http_domain}#{request.fullpath}")
    end
  end

  ##############################################################################
  #
  #  :section: User authentication
  #
  ##############################################################################

  # Filter that should run before everything else.  Establishes whether a User
  # is logged in or not.
  #
  # Stores the currently logged-in User in the "globals" <tt>@user</tt> and
  # <tt>User.current</tt>, as well as the session.  (The first is visible to
  # all controller instances and views; the second is visible to the entire
  # website application.)
  #
  # It first checks if the User is already logged in, i.e. is stored in the
  # session.  If not, it checks for an autologin cookie on the User's browser,
  # and logs them in automatically if so.
  #
  # In both cases, it makes sure the User actually exists and is verified.  If
  # not, the "user" is immediately logged out and the autologin cookie is
  # destroyed.
  #
  def autologin
    # render(plain: "Sorry, we've taken MO down to test something urgent."\
    #               "We'll be back in a few minutes. -Jason", layout: false)
    # return false

    # if browser.bot?
    #   render(status: 503, text: "robots are temporarily blocked from MO",
    #          layout: false)
    #   return false
    # end

    try_user_autologin(session_user)
    make_logged_in_user_available_to_everyone
    track_last_page_request_by_user
    block_suspended_users
  end

  private ##########

  def clear_user_globals
    @user = nil
    User.current = nil
  end

  def try_user_autologin(user)
    # Do nothing if already logged in: if user asked us to remember him the
    # cookie will already be there, if not then we want to leave it out.
    if already_logged_in?(user)
      refresh_logged_in_user_instance(user)

    # Log in if cookie is valid, and autologin is enabled.
    elsif (user = valid_user_from_cookie) && user.verified
      login_valid_user(user)
    else
      delete_invalid_cookies
    end
  end

  def already_logged_in?(user)
    user&.verified
  end

  def valid_user_from_cookie
    return unless (cookie = cookies["mo_user"]) &&
                  (split = cookie.split(" ")) &&
                  (user = User.where(id: split[0]).first) &&
                  (split[1] == user.auth_code)

    user
  end

  def refresh_logged_in_user_instance(user)
    @user = user
    @user.reload
  end

  def login_valid_user(user)
    @user = session_user_set(user)
    @user.last_login = Time.current
    @user.save

    # Reset cookie to push expiry forward.  This way it will continue to
    # remember the user until they are inactive for over a month.  (Else
    # they'd have to login every month, no matter how often they login.)
    autologin_cookie_set(user)
  end

  def delete_invalid_cookies
    clear_autologin_cookie
    session_user_set(nil)
  end

  def make_logged_in_user_available_to_everyone
    User.current = @user
    logger.warn("user=#{@user ? @user.id : "0"}" \
                " robot=#{browser.bot? ? "Y" : "N"}" \
                " ip=#{request.remote_ip}")
  end

  # Track when user requested a page, but update at most once an hour.
  def track_last_page_request_by_user
    if @user && (
        !@user.last_activity ||
        @user.last_activity.to_s("%Y%m%d%H") != Time.current.to_s("%Y%m%d%H"))
      @user.last_activity = Time.current
      @user.save
    end
  end

  def block_suspended_users
    return true unless user_suspended? # Tell Rails to continue processing.

    block(user)
    false # Tell Rails to stop processing.
  end

  def user_suspended?
    @user && @user.id == 2750 # Kick Byrain off the site.
  end

  def block_user
    render(plain: "Your account has been temporarily suspended.",
           layout: false)
  end

  public ##########

  # Filter that redirect anonymous users to login
  # unless they're looking at allowed pages
  def redirect_anonymous_users
    return true if browser.bot? # recognized bots are handled elsewhere
    return true if @user

    store_location
    redirect_to(account_login_path)
  end

  # ----------------------------
  #  "Public" methods.
  # ----------------------------

  # Is the current User the correct User (or is admin mode on)?  Returns true
  # or false.  (*NOTE*: this is available to views.)
  #
  #   <% if check_permission(@object)
  #     link_to('Destroy', :action => :destroy_object)
  #   end %>
  #
  def check_permission(obj)
    in_admin_mode? || correct_user_for_object?(obj)
  end
  helper_method :check_permission

  def correct_user_for_object?(obj)
    owned_by_user?(obj) || editable_by_user?(obj) || obj_is_user?(obj)
  end

  def owned_by_user?(obj)
    obj.respond_to?(:user_id) && User.current_id == obj.user_id
  end

  def editable_by_user?(obj)
    obj.try(&:can_edit?)
  end

  def obj_is_user?(obj)
    (obj.is_a?(String) || obj.is_a?(Integer)) && obj.to_i == User.current_id
  end

  private :correct_user_for_object?, :owned_by_user?, :editable_by_user?,
          :obj_is_user?

  # Is the current User the correct User (or is admin mode on)?  Returns true
  # or false.  Flashes a "denied" error message if false.
  #
  #   def destroy_thing
  #     @thing = Thing.find(params[:id].to_s)
  #     if check_permission!(@thing)
  #       @thing.destroy
  #       flash_notice "Success!"
  #     end
  #     redirect_to(:action => :show_thing)
  #   end
  #
  def check_permission!(obj)
    unless (result = check_permission(obj))
      flash_error(:permission_denied.t)
    end
    result
  end
  alias check_user_id check_permission!

  # Is the current User a reviewer?  Returns true or false.  (*NOTE*: this is
  # available to views.)
  def reviewer?
    result = false
    result = @user.in_group?("reviewers") if @user
    result
  end
  helper_method :reviewer?

  # Is the current User in admin mode?  Returns true or false.  (*NOTE*: this
  # is available to views.)
  def in_admin_mode?
    session[:admin]
  end
  helper_method :in_admin_mode?

  # Are there are any QueuedEmail's of the given flavor for the given User?
  # Returns true or false.
  #
  # This only applies to emails that are associated with Notification's for
  # which there is a note_template.  (Only one type now: Notification's with
  # flavor :name, which corresponds to QueuedEmail's with flavor :naming.)
  def unshown_notifications?(user, flavor = :naming)
    QueuedEmail.where(flavor: flavor, to_user_id: user.id).each do |q|
      ints = q.get_integers(%w[shown notification], true)
      next if ints["shown"]

      notification = Notification.safe_find(ints["notification"].to_i)
      next unless notification&.note_template

      return true
    end

    false
  end

  # ----------------------------
  #  "Private" methods.
  # ----------------------------

  # Create/update the auto-login cookie.
  def autologin_cookie_set(user)
    cookies["mo_user"] = {
      value: "#{user.id} #{user.auth_code}",
      expires: 1.month.from_now
    }
  end

  # Destroy the auto-login cookie.
  def clear_autologin_cookie
    cookies.delete("mo_user")
  end

  # Store User in session (id only).
  def session_user_set(user)
    session[:user_id] = user ? user.id : nil
    user
  end

  # Retrieve the User from session.  Returns User object or nil.  (Does not
  # check verified status or anything.)
  def session_user
    User.safe_find(session[:user_id])
  end

  ##############################################################################
  #
  #  :section: Internationalization
  #
  ##############################################################################

  # Before filter: Decide which locale to use for this request.  Sets the
  # Globalite default.  Tries to get the locale from:
  #
  # 1. parameters (user clicked on language in bottom left)
  # 2. user prefs (user edited their preferences)
  # 3. session (whatever we used last time)
  # 4. navigator (provides default)
  # 5. server (MO.default_locale)
  #
  def set_locale
    lang = Language.find_by(locale: specified_locale) || Language.official

    # Only change the Locale code if it needs changing.  There is about a 0.14
    # second performance hit every time we change it... even if we're only
    # changing it to what it already is!!
    change_locale_if_needed(lang.locale)

    # Update user preference.
    @user.update(locale: lang.locale) if @user && @user.locale != lang.locale

    logger.debug("[I18n] Locale set to #{I18n.locale}")

    # Tell Rails to continue to process request.
    true
  end

  def specified_locale
    params_locale || prefs_locale || session_locale || browser_locale
  end

  def params_locale
    return unless params[:user_locale]

    logger.debug("[I18n] loading locale: #{params[:user_locale]} from params")
    params[:user_locale]
  end

  def prefs_locale
    return unless @user&.locale.present? && params[:controller] != "ajax"

    logger.debug("[I18n] loading locale: #{@user.locale} from @user")
    @user.locale
  end

  def session_locale
    return unless session[:locale]

    logger.debug("[I18n] loading locale: #{session[:locale]} from session")
    session[:locale]
  end

  def browser_locale
    return unless (locale = valid_locale_from_request_header)

    logger.debug("[I18n] loading locale: #{locale} from request header")
    locale
  end

  def change_locale_if_needed(new_locale)
    return if I18n.locale.to_s == new_locale

    I18n.locale = new_locale
    session[:locale] = new_locale
  end

  # Before filter: Set timezone based on cookie set in application layout.
  def set_timezone
    tz = cookies[:tz]
    if tz.present?
      begin
        Time.zone = tz
      rescue StandardError
        logger.warn("TimezoneError: #{tz.inspect}")
      end
    end
    @js = js_enabled?(tz)
  end

  # Until we get rid of reliance on @js, this is a surrogate for
  # testing if the client's JS is enabled and sufficiently fully-featured.
  def js_enabled?(time_zone)
    time_zone.present? ? true : Rails.env.test?
  end

  # Return Array of the browser's requested locales (HTTP_ACCEPT_LANGUAGE).
  # Example syntax:
  #
  #   en-au,en-gb;q=0.8,en;q=0.5,ja;q=0.3
  #
  def sorted_locales_from_request_header
    result = []
    if (accepted_locales = request.env["HTTP_ACCEPT_LANGUAGE"])

      locale_weights = map_locales_to_weights(accepted_locales)
      # Now sort by decreasing weights.
      result = locale_weights.sort { |a, b| b[1] <=> a[1] }.map { |a| a[0] }
    end

    logger.debug("[globalite] client accepted locales: #{result.join(", ")}")
    result
  end

  # Extract locales and weights, creating map from locale to weight.
  def map_locales_to_weights(locales)
    locales.split(",").each_with_object({}) do |term, loc_wts|
      next unless "#{term};q=1" =~ /^(.+?);q=([^;]+)/

      loc_wts[Regexp.last_match(1)] = (begin
                                         Regexp.last_match(2).to_f
                                       rescue StandardError
                                         -1.0
                                       end)
    end
  end

  # Returns our locale that best suits the HTTP_ACCEPT_LANGUAGE request header.
  # Returns a String, or <tt>nil</tt> if no valid match found.
  def valid_locale_from_request_header
    # Get list of languages browser requested, sorted in the order it prefers
    # them.
    requested_locales = sorted_locales_from_request_header.map do |locale|
      if locale =~ /^(\w\w)-(\w+)$/
        Regexp.last_match(1).downcase
      else
        locale.downcase
      end
    end

    # Lookup the closest match based on the given request priorities.
    lookup_valid_locale(requested_locales)
  end

  # Lookup the closest match based on the given request priorities.
  def lookup_valid_locale(requested_locales)
    requested_locales.each do |locale|
      logger.debug("[globalite] trying to match locale: #{locale}")
      language = locale.split("-").first
      next unless I18n.available_locales.include?(language.to_sym)

      logger.debug("[globalite] language match: #{language}")
      return language
    end
    "en"
  end

  private :js_enabled?, :map_locales_to_weights, :lookup_valid_locale

  ##############################################################################
  #
  #  :section: Error handling
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
  helper_method :flash_notices?

  # Get a copy of the errors.  Return as String.
  def flash_get_notices
    # Maybe there is a cleaner way to do this.  session[:notice] should
    # already be html_safe, but the substring marks it as unsafe. Maybe there
    # is a way to test if it's html_safe before, and if so, then it should be
    # okay to remove the first character without making it html_unsafe??
    # rubocop:disable Rails/OutputSafety
    session[:notice].to_s[1..].html_safe
    # rubocop:enable Rails/OutputSafety
  end
  helper_method :flash_get_notices

  # Get current notice level. (0 = notice, 1 = warning, 2 = error)
  def flash_notice_level
    level = session[:notice].to_s[0, 1]
    level == "" ? nil : level.to_i
  end
  helper_method :flash_notice_level

  # Clear error/warning messages. *NOTE*: This is done automatically by the
  # application layout (app/views/layouts/application.rhtml) every time it
  # renders the latest error messages.
  def flash_clear
    @last_notice = session[:notice] if Rails.env.test?
    session[:notice] = nil
  end
  helper_method :flash_clear

  # Report an informational message that will be displayed (in green) at the
  # top of the next page the User sees.
  def flash_notice(*strs)
    session[:notice] ||= "0"
    session[:notice] += strs.map { |str| "<p>#{str}</p>" }.join("")
  end
  helper_method :flash_notice

  # Report a warning message that will be displayed (in yellow) at the top of
  # the next page the User sees.
  def flash_warning(*strs)
    flash_notice(*strs)
    session[:notice][0, 1] = "1" if session[:notice][0, 1] == "0"
    false
  end
  helper_method :flash_warning

  # Report an error message that will be displayed (in red) at the top of the
  # next page the User sees.
  def flash_error(*strs)
    flash_notice(*strs)
    session[:notice][0, 1] = "2" if session[:notice][0, 1] != "2"
    false
  end
  helper_method :flash_error

  def flash_object_errors(obj)
    return unless obj&.errors && !obj.errors.empty?

    obj.formatted_errors.each { |error| flash_error(error) }
  end

  def save_with_log(obj)
    type_sym = obj.class.to_s.underscore.to_sym
    if obj.save
      flash_notice(:runtime_created_at.t(type: type_sym))
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

  ##############################################################################
  #
  #  :section: Name validation
  #
  ##############################################################################

  # Goes through list of names entered by user and creates (and saves) any that
  # are not in the database (but only if user has approved them).
  #
  # Used by: bulk_name_editor, change_synonyms, create/edit_species_list
  #
  # Inputs:
  #
  #   name_list         string, delimted by newlines (see below for syntax)
  #   approved_names    array of real_search_names (or string delimited by "/")
  #   deprecate?        are any created names to be deprecated?
  #
  # Syntax: (NameParse class does the actual parsing)
  #
  #   Xxx yyy
  #   Xxx yyy var. zzz
  #   Xxx yyy Author
  #   Xxx yyy sensu Blah
  #   Valid name Author = Deprecated name Author
  #   blah blah [comment]
  #   (this is described better in views/observer/bulk_name_edit.rhtml)
  #
  def construct_approved_names(name_list, approved_names, deprecate = false)
    return unless approved_names

    if approved_names.is_a?(String)
      approved_names = approved_names.split(/\r?\n/)
    end
    name_list.split("\n").each do |ns|
      next if ns.blank?

      name_parse = NameParse.new(ns)
      construct_approved_name(name_parse, approved_names, deprecate)
    end
  end

  # Processes a single line from the list above.
  # Used only by construct_approved_names().
  def construct_approved_name(name_parse, approved_names, deprecate)
    # Don't do anything if the given names are not approved
    if approved_names.member?(name_parse.name)
      # Build just the given names (not synonyms)
      construct_given_name(name_parse, deprecate)
    end

    # Do the same thing for synonym (found the Approved = Synonym syntax).
    return unless name_parse.has_synonym &&
                  approved_names.member?(name_parse.synonym)

    construct_synonyms(name_parse)
  end

  def construct_given_name(name_parse, deprecate)
    # Create name object for this name (and any parents, such as genus).
    names = Name.find_or_create_name_and_parents(name_parse.search_name)

    # if above parse was successful
    if (name = names.last)
      name.rank = name_parse.rank if name_parse.rank

      process_given_name_comments_for_bulk_editor(name_parse, name)

      # Only bulk name editor allows the synonym syntax now.  Tell it to
      # approve the left-hand name.
      deprecate2 = (name_parse.has_synonym ? false : deprecate)

      save_approved_given_names(names, deprecate2)

    # Parse must have failed.
    else
      flash_error(:runtime_no_create_name.t(type: :name,
                                            value: name_parse.name))
    end
  end

  def process_given_name_comments_for_bulk_editor(name_parse, name)
    return unless (comment = name_parse.comment)

    # Okay to add citation to any record without an existing citation.
    if comment =~ /^citation: *(.*)/
      citation = Regexp.last_match(1)
      name.citation = citation if name.citation.blank?
    # Only save comment if name didn't exist
    elsif name.new_record?
      name.notes = comment
    else
      flash_warning("Didn't save comment for #{name.real_search_name}, " \
                    "name already exists. (comment = \"#{comment}\")")
    end
  end

  def save_approved_given_names(names, deprecate2)
    Name.save_names(names, deprecate2)
    names.each { |n| flash_object_errors(n) }
  end

  def construct_synonyms(name_parse)
    synonyms = create_synonym(name_parse)

    # Parse was successful
    if (synonym = synonyms.last)
      synonym.rank = name_parse.synonym_rank if name_parse.synonym_rank
      process_synonym_comments_for_bulk_editor(name_parse, synonym)
      save_synonyms(synonym, synonyms)

    # Parse must have failed.
    else
      flash_error(:runtime_no_create_name.t(type: :name,
                                            value: name_parse.synonym))
    end
  end

  def create_synonym(name_parse)
    Name.find_or_create_name_and_parents(name_parse.synonym_search_name)
  end

  def process_synonym_comments_for_bulk_editor(name_parse, synonym)
    return unless (comment = name_parse.synonym_comment)

    # Only save comment if name didn't exist
    if synonym.new_record?
      synonym.notes = comment
    else
      flash_warning("Didn't save comment for #{synonym.real_search_name}, " \
                    "name already exists. (comment = \"#{comment}\")")
    end
  end

  # Deprecate and save.
  def save_synonyms(synonym, synonyms)
    synonym.change_deprecated(true)
    synonym.save_with_log(:log_deprecated_by, touch: true)
    Name.save_names(synonyms[0..-2], nil) # Don't change higher taxa
  end

  ##############################################################################
  #
  #  :section: Searching
  #
  #  The general idea is that the user executes a search or requests an index,
  #  then clicks on a result.  This takes the user to a show_object page.  This
  #  page "knows" about the search or index via a special universal URL
  #  parameter (via +query_params+).  When the user then clicks on "prev" or
  #  "next", it can then step through the query results.
  #
  #  While browsing like this, the user may want to divert temporarily to add a
  #  comment or propose a name or something.  These actions are responsible for
  #  keeping track of these search parameters, and eventually passing them back
  #  to the show_object page.  Usually they just pass the query parameter
  #  through via +pass_query_params+.
  #
  #  See Query and AbstractQuery for more detail.
  #
  ##############################################################################

  # This clears the search/index saved in the session.
  def clear_query_in_session
    session[:checklist_source] = nil
  end

  # This stores the latest search/index used for use by create_species_list.
  # (Stores the Query id in <tt>session[:checklist_source]</tt>.)
  def store_query_in_session(query)
    query.save unless query.id
    session[:checklist_source] = query.id
  end

  # Get Query last stored on the "clipboard" (session).
  def query_from_session
    return unless (id = session[:checklist_source])

    Query.safe_find(id)
  end

  # Get instance of Query which is being passed to subsequent pages.
  def passed_query
    Query.safe_find(query_params[:q].to_s.dealphabetize)
  end
  helper_method :passed_query

  # Return query parameter(s) necessary to pass query information along to
  # the next request. *NOTE*: This method is available to views.
  def query_params(query = nil)
    if browser.bot?
      {}
    elsif query
      query.save unless query.id
      { q: query.id.alphabetize }
    else
      @query_params || {}
    end
  end
  helper_method :query_params

  def add_query_param(params, query = nil)
    return params if browser.bot?

    query_param = get_query_param(query)
    if params.is_a?(String) # i.e., if params is a path
      append_query_param_to_path(params, query_param)
    else
      params[:q] = query_param
      params
    end
  end
  helper_method :add_query_param

  def append_query_param_to_path(path, query_param)
    return path unless query_param

    if path.match?(/\?/) # Does path already have a query string?
      "#{path}&q=#{query_param}" # add query_param to existing query string
    else
      "#{path}?q=#{query_param}" # create a query string comprising query_param
    end
  end

  # Allows us to add query to a path helper:
  #   object_path(@object, q: get_query_param)
  def get_query_param(query = nil)
    return nil if browser.bot?

    if query
      query.save unless query.id
      query.id.alphabetize
    elsif @query_params
      @query_params[:q]
    end
  end
  helper_method :get_query_param

  def redirect_with_query(args, query = nil)
    redirect_to(add_query_param(args, query))
  end

  def url_with_query(args, query = nil)
    url_for(add_query_param(args, query))
  end

  def coerced_query_link(query, model)
    return nil unless query&.coercable?(model.name.to_sym)

    [
      :show_objects.t(type: model.type_tag),
      add_query_param({ controller: model.show_controller,
                        action: model.index_action }, query)
    ]
  end
  helper_method :coerced_query_link

  # Pass the in-coming query parameter(s) through to the next request.
  def pass_query_params
    @query_params = {}
    @query_params[:q] = params[:q] if params[:q].present?
    @query_params
  end

  # Change the query that +query_params+ passes along to the next request.
  # *NOTE*: This method is available to views.
  def query_params_set(query = nil)
    @query_params = {}
    if browser.bot?
      # do nothing
    elsif query
      query.save unless query.id
      @query_params[:q] = query.id.alphabetize
    end
    @query_params
  end
  helper_method :query_params_set

  # Lookup an appropriate Query or create a default one if necessary.  If you
  # pass in arguments, it modifies the query as necessary to ensure they are
  # correct.  (Useful for specifying sort conditions, for example.)
  def find_or_create_query(model_symbol, args = {})
    map_past_bys(args)
    model = model_symbol.to_s
    result = existing_updated_or_default_query(model, args)
    save_query_unless_bot(result)
    result
  end

  # Lookup the given kind of Query, returning nil if it no longer exists.
  def find_query(model = nil, update = !browser.bot?)
    model = model.to_s if model
    q = dealphabetize_q_param

    return nil unless (query = query_exists(q))

    result = find_new_query_for_model(model, query)
    save_updated_query(result) if update && result
    result
  end

  # Handle advanced_search actions with an invalid q param,
  # so that they get just one flash msg if the query has expired.
  # This method avoids a call to find_safe, which would add
  # "undefined method `id' for nil:NilClass" if there's no QueryRecord for q
  def handle_advanced_search_invalid_q_param?
    return unless invalid_q_param?

    flash_error(:advanced_search_bad_q_error.t)
    redirect_to(observer_advanced_search_form_path)
  end

  private ##########

  def map_past_bys(args)
    args[:by] = (BY_MAP[args[:by].to_s] || args[:by]) if args.member?(:by)
  end

  BY_MAP = {
    "modified" => :updated_at,
    "created" => :created_at
  }.freeze

  # Lookup the query and,
  # If it exists, return it or - if its arguments need modification -
  # a new query based on the existing one but with modified arguments.
  # If it does not exist, resturn default query.
  def existing_updated_or_default_query(model, args)
    result = find_query(model, false)
    if result
      # If existing query needs updates, we need to create a new query,
      # otherwise the modifications won't persist.
      # Use the existing query as the template, though.
      if query_needs_update?(args, result)
        result = create_query(model, result.flavor, result.params.merge(args))
      end
    # If no query found, just create a default one.
    else
      result = create_query(model, :all, args)
    end
    result
  end

  def dealphabetize_q_param
    params[:q].dealphabetize
  rescue StandardError
    nil
  end

  def query_exists(params)
    return unless params && (query = Query.safe_find(params))

    query
  end

  # Turn old query into a new query for given model,
  # (re-using the old query if it's still correct),
  # and returning nil if no new query can be found.
  def find_new_query_for_model(model, old_query)
    old_query_correct_for_model(model, old_query) ||
      old_query_coercable_for_model(model, old_query) ||
      outer_query_correct_or_coerceable_for_model(model, old_query) ||
      nil
  end

  def old_query_correct_for_model(model, old_query)
    old_query if !old_query || (old_query.model.to_s == model)
  end

  def old_query_coercable_for_model(model, old_query)
    old_query.coerce(model)
  end

  def outer_query_correct_or_coerceable_for_model(model, old_query)
    return unless (outer_query = old_query.outer)

    if outer_query.model.to_s == model
      outer_query
    elsif (coerced_outer_query = outer_query.coerce(model))
      coerced_outer_query
    end
  end

  def save_updated_query(result)
    result.increment_access_count
    result.save
  end

  def query_needs_update?(new_args, query)
    new_args.any? { |_arg, val| query.params[:arg] != val }
  end

  def invalid_q_param?
    params && params[:q] &&
      !QueryRecord.where(id: params[:q].dealphabetize).exists?
  end

  public ##########

  # Create a new Query of the given flavor for the given model.  Pass it
  # in all the args you would to Query#new. *NOTE*: Not all flavors are
  # capable of supplying defaults for every argument.
  def create_query(model_symbol, flavor = :all, args = {})
    Query.lookup(model_symbol, flavor, args)
  end

  private ##########

  def save_query_unless_bot(result)
    return unless result && !browser.bot?

    result.increment_access_count
    result.save
  end

  # Create a new query by adding a bounding box to the given one.
  def restrict_query_to_box(query)
    return query if params[:north].blank?

    model = query.model.to_s.to_sym
    flavor = query.flavor
    tweaked_params = query.params.merge(tweaked_bounding_box_params)
    Query.lookup(model, flavor, tweaked_params)
  end

  def tweaked_bounding_box_params
    {
      north: tweak_up(params[:north], 0.001, 90),
      south: tweak_down(params[:south], 0.001, -90),
      east: tweak_up(params[:east], 0.001, 180),
      west: tweak_down(params[:west], 0.001, -180)
    }
  end

  def tweak_up(value, amount, max)
    [max, value.to_f + amount].min
  end

  def tweak_down(value, amount, min)
    [min, value.to_f - amount].max
  end

  public ##########

  # This is the common code for all the 'prev/next_object' actions.  Pass in
  # the current object and direction (:prev or :next), and it looks up the
  # query, grabs the next object, and redirects to the appropriate
  # 'show_object' action.
  #
  #   def next_image
  #     redirect_to_next_object(:next, Image, params[:id].to_s)
  #   end
  #
  def redirect_to_next_object(method, model, id)
    return unless (object = find_or_goto_index(model, id))

    next_params = find_query_and_next_object(object, method, id)
    object = next_params[:object]
    id =     next_params[:id]
    query =  next_params[:query]

    # Redirect to the show_object page appropriate for the new object.
    redirect_to(add_query_param({ controller: object.show_controller,
                                  action: object.show_action,
                                  id: id }, query))
  end

  def find_query_and_next_object(object, method, id)
    # prev/next in RssLog query
    query_and_next_object_rss_log_increment(object, method) ||
      # other cases (normal case or no next object)
      query_and_next_object_normal(object, method, id)
  end

  private ##########

  def query_and_next_object_rss_log_increment(object, method)
    # Special exception for prev/next in RssLog query: If go to "next" in
    # show_observation, for example, inside an RssLog query, go to the next
    # object, even if it's not an observation. If...
    #             ... q param is an RssLog query
    return unless (query = current_query_is_rss_log) &&
                  # ... and current rss_log exists, it's in query results,
                  #     and can set current index of query results from rss_log
                  (rss_log = results_index_settable_from_rss_log(query,
                                                                 object)) &&
                  # ... and next/prev doesn't return nil (at end)
                  (new_query = query.send(method)) &&
                  # ... and can get new rss_log object
                  (rss_log = new_query.current)

    { object: rss_log.target || rss_log, id: object.id, query: new_query }
  end

  # q parameter exists, a query exists for that param, and it's an rss query
  def current_query_is_rss_log
    return unless params[:q] && (query = query_exists(dealphabetize_q_param))

    query if query.model == RssLog
  end

  # Can we can set current index in query results based on rss_log query?
  def results_index_settable_from_rss_log(query, object)
    return unless (rss_log = rss_log_exists) &&
                  in_query_results(rss_log, query) &&
                  # ... and can set current index in query results
                  (query.current = object.rss_log)

    rss_log
  end

  def rss_log_exists
    object.rss_log
  rescue StandardError
    nil
  end

  def in_query_results(rss_log, query)
    query.index(rss_log)
  end

  # Normal case: attempt to coerce the current query into an appropriate
  # type, and go from there.  This handles all the exceptional cases:
  # 1) query not coercable (creates a new default one)
  # 2) current object missing from results of the current query
  # 3) no more objects being left in the query in the given direction
  def query_and_next_object_normal(object, method, id)
    query = find_or_create_query(object.class)
    query.current = object

    if !query.index(object)
      current_object_missing_from_current_query_results(object, id, query)
    elsif (new_query = query.send(method))
      { object: object, id: new_query.current_id, query: new_query }
    else
      no_more_objects_in_given_direction(object, id, query)
    end
  end

  def current_object_missing_from_current_query_results(object, id, query)
    flash_error(:runtime_object_not_in_index.t(id: object.id,
                                               type: object.type_tag))
    { object: object, id: id, query: query }
  end

  def no_more_objects_in_given_direction(object, id, query)
    flash_error(:runtime_no_more_search_objects.t(type: object.type_tag))
    { object: object, id: id, query: query }
  end

  public ##########

  ##############################################################################
  #
  #  :section: Indexes
  #
  ##############################################################################

  # Render an index or set of search results as a list or matrix. Arguments:
  # query::     Query instance describing search/index.
  # args::      Hash of options.
  #
  # Options include these:
  # id::            Warp to page that includes object with this id.
  # action::        Template used to render results.
  # matrix::        Displaying results as matrix?
  # letters::       Paginating by letter?
  # letter_arg::    Param used to store letter for pagination.
  # number_arg::    Param used to store page number for pagination.
  # num_per_page::  Number of results per page.
  # sorting_links:: Array of pairs: ["by" String, label String]
  # always_index::  Always show index, even if only one result.
  # link_all_sorts:: Don't gray-out the current sort criteria.
  #
  # Side-effects: (sets/uses the following instance variables for the view)
  # @title::        Provides default title.
  # @links:         Extra links to add to right hand tab set.
  # @sorts::
  # @layout::
  # @pages::        Paginator instance.
  # @objects::      Array of objects to be shown.
  # @extra_data::   Results of block yielded on every object if block given.
  #
  # Other side-effects:
  # store_location::          Sets this as the +redirect_back_or_default+
  #                           location.
  # clear_query_in_session::  Clears the query from the "clipboard"
  #                           (if you didn't just store this query on it!).
  # query_params_set::        Tells +query_params+ to pass this query on
  #                           in links on this page.
  #
  def show_index_of_objects(query, args = {})
    letter_arg   = args[:letter_arg] || :letter
    number_arg   = args[:number_arg] || :page
    num_per_page = args[:num_per_page] || 50
    include      = args[:include] || nil
    type         = query.model.type_tag

    apply_content_filters(query)

    # Tell site to come back here on +redirect_back_or_default+.
    store_location

    # Clear out old query from session.  (Don't do it if caller just finished
    # storing *this* query in there, though!!)
    clear_query_in_session if session[:checklist_source] != query.id

    # Pass this query on when clicking on results.
    query_params_set(query)

    # Supply default error message to display if no results found.
    if (query.params.keys - query.required_parameters - [:by]).empty?
      @error ||=
        case query.flavor
        when :all
          :runtime_no_objects.t(type: type)
        when :at_location
          loc = query.find_cached_parameter_instance(Location, :location)
          :runtime_index_no_at_location.t(type: type,
                                          location: loc.display_name)
        when :at_where
          :runtime_index_no_at_location.t(type: type,
                                          location: query.params[:location])
        when :by_author
          user = query.find_cached_parameter_instance(User, :user)
          :runtime_user_hasnt_authored.t(type: type, user: user.legal_name)
        when :by_editor
          user = query.find_cached_parameter_instance(User, :user)
          :runtime_user_hasnt_edited.t(type: type, user: user.legal_name)
        when :by_rss_log
          :runtime_index_no_by_rss_log.t(type: type)
        when :by_user
          user = query.find_cached_parameter_instance(User, :user)
          :runtime_user_hasnt_created.t(type: type, user: user.legal_name)
        when :for_target
          :runtime_index_no_for_object.t(type: type)
        when :for_user
          user = query.find_cached_parameter_instance(User, :user)
          :runtime_index_no_for_user.t(type: type, user: user.legal_name)
        when :in_species_list
          spl = query.find_cached_parameter_instance(SpeciesList, :species_list)
          :runtime_index_no_in_species_list.t(type: type, name: spl.title)
        when :inside_observation
          id = query.params[:observation]
          :runtime_index_no_inside_observation.t(type: type, id: id)
        when :pattern_search
          :runtime_no_matches_pattern.t(type: type,
                                        value: query.params[:pattern].to_s)
        when :regexp_search
          :runtime_no_matches_regexp.t(type: type,
                                       value: query.params[:regexp].to_s)
        when :with_descriptions
          :runtime_index_no_with.t(type: type, attachment: :description)
        when :with_observations
          :runtime_index_no_with.t(type: type, attachment: :observation)
        end
    end
    @error ||= :runtime_no_matches.t(type: type)

    # Get user prefs for displaying results as a matrix.
    if args[:matrix]
      @layout = calc_layout_params
      num_per_page = @layout["count"]
    end

    # Inform the query that we'll need the first letters as well as ids.
    query.need_letters = args[:letters] if args[:letters]

    # Get number of results first so we know how to paginate.
    @timer_start = Time.current
    @num_results = query.num_results
    @timer_end = Time.current

    # Supply a default title.
    # If no results, then title is empty but not nil.
    # Result: No title is displayed
    # (overriding any title specified in the view)
    # and the html <title> metadata == a translated tag or the action name
    # see ApplicationHelper#title_tag_contents
    @num_results.zero? ? @title = "" : @title ||= query.title

    # Add magic links for sorting if enough results to sort
    @sorts = (@num_results > 1 ? sorting_links(query, args) : nil)

    # If only one result (before pagination), redirect to 'show' action.
    if (@num_results == 1) && !args[:always_index]
      redirect_with_query(controller: query.model.show_controller,
                          action: query.model.show_action,
                          id: query.result_ids.first)

    # Otherwise paginate results.  (Everything we need should be cached now.)
    else
      @pages = if args[:letters]
                 paginate_letters(letter_arg, number_arg, num_per_page)
               else
                 paginate_numbers(number_arg, num_per_page)
               end

      # Skip to correct place if coming back in to index from show_object.
      if args[:id].present? &&
         params[@pages.letter_arg].blank? &&
         params[@pages.number_arg].blank?
        @pages.show_index(query.index(args[:id]))
      end

      # Instantiate correct subset.
      logger.warn("QUERY starting: #{query.query.inspect}")
      @timer_start = Time.current
      @objects = query.paginate(@pages, include: include)
      @timer_end = Time.current
      logger.warn("QUERY finished: model=#{query.model}, " \
                  "flavor=#{query.flavor}, params=#{query.params.inspect}, " \
                  "time=#{(@timer_end - @timer_start).to_f}")

      # Give the caller the opportunity to add extra columns.
      if block_given?
        @extra_data = @objects.each_with_object({}) do |object, data|
          row = yield(object)
          row = [row] unless row.is_a?(Array)
          data[object.id] = row
        end
      end

      if args[:template]
        render(template: args[:template]) # Render the list if given template.
      elsif args[:action]
        render(action: args[:action])
      end
    end
  end

  private ##########

  def apply_content_filters(query)
    filters = users_content_filters || {}
    @any_content_filters_applied = false
    ContentFilter.all.each do |fltr|
      key = fltr.sym
      # applicable to this query?
      next unless query.takes_parameter?(key)
      # overridden by search, etc.?
      next if query.params.key?(key)
      # in user's content filter?
      next unless fltr.on?(filters[key])

      # This is a "private" method used by Query#validate_params.
      # It would be better to add these parameters before the query is
      # instantiated. Or alternatively, make query validation lazy so
      # we can continue to add parameters up until we first ask it to
      # execute the query.
      query.params[key] = query.validate_value(fltr.type, fltr.sym,
                                               filters[key].to_s)
      @any_content_filters_applied = true
    end
  end

  def users_content_filters
    @user ? @user.content_filter : MO.default_content_filter
  end

  def sorting_links(query, args)
    return nil unless (sorts = args[:sorting_links]) &&
                      (sorts.length > 1) &&
                      !browser.bot?

    add_sorting_links(query, sorts, args[:link_all_sorts])
  end

  public ##########

  # Create sorting links for index pages, "graying-out" the current order.
  def add_sorting_links(query, links, link_all = false)
    results = []
    this_by = (query.params[:by] || query.default_order).sub(/^reverse_/, "")

    links.each do |by, label|
      results << link_or_grayed_text(link_all, this_by, label, query, by)
    end

    # Add a "reverse" button.
    results << sort_link(:sort_by_reverse.t, query, reverse_by(query, this_by))
  end

  private ##########

  def link_or_grayed_text(link_all, this_by, label, query, by)
    if !link_all && (by.to_s == this_by)
      label.t
    else
      sort_link(label.t, query, by)
    end
  end

  def sort_link(text, query, by)
    [text, { controller: query.model.show_controller,
             action: query.model.index_action,
             by: by }.merge(query_params)]
  end

  def reverse_by(query, this_by)
    if query.params[:by].to_s.start_with?("reverse_")
      this_by
    else
      "reverse_#{this_by}"
    end
  end

  public ##########

  # Lookup a given object, displaying a warm-fuzzy error and redirecting to the
  # appropriate index if it no longer exists.
  def find_or_goto_index(model, id)
    model.safe_find(id) || flash_error_and_goto_index(model, id)
  end

  def flash_error_and_goto_index(model, id)
    flash_error(:runtime_object_not_found.t(id: id || "0",
                                            type: model.type_tag))
    redirect_with_query(controller: model.show_controller,
                        action: model.index_action)
  end

  private ##########

  # Redirects to an appropriate fallback index in case of unrecoverable error.
  # Most such errors are dealt with on a case-by-case basis in the controllers,
  # however a few generic actions don't necessarily know where to send users
  # when things go south.  This makes a good stab at guessing, at least.
  def goto_index(redirect = nil)
    pass_query_params
    from = redirect_from(redirect)
    to_model = REDIRECT_FALLBACK_MODELS[from.to_sym]
    raise("Unsure where to go from #{from}.") unless to_model

    redirect_with_query(controller: to_model.show_controller,
                        action: to_model.index_action)
  end

  # Return string which is the class or controller to fall back from.
  def redirect_from(redirect)
    redirect = redirect.name.underscore if redirect.is_a?(Class)
    (redirect || controller.name).to_s
  end

  REDIRECT_FALLBACK_MODELS = {
    account: RssLog,
    comment: Comment,
    image: Image,
    location: Location,
    name: Name,
    naming: Observation,
    observation: Observation,
    observer: RssLog,
    project: Project,
    rss_log: RssLog,
    species_list: SpeciesList,
    user: RssLog,
    vote: Observation
  }.freeze

  public ##########

  # Initialize Paginator object.  This now does very little thanks to the new
  # Query model.
  # arg::    Name of parameter to use.  (default is 'letter')
  #
  #   # In controller:
  #   query  = create_query(:Name, :by_user, :user => params[:id].to_s)
  #   query.need_letters('names.display_name')
  #   @pages = paginate_letters(:letter, :page, 50)
  #   @names = query.paginate(@pages)
  #
  #   # In view:
  #   <%= pagination_letters(@pages) %>
  #   <%= pagination_numbers(@pages) %>
  #
  def paginate_letters(letter_arg = :letter, number_arg = :page,
                       num_per_page = 50)
    MOPaginator.new(
      letter_arg: letter_arg,
      number_arg: number_arg,
      letter: paginator_letter(letter_arg),
      number: paginator_number(number_arg),
      num_per_page: num_per_page
    )
  end

  # Initialize Paginator object.  This now does very little thanks to
  # the new Query model.
  # arg::           Name of parameter to use.  (default is 'page')
  # num_per_page::  Number of results per page.  (default is 50)
  #
  #   # In controller:
  #   query    = create_query(:Name, :by_user, :user => params[:id].to_s)
  #   @numbers = paginate_numbers(:page, 50)
  #   @names   = query.paginate(@numbers)
  #
  #   # In view:
  #   <%= pagination_numbers(@numbers) %>
  #
  def paginate_numbers(arg = :page, num_per_page = 50)
    MOPaginator.new(
      number_arg: arg,
      number: paginator_number(arg),
      num_per_page: num_per_page
    )
  end

  private ##########

  def paginator_letter(parameter_key)
    return nil unless params[parameter_key].to_s =~ /^([A-Z])$/i

    Regexp.last_match(1).upcase
  end

  def paginator_number(parameter_key)
    params[parameter_key].to_s.to_i
  rescue StandardError
    1
  end

  public ##########

  ##############################################################################
  #
  #  :section: Memory usage.
  #
  ##############################################################################

  def extra_gc
    ObjectSpace.garbage_collect
  end

  ##############################################################################
  #
  #  :section: Other stuff
  #
  ##############################################################################

  # Before filter: disable link prefetching.
  #
  # This, I'm inferring, is when an over-achieving browser actively goes out
  # prefetching all the pages linked to from the current page so that the user
  # doesn't have to wait as long when they click on one.  The problem is, if
  # the browser pre-fetches something like +destroy_comment+, it could
  # potentially delete or otherwise harm things unintentionally.
  #
  # The old policy was to disable this feature for a few obviously dangerous
  # actions.  I've changed it now to only _enable_ it for common (and safe)
  # actions like show_observation, post_comment, etc.  Each controller is now
  # responsible for explicitly listing the actions which accept it.
  # -JPH 20100123
  #
  def disable_link_prefetching
    return unless request.env["HTTP_X_MOZ"] == "prefetch"

    logger.debug("prefetch detected: sending 403 Forbidden")
    render(plain: "", status: :forbidden)
    false
  end

  # Tell an object that someone has looked at it (unless a robot made the
  # request).
  def update_view_stats(object)
    return unless object.respond_to?(:update_view_stats) && !browser.bot?

    object.update_view_stats
  end

  # Default image size to use for thumbnails: either :thumbnail or :small.
  # Looks at both the user's pref (if logged in) or the session (if not logged
  # in), else reverts to small. *NOTE*: This method is available to views.
  def default_thumbnail_size
    if @user
      @user.thumbnail_size
    else
      session[:thumbnail_size]
    end || :thumbnail
  end
  helper_method :default_thumbnail_size

  def default_thumbnail_size_set(val)
    if @user && @user.thumbnail_size != val
      @user.thumbnail_size = val
      @user.save_without_our_callbacks
    else
      session[:thumbnail_size] = val
    end
  end

  def calc_layout_params
    count = @user&.layout_count || MO.default_layout_count
    { "count" => count }
  end

  def permission?(obj, error_message)
    result = (in_admin_mode? || obj.can_edit?(@user))
    flash_error(error_message) unless result
    result
  end

  def can_delete?(obj)
    permission?(obj, :runtime_no_destroy.l(type: obj.type_tag))
  end

  def can_edit?(obj)
    permission?(obj, :runtime_no_update.l(type: obj.type_tag))
  end

  def render_xml(args)
    request.format = "xml"
    respond_to do |format|
      format.xml { render args }
    end
  end

  # Bad place for this, but need proper refactor to have a good place.
  def gather_users_votes(obs, user)
    obs.namings.each_with_object({}) do |naming, votes|
      votes[naming.id] =
        naming.votes.find { |vote| vote.user_id == user.id } ||
        Vote.new(value: 0)
    end
  end

  ##############################################################################

  private

  # defined here because used by both image_controller and observer_controller
  def whitelisted_image_args
    [:copyright_holder, :image, :license_id, :notes, :original_name, :when]
  end
end
