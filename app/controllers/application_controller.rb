# encoding: utf-8
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
#  check_user_alert::   Check if User has an alert to be displayed.
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
#  is_reviewer?::           Is the current User a reviewer?
#  is_in_admin_mode?::      Is the current User in admin mode?
#  has_unshown_notifications?::
#                           Are there pending Notification's of a given type?
#  check_user_alert::       (filter: redirect to show_alert if has alert)
#  set_autologin_cookie::   (set autologin cookie)
#  clear_autologin_cookie:: (clear autologin cookie)
#  set_session_user::       (store user in session -- id only)
#  get_session_user::       (retrieve user from session)
#
#  ==== Internationalization
#  all_locales::            Array of available locales for which we have
#                           translations.
#  set_locale::             (filter: determine which locale is requested)
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
#  get_query_from_session:: Gets Query that was stored in the session above.
#  query_params::           Parameters to add to link_to, etc. for passing
#                           Query around.
#  set_query_params::       Make +query_params+ refer to a given Query.
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
#  log_memory_usage::       (filter: logs memory use stats from
#                           <tt>/proc/$$/smaps</tt>)
#  extra_gc::               (filter: calls <tt>ObjectSpace.garbage_collect</tt>)
#  count_objects::          (does... nothing??!!... for every Object that
#                           currently exists)
#
#  ==== Other stuff
#  disable_link_prefetching:: (filter: prevents prefetching of destroy methods)
#  update_view_stats::      Called after each show_object request.
#  calc_layout_params::     Gather User's list layout preferences.
#  catch_errors             (filter: catches errors for integration tests)
#  default_thumbnail_size:: Default thumbnail size: :thumbnail or :small.
#  set_default_thumbnail_size:: Change default thumbnail size for  current user.
#
class ApplicationController < ActionController::Base
  require "extensions"
  require "login_system"
  require "csv"
  include LoginSystem

  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  around_action :catch_errors # if Rails.env == "test"
  before_action :kick_out_robots
  before_action :create_view_instance_variable
  before_action :verify_authenticity_token
  before_action :fix_bad_domains
  before_action :autologin
  before_action :set_locale
  before_action :set_timezone
  before_action :refresh_translations
  before_action :track_translations
  before_action :check_user_alert
  # before_action :extra_gc
  # after_action  :extra_gc
  # after_action  :log_memory_usage

  # Disable all filters except set_locale.
  # (Used to streamline API and Ajax controllers.)
  def self.disable_filters
    skip_action_callback :verify_authenticity_token
    skip_action_callback :fix_bad_domains
    skip_action_callback :autologin
    skip_action_callback :set_timezone
    skip_action_callback :refresh_translations
    skip_action_callback :track_translations
    skip_action_callback :check_user_alert
    # skip_action_callback   :extra_gc
    # skip_action_callback   :log_memory_usage
    before_action :disable_link_prefetching
    before_action { User.current = nil }
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

  # Physically eject robots unless they're looking at accepted pages.
  def kick_out_robots
    return true unless browser.bot?
    return true if Robots.allowed?(
      controller: params[:controller],
      action:     params[:action],
      ua:         browser.ua,
      ip:         request.remote_ip
    )
    render(text: "Robots are not allowed on this page.", status: 403,
           layout: false)
    false
  end

  # Make sure user is logged in and has posted something -- i.e., not a spammer.
  def require_successful_user
    return true if @user && @user.is_successful_contributor?
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
  def catch_errors
    start      = Time.current
    controller = params[:controller]
    action     = params[:action]
    robot      = browser.bot? ? "robot" : "user"
    ip         = catch_ip
    url        = catch_url
    ua         = catch_ua
    yield
    logger.warn("TIME: #{Time.current - start} #{status}"\
                "#{controller} #{action} #{robot} #{ip}\t#{url}\t#{ua}")
  rescue => e
    raise @error = e
  end

  def catch_ip
    request.remote_ip
  rescue
    "unknown"
  end

  def catch_url
    request.url
  rescue
    "unknown"
  end

  def catch_ua
    browser.ua
  rescue
    "unknown"
  end

  # Update Globalite with any recent changes to translations.
  def refresh_translations
    Language.update_recent_translations
  end

  # Keep track of localization strings so users can edit them (sort of) in situ.
  def track_translations
    @language = Language.find_by(locale: I18n.locale)
    if @user && @language &&
       (!@language.official || is_reviewer?)
      Language.track_usage(flash[:tags_on_last_page])
    else
      Language.ignore_usage
    end
  end

  # Need to pass list of tags used in this action to next page if redirecting.
  def redirect_to(*args)
    flash[:tags_on_last_page] = Language.save_tags if Language.tracking_usage
    super
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
    # render(text: "Sorry, we've taken MO down to test something urgent."\
    #              "We'll be back in a few minutes. -Jason", layout: false)
    # return false

    # if browser.bot?
    #   render(status: 503, text: "robots are temporarily blocked from MO",
    #          layout: false)
    #   return false
    # end

    # Guilty until proven innocent...
    clear_user_globals

    # Do nothing if already logged in: if user asked us to remember him the
    # cookie will already be there, if not then we want to leave it out.
    if (user = get_session_user) && user.verified
      refresh_logged_in_user_instance(user)

    # Log in if cookie is valid, and autologin is enabled.
    elsif (cookie = cookies["mo_user"]) &&
          (split = cookie.split(" ")) &&
          (user = User.where(id: split[0]).first) &&
          (split[1] == user.auth_code) &&
          user.verified
      login_valid_user(user)
    else delete_invalid_cookies
    end

    make_logged_in_user_available_to_everyone
    track_last_page_request_by_user
    block_suspended_users
  end

  def clear_user_globals
    @user = nil
    User.current = nil
  end

  def refresh_logged_in_user_instance(user)
    @user = user
    @user.reload
  end

  def login_valid_user(user)
    @user = set_session_user(user)
    @user.last_login = Time.current
    @user.save

    # Reset cookie to push expiry forward.  This way it will continue to
    # remember the user until they are inactive for over a month.  (Else
    # they'd have to login every month, no matter how often they login.)
    set_autologin_cookie(user)
  end

  def delete_invalid_cookies
    clear_autologin_cookie
    set_session_user(nil)
  end

  def make_logged_in_user_available_to_everyone
    User.current = @user
    logger.warn("user=#{@user ? @user.id : "0"}" \
                "robot=#{browser.bot? ? "Y" : "N"}")
  end

  # Track when user requested a page, but update at most once an hour.
  def track_last_page_request_by_user
    if @user && (
        !@user.last_activity ||
        @user.last_activity.to_s("%Y%m%d%H") != Time.current.to_s("%Y%m%d%H")
    )
      @user.last_activity = Time.current
      @user.save
    end
  end

  def block_suspended_users
    return true unless user_suspended? # Tell Rails to continue processing.
    block user
    false                              # Tell Rails to stop processing.
  end

  def user_suspended?
    @user && @user.id == 2750 # Kick Byrain off the site.
  end

  def block_user
    render(text: "Your account has been temporarily suspended.",
           layout: false)
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
    is_in_admin_mode? || correct_user_for_object?(obj)
  end
  helper_method :check_permission

  def correct_user_for_object?(obj)
    owned_by_user?(obj) || editable_by_user?(obj) || obj_is_user?(obj)
  end

  def owned_by_user?(obj)
    obj.respond_to?(:user_id) && User.current_id == obj.user_id
  end

  def editable_by_user?(obj)
    obj.respond_to?(:has_edit_permission?) &&
      obj.has_edit_permission?(User.current)
  end

  def obj_is_user?(obj)
    (obj.is_a?(String) || obj.is_a?(Integer)) && obj.to_i == User.current_id
  end

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
      flash_error :permission_denied.t
    end
    result
  end
  alias_method :check_user_id, :check_permission!

  # Is the current User a reviewer?  Returns true or false.  (*NOTE*: this is
  # available to views.)
  def is_reviewer?
    result = false
    result = @user.in_group?("reviewers") if @user
    result
  end
  alias_method :is_reviewer, :is_reviewer?
  helper_method :is_reviewer
  helper_method :is_reviewer?

  # Is the current User in admin mode?  Returns true or false.  (*NOTE*: this
  # is available to views.)
  def is_in_admin_mode?
    @user && @user.admin && session[:admin]
  end
  helper_method :is_in_admin_mode?

  # Are there are any QueuedEmail's of the given flavor for the given User?
  # Returns true or false.
  #
  # This only applies to emails that are associated with Notification's for
  # which there is a note_template.  (Only one type now: Notification's with
  # flavor :name, which corresponds to QueuedEmail's with flavor :naming.)
  def has_unshown_notifications?(user, flavor = :naming)
    result = false
    QueuedEmail.where(flavor: flavor, to_user_id: user.id).each do |q|
      ints = q.get_integers(%w(shown notification), true)
      next if ints["shown"]
      notification = Notification.safe_find(ints["notification"].to_i)
      if notification && notification.note_template
        result = true
        break
      end
    end
    result
  end

  # ----------------------------
  #  "Private" methods.
  # ----------------------------

  # Before filter: check if the current User has an alert.  If so, it redirects
  # to <tt>/account/show_alert</tt>.  Returns true.
  def check_user_alert
    if @user && @user.alert && @user.alert_next_showing < Time.current &&
       # Careful not to start infinite redirect-loop!
       action_name != "show_alert"
      redirect_to(controller: :account, action: :show_alert)
    end
    true
  end

  # Create/update the auto-login cookie.
  def set_autologin_cookie(user)
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
  def set_session_user(user)
    session[:user_id] = user ? user.id : nil
    user
  end

  # Retrieve the User from session.  Returns User object or nil.  (Does not
  # check verified status or anything.)
  def get_session_user
    User.safe_find(session[:user_id])
  end

  ##############################################################################
  #
  #  :section: Internationalization
  #
  ##############################################################################

  # Get sorted list of locale codes (String's) that we have translations for.
  def all_locales
    Dir.glob(::Rails.root.to_s + "/config/locales/*.yml").sort.map do |file|
      file.sub(/.*?(\w+-\w+).yml/, '\\1')
    end
  end
  helper_method :all_locales

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
    code = specified_locale || MO.default_locale

    # Only change the Locale code if it needs changing.  There is about a 0.14
    # second performance hit every time we change it... even if we're only
    # changing it to what it already is!!
    change_locale_if_needed(code)

    # Update user preference.
    if @user && @user.locale.to_s != I18n.locale.to_s
      @user.update(locale: I18n.locale.to_s)
    end

    logger.debug "[I18n] Locale set to #{I18n.locale}"

    # Tell Rails to continue to process request.
    true
  end

  def specified_locale
    params_locale || prefs_locale || session_locale || browser_locale
  end

  def params_locale
    return unless params[:user_locale]
    logger.debug "[I18n] loading locale: #{params[:user_locale]} from params"
    params[:user_locale]
  end

  def prefs_locale
    return unless @user && !@user.locale.blank? && params[:controller] != "ajax"
    logger.debug "[I18n] loading locale: #{@user.locale} from @user"
    @user.locale
  end

  def session_locale
    return unless session[:locale]
    logger.debug "[I18n] loading locale: #{session[:locale]} from session"
    session[:locale]
  end

  def browser_locale
    return unless (locale = valid_locale_from_request_header)
    logger.debug "[I18n] loading locale: #{locale} from request header"
    locale
  end

  def change_locale_if_needed(code)
    new_locale = code.split("-")[0]
    return if I18n.locale.to_s == new_locale
    I18n.locale = new_locale
    session[:locale] = new_locale
  end

  # Before filter: Set timezone based on cookie set in application layout.
  def set_timezone
    tz = cookies[:tz]
    if tz.blank?
      # For now, until we get rid of reliance on @js, this is a surrogate for
      # testing if the client's JS is enabled and sufficiently fully-featured.
      @js = Rails.env == "test"
    else
      begin
        Time.zone = tz
      rescue
        logger.warn "TimezoneError: #{tz.inspect}"
      end
      @js = true
    end
  end

  # Return Array of the browser's requested locales (HTTP_ACCEPT_LANGUAGE).
  # Example syntax:
  #
  #   en-au,en-gb;q=0.8,en;q=0.5,ja;q=0.3
  #
  def sorted_locales_from_request_header
    result = []
    if (accepted_locales = request.env["HTTP_ACCEPT_LANGUAGE"])

      # Extract locales and weights, creating map from locale to weight.
      locale_weights = {}
      accepted_locales.split(",").each do |term|
        next unless (term + ";q=1") =~ /^(.+?);q=([^;]+)/
        locale_weights[Regexp.last_match(1)] = (begin
                                                  Regexp.last_match(2).to_f
                                                rescue
                                                  -1.0
                                                end)
      end

      # Now sort by decreasing weights.
      result = locale_weights.sort { |a, b| b[1] <=> a[1] }.map { |a| a[0] }
    end

    logger.debug "[globalite] client accepted locales: #{result.join(", ")}"
    result
  end
  include ::ContentFilter
  helper_method(:observation_filters, :observation_filters_with_checkboxes)

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

  # Returns our locale that best suits the HTTP_ACCEPT_LANGUAGE request header.
  # Returns a String, or <tt>nil</tt> if no valid match found.
  def lookup_valid_locale(requested_locales)
    match = "en"
    requested_locales.each do |locale|
      logger.debug "[globalite] trying to match locale: #{locale}"
      language = locale.split("-").first

      if I18n.available_locales.include?(language.to_sym)
        match = language
        logger.debug "[globalite] language match: #{match}"
      end

      break if match
    end
    match
  end

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
    session[:notice].to_s[1..-1].html_safe
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
    @last_notice = session[:notice] if Rails.env == "test"
    session[:notice] = nil
  end
  helper_method :flash_clear

  # Report an informational message that will be displayed (in green) at the
  # top of the next page the User sees.
  def flash_notice(*strs)
    session[:notice] += "<br/>" if session[:notice]
    session[:notice] ||= "0"
    session[:notice] += strs.map(&:to_s).join("<br/>")
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
    return unless obj && obj.errors && !obj.errors.empty?
    flash_error(obj.formatted_errors.join("<br/>"))
  end

  def save_with_log(obj)
    type_sym = obj.class.to_s.underscore.to_sym
    if obj.save
      flash_notice(:runtime_created_at.t(type: type_sym))
      return true
    else
      flash_error(:runtime_no_save.t(type: type_sym))
      flash_object_errors(obj)
      return false
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
      flash_error :runtime_no_create_name.t(type: :name,
                                            value: name_parse.name)
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
      flash_error :runtime_no_create_name.t(type: :name,
                                            value: name_parse.synonym)
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
  def get_query_from_session
    if id = session[:checklist_source]
      Query.safe_find(id)
    end
  end

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
    if browser.bot?
      # do nothing
    elsif query
      query.save unless query.id
      params[:q] = query.id.alphabetize
    elsif @query_params
      params[:q] = @query_params[:q]
    end
    params
  end
  helper_method :add_query_param

  def redirect_with_query(args)
    redirect_to(add_query_param(args))
  end

  def url_with_query(args)
    url_for(add_query_param(args))
  end

  def coerced_query_link(query, model)
    return nil unless query && query.is_coercable?(model.name.to_sym)
    link_args = {
      controller: model.show_controller,
      action: model.index_action
    }
    return [
      :show_objects.t(type: model.type_tag),
      add_query_param(link_args, query)
    ]
  end
  helper_method :coerced_query_link

  # Pass the in-coming query parameter(s) through to the next request.
  def pass_query_params
    @query_params = {}
    @query_params[:q] = params[:q] unless params[:q].blank?
    @query_params
  end

  # Change the query that +query_params+ passes along to the next request.
  # *NOTE*: This method is available to views.
  def set_query_params(query = nil)
    @query_params = {}
    if browser.bot?
      # do nothing
    elsif query
      query.save unless query.id
      @query_params[:q] = query.id.alphabetize
    end
    @query_params
  end
  helper_method :set_query_params

  # Lookup an appropriate Query or create a default one if necessary.  If you
  # pass in arguments, it modifies the query as necessary to ensure they are
  # correct.  (Useful for specifying sort conditions, for example.)
  def find_or_create_query(model_symbol, args = {})
    map_past_bys(args)
    model = model_symbol.to_s
    if result = find_query(model, false)

      # Check if the existing query needs to be updated.
      any_changes = false
      for arg, val in args
        if result.params[:arg] != val
          any_changes = true
          break
        end
      end

      # If it does, we need to create a new query, otherwise the modifications
      # won't persist.  Use the existing query as the template, though.
      if any_changes
        result = create_query(model, result.flavor, result.params.merge(args))
      end

    # Otherwise, just create a default one.
    else
      result = create_query(model, :all, args)
    end

    if result && !browser.bot?
      result.increment_access_count
      result.save
    end
    result
  end

  BY_MAP = {
    "modified" => :updated_at,
    "created" => :created_at
  }

  def map_past_bys(args)
    args[:by] = (BY_MAP[args[:by].to_s] || args[:by]) if args.member?(:by)
  end

  # Lookup the given kind of Query, returning nil if it no longer exists.
  def find_query(model = nil, update = !browser.bot?)
    model = model.to_s if model
    result = nil
    q = begin
          params[:q].dealphabetize
        rescue
          nil
        end
    if q && (query = Query.safe_find(q))
      # This is right kind of query.
      if !model || (query.model.to_s == model)
        result = query
      # If not, try coercing it.
      elsif query2 = query.coerce(model)
        result = query2
      # If that fails, try the outer query coercing if necessary.
      elsif query = query.outer
        if query.model.to_s == model
          result = query
        elsif query2 = query.coerce(model)
          result = query2
        end
      end
      if update && result
        result.increment_access_count
        result.save
      end
    end
    result
  end

  # Create a new Query of the given flavor for the given model.  Pass it
  # in all the args you would to Query#new. *NOTE*: Not all flavors are
  # capable of supplying defaults for every argument.
  def create_query(model_symbol, flavor = :all, args = {})
    Query.lookup(model_symbol, flavor, args)
  end

  # Create a new query by adding a bounding box to the given one.
  def restrict_query_to_box(query)
    if params[:north].blank?
      query
    else
      model = query.model.to_s.to_sym
      flavor = query.flavor
      args = query.params.merge(
        north: tweak_up(params[:north], 0.001, 90),
        south: tweak_down(params[:south], 0.001, -90),
        east: tweak_up(params[:east], 0.001, 180),
        west: tweak_down(params[:west], 0.001, -180)
      )
      Query.lookup(model, flavor, args)
    end
  end

  def tweak_up(v, amount, max)
    [max, v.to_f + amount].min
  end

  def tweak_down(v, amount, min)
    [min, v.to_f - amount].max
  end

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
    if object = find_or_goto_index(model, id)

      # Special exception for prev/next in RssLog query: If go to "next" in
      # show_observation, for example, inside an RssLog query, go to the next
      # object, even if it's not an observation.    If...
      if params[:q] && # ... query parameter given
         (q = begin
                params[:q].dealphabetize
              rescue
                nil
              end) &&
         (query = Query.safe_find(q)) && # ... and query exists
         (query.model == RssLog)      && # ... and it's a RssLog query
         (rss_log = begin
                      object.rss_log
                    rescue
                      nil
                    end) && # ... and current rss_log exists
         query.index(rss_log) && # ... and it's in query results
         (query.current = object.rss_log) && # ... and can set current index in query results
         (new_query = query.send(method)) && # ... and next/prev doesn't return nil (at end)
         (rss_log = new_query.current) # ... and can get new rss_log object
        query  = new_query
        object = rss_log.target || rss_log
        id = object.id

      # Normal case: attempt to coerce the current query into an appropriate
      # type, and go from there.  This handles all the exceptional cases:
      # 1) query not coercable (creates a new default one)
      # 2) current object missing from results of the current query
      # 3) no more objects being left in the query in the given direction
      else
        query = find_or_create_query(object.class)
        query.current = object
        if !query.index(object)
          type = object.type_tag
          flash_error(:runtime_object_not_in_index.t(id: object.id, type: type))
        elsif new_query = query.send(method)
          query = new_query
          id = query.current_id
        else
          type = object.type_tag
          flash_error(:runtime_no_more_search_objects.t(type: type))
        end
      end

      # Redirect to the show_object page appropriate for the new object.
      redirect_to(add_query_param({
                                    controller: object.show_controller,
                                    action: object.show_action,
                                    id: id
                                  }, query))
    end
  end

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
  # store_location::          Sets this as the +redirect_back_or_default+ location.
  # clear_query_in_session::  Clears the query from the "clipboard" (if you didn't just store this query on it!).
  # set_query_params::        Tells +query_params+ to pass this query on in links on this page.
  #
  def show_index_of_objects(query, args = {})
    letter_arg   = args[:letter_arg] || :letter
    number_arg   = args[:number_arg] || :page
    num_per_page = args[:num_per_page] || 50
    include      = args[:include] || nil
    type = query.model.type_tag

    update_filter_status_of(query)

    # Tell site to come back here on +redirect_back_or_default+.
    store_location

    # Clear out old query from session.  (Don't do it if caller just finished
    # storing *this* query in there, though!!)
    clear_query_in_session if session[:checklist_source] != query.id

    # Pass this query on when clicking on results.
    set_query_params(query)

    # Supply a default title.
    @title ||= query.title

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
        when :of_children
          name = query.find_cached_parameter_instance(Name, :name)
          :runtime_index_no_of_children.t(type: type,
                                          name: name.display_name)
        when :of_name
          name = query.find_cached_parameter_instance(Name, :name)
          :runtime_index_no_of_name.t(type: type, name: name.display_name)
        when :of_parents
          name = query.find_cached_parameter_instance(Name, :name)
          :runtime_index_no_of_parents.t(type: type,
                                         name: name.display_name)
        when :pattern_search
          :runtime_no_matches_pattern.t(type: type,
                                        value: query.params[:pattern].to_s).html_safe
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

    # Add magic links for sorting.
    if (sorts = args[:sorting_links]) &&
       (sorts.length > 1) &&
       !browser.bot?
      @sorts = add_sorting_links(query, sorts, args[:link_all_sorts])
    else
      @sorts = nil
    end
    # "@sorts".print_thing(@sorts)

    # Get user prefs for displaying results as a matrix.
    if args[:matrix]
      @layout = calc_layout_params
      num_per_page = @layout["count"]
    end

    # Inform the query that we'll need the first letters as well as ids.
    query.need_letters = args[:letters] if args[:letters]

    # Get number of results first so we know how to paginate.
    @timer_start = Time.now
    @num_results = query.num_results
    @timer_end = Time.now

    # If only one result (before pagination), redirect to 'show' action.
    if (query.num_results == 1) &&
       !args[:always_index]
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
      if !args[:id].blank? &&
         params[@pages.letter_arg].blank? &&
         params[@pages.number_arg].blank?
        @pages.show_index(query.index(args[:id]))
      end

      # Instantiate correct subset.
      logger.warn("QUERY starting: #{query.query.inspect}")
      @timer_start = Time.now
      @objects = query.paginate(@pages, include: include)
      @timer_end = Time.now
      logger.warn("QUERY finished: model=#{query.model}, " \
                  "flavor=#{query.flavor}, params=#{query.params.inspect}, " \
                  "time=#{(@timer_end - @timer_start).to_f}")

      # Give the caller the opportunity to add extra columns.
      if block_given?
        @extra_data = @objects.inject({}) do |data, object|
          row = yield(object)
          row = [row] unless row.is_a?(Array)
          data[object.id] = row
          data
        end
      end

      # Render the list if given template.
      render(action: args[:action]) if args[:action]
    end
  end

  def update_filter_status_of(query)
    apply_allowed_default_filter_prefs_to(query)
    @on_obs_filters = query.on_obs_filters if query.respond_to?(:on_obs_filters)
  end

  def apply_allowed_default_filter_prefs_to(query)
    apply_default_filters_to(query) if default_filters_applicable_to?(query)
  end

  # The default filters are applicable if the query responds to them
  # AND the query is unfiltered.
  def default_filters_applicable_to?(query)
    query.respond_to?(:observation_filter_input) &&
      !query.has_obs_filter_params?
  end

  # Apply user defaults if they exists, else apply site-wide default.
  def apply_default_filters_to(query)
    default_filters = @user ? @user.content_filter : MO.default_content_filter
    query.params.merge!(default_filters) if default_filters
  end

  # Create sorting links for index pages, "graying-out" the current order.
  def add_sorting_links(query, links, link_all = false)
    results = []
    this_by = query.params[:by] || query.default_order
    this_by = this_by.to_s.sub(/^reverse_/, "")

    for by, label in links
      str = label.t
      if !link_all && (by.to_s == this_by)
        results << str
      else
        results << [str, { controller: query.model.show_controller,
                           action: query.model.index_action,
                           by: by }.merge(query_params)]
      end
    end

    # Add a "reverse" button.
    str = :sort_by_reverse.t
    if query.params[:by].to_s.match(/^reverse_/)
      reverse_by = this_by
    else
      reverse_by = "reverse_#{this_by}"
    end
    results << [str, { controller: query.model.show_controller,
                       action: query.model.index_action,
                       by: reverse_by }.merge(query_params)]

    results
  end

  # Lookup a given object, displaying a warm-fuzzy error and redirecting to the
  # appropriate index if it no longer exists.
  def find_or_goto_index(model, id)
    result = model.safe_find(id)
    unless result
      flash_error(:runtime_object_not_found.t(id: id || "0",
                                              type: model.type_tag))
      redirect_with_query(controller: model.show_controller,
                          action: model.index_action)
    end
    result
  end

  # Redirects to an appropriate fallback index in case of unrecoverable error.
  # Most such errors are dealt with on a case-by-case basis in the controllers,
  # however a few generic actions don't necessarily know where to send users
  # when things go south.  This makes a good stab at guessing, at least.
  def goto_index(redirect = nil)
    pass_query_params
    redirect = redirect.name.underscore if redirect.is_a?(Class)
    model = case (redirect || controller.name).to_s
            when "account" then RssLog
            when "comment" then Comment
            when "image" then Image
            when "location" then Location
            when "name" then Name
            when "naming" then Observation
            when "observation" then Observation
            when "observer" then RssLog
            when "project" then Project
            when "rss_log" then RssLog
            when "species_list" then SpeciesList
            when "user" then RssLog
            when "vote" then Observation
    end
    fail "Not sure where to go from #{redirect || controller.name}." unless model
    redirect_with_query(controller: model.show_controller,
                        action: model.index_action)
  end

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
  def paginate_letters(letter_arg = :letter, number_arg = :page, num_per_page = 50)
    MOPaginator.new(
      letter_arg: letter_arg,
      number_arg: number_arg,
      letter: (params[letter_arg].to_s.match(/^([A-Z])$/i) ? Regexp.last_match(1).upcase : nil),
      number: (begin
                 params[number_arg].to_s.to_i
               rescue
                 1
               end),
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
      number: (begin
                 params[arg].to_s.to_i
               rescue
                 1
               end),
      num_per_page: num_per_page
    )
  end

  ##############################################################################
  #
  #  :section: Memory usage.
  #
  ##############################################################################

  def count_objects
    ObjectSpace.each_object { |_o| }
  end

  def extra_gc
    ObjectSpace.garbage_collect
  end

  def log_memory_usage
    sd = sc = pd = pc = 0
    File.new("/proc/#{$PROCESS_ID}/smaps").each_line do |line|
      if line.match(/\d+/)
        val = $&.to_i
        line.match(/^Shared_Dirty/) ? (sd += val) :
        line.match(/^Shared_Clean/) ? (sc += val) :
        line.match(/^Private_Dirty/) ? (pd += val) :
        line.match(/^Private_Clean/) ? (pc += val) : 1
      end
    end
    uid = session[:user_id].to_i
    logger.warn "Memory Usage: pd=%d, pc=%d, sd=%d, sc=%d (pid=%d, uid=%d, uri=%s)\n" % \
      [pd, pc, sd, sc, $PROCESS_ID, uid, request.fullpath]
  end

  ################################################################################
  #
  #  :section: Other stuff
  #
  ################################################################################

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
    if request.env["HTTP_X_MOZ"] == "prefetch"
      logger.debug "prefetch detected: sending 403 Forbidden"
      render(text: "", status: 403)
      return false
    end
  end

  # Tell an object that someone has looked at it (unless a robot made the
  # request).
  def update_view_stats(object)
    if object.respond_to?(:update_view_stats) && !browser.bot?
      object.update_view_stats
    end
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

  # Set the default thumbnail size, either for the current user if logged in,
  # or for the current session.
  def set_default_thumbnail_size(val)
    if @user
      if @user.thumbnail_size != val
        @user.thumbnail_size = val
        @user.save_without_our_callbacks
      end
    else
      session[:thumbnail_size] = val
    end
  end

  def calc_layout_params
    count = (@user && @user.layout_count) || MO.default_layout_count
    { "count" => count }
  end

  def has_permission?(obj, error_message)
    result = (is_in_admin_mode? || obj.can_edit?(@user))
    flash_error(error_message) unless result
    result
  end

  def can_delete?(obj)
    has_permission?(obj, :runtime_no_destroy.l(type: obj.type_tag))
  end

  def can_edit?(obj)
    has_permission?(obj, :runtime_no_update.l(type: obj.type_tag))
  end

  def render_xml(args)
    request.format = "xml"
    respond_to do |format|
      format.xml { render args }
    end
  end
  ##############################################################################

  private

  # defined here because used by both image_controller and observer_controller
  def whitelisted_image_args
    [:copyright_holder, :image, :license_id, :notes, :original_name, :when]
  end
end
