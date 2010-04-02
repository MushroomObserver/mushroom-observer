#
#  = Application Controller Base Class
#
#  This is the base class for all the application's controllers.  It contains
#  all the important application-wide filters and lots of helper methods.
#  Anything that appears here is available to every controller and view.
#
#  == Filters
#
#  browser_status::     Auto-detect browser capabilities (plugin).
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
#  all_locales::            Array of available locales for which we have translations.
#  translate_menu::         Translate keys in select-menu's options.
#  set_locale::             (filter: determine which locale is requested)
#  standardize_locale::
#  get_sorted_locales_from_request_header::
#                           (parse locale preferences from request header)
#  get_valid_locale_from_request_header::
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
#  create_needed_names::      Creates the given name if it's been approved.
#  construct_approved_names:: Creates a list of names if they've been approved.
#  construct_approved_name::  (helper)
#  save_names::               (helper)
#  save_name::                (helper)
#
#  ==== Searching
#  clear_query_in_session:: Clears out Query stored in session below.
#  store_query_in_session:: Stores Query in session for use by create_species_list.
#  get_query_from_session:: Gets Query that was stored in the session above.
#  query_params::           Parameters to add to link_to, etc. for passing Query around.
#  set_query_params::       Make +query_params+ refer to a given Query.
#  pass_query_params::      Tell +query_params+ to pass-through the Query given to this action.
#  find_query::             Find a given Query or return nil.
#  find_or_create_query::   Find appropriate Query or create as necessary.
#  create_query::           Create a new Query from scratch.
#  redirect_to_next_object:: Find next object from a Query and redirect to its show page.
#  show_index_of_objects::  Show paginated set of Query results as a list.
#  find_or_goto_index::     Look up object by id, displaying error and redirecting on failure.
#  goto_index::             Redirect to a reasonable fallback (index) page in case of error.
#
#  ==== Pagination
#  paginate_letters::       Paginate an Array by letter.
#  paginate_numbers::       Paginate an Array normally.
#
#  ==== Memory usage
#  log_memory_usage::       (filter: logs memory use stats from <tt>/proc/$$/smaps</tt>)
#  extra_gc::               (filter: calls <tt>ObjectSpace.garbage_collect</tt>)
#  count_objects::          (does... nothing??!!... for every Object that currently exists)
#
#  ==== Other stuff
#  disable_link_prefetching:: Filter: prevents prefetching of destroy methods.
#  update_view_stats::      Called after each show_object request.
#  calc_layout_params::     Gather User's list layout preferences.
#
################################################################################

class ApplicationController < ActionController::Base
  require 'extensions'
  require 'login_system'
  include LoginSystem

  around_filter :catch_errors if TESTING
  before_filter :browser_status
  before_filter :autologin
  before_filter :set_locale
  before_filter :check_user_alert
  # before_filter :extra_gc
  # after_filter  :extra_gc
  # after_filter  :log_memory_usage

  # Catch errors for integration tests.
  def catch_errors
    yield
  rescue => e
    @error = e
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
    # render(:text => "Sorry, we've taken MO down to test something urgent.  We'll be back in a few minutes. -Jason", :layout => false)
    # return false

    # Guilty until proven innocent...
    @user = nil
    User.current = nil

    # Disable everything to do with cookies for API controller.
    if controller_name != 'api'

      # Do nothing if already logged in: if user asked us to remember him the
      # cookie will already be there, if not then we want to leave it out.
      if (user = get_session_user) &&
         (user.verified)
        @user = user
        @user.reload

      # Log in if cookie is valid, and autologin is enabled.
      elsif (cookie = cookies[:mo_user])  &&
            (split = cookie.split(" ")) &&
            (user = User.find(:first, :conditions => ['id = ?', split[0]])) &&
            (split[1] == user.auth_code) &&
            (user.verified)
        @user = set_session_user(user)

        # Reset cookie to push expiry forward.  This way it will continue to
        # remember the user until they are inactive for over a month.  (Else
        # they'd have to login every month, no matter how often they login.)
        set_autologin_cookie(user)

      # Delete invalid cookies.
      else
        clear_autologin_cookie
        set_session_user(nil)
      end

      # Make currently logged-in user available to everyone.
      User.current = @user
    end

    # Tell Rails to continue to process.
    return true
  end

  # Much-streamlined login "filter" used by AJAX methods that require login.
  # Just calls get_session_user, requires that the user already be logged in
  # and has user id stored in the session.
  def login_for_ajax
    get_session_user
  end

  # ----------------------------
  #  "Public" methods.
  # ----------------------------

  # Is the current User the correct User (or is admin mode on)?  Returns true
  # or false.  (*NOTE*: this is available to views.)
  #
  #   <% if check_permission(@object.user)
  #     link_to('Destroy', :action => :destroy_object)
  #   end %>
  #
  def check_permission(user)
    id = user.is_a?(ActiveRecord::Base) ? user.id : user.to_i rescue 0
    @user && (@user.id.to_i == id || is_in_admin_mode?) rescue false
  end
  helper_method :check_permission

  # Is the current User the correct User (or is admin mode on)?  Returns true
  # or false.  Flashes a "denied" error message if false.
  #
  #   def destroy_thing
  #     @thing = Thing.find(params[:id])
  #     if check_permission!(@thing.user)
  #       @thing.destroy
  #       flash_notice "Success!"
  #     end
  #     redirect_to(:action => :show_thing)
  #   end
  #
  def check_permission!(user)
    unless result = check_permission(user)
      flash_error :permission_denied.t
    end
    result
  end
  alias check_user_id check_permission!

  # Is the current User a reviewer?  Returns true or false.  (*NOTE*: this is
  # available to views.)
  def is_reviewer?
    result = false
    if @user
      result = @user.in_group?('reviewers')
    end
    result
  end
  alias is_reviewer is_reviewer?
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
  #
  def has_unshown_notifications?(user, flavor=:naming)
    result = false
    for q in QueuedEmail.find_all_by_flavor_and_to_user_id(flavor, user.id)
      ints = q.get_integers(["shown", "notification"], true)
      unless ints["shown"]
        notification = Notification.find(ints["notification"].to_i)
        if notification and notification.note_template
          result = true
          break
        end
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
    if @user && @user.alert && @user.alert_next_showing < Time.now &&
       # Careful not to start infinite redirect-loop!
       action_name != 'show_alert'
      redirect_to(:controller => :account, :action => :show_alert)
    end
    return true
  end

  # Create/update the auto-login cookie.
  def set_autologin_cookie(user)
    cookies[:mo_user] = {
      :value => "#{user.id} #{user.auth_code}",
      :expires => 1.month.from_now
    }
  end

  # Destroy the auto-login cookie.
  def clear_autologin_cookie
    cookies.delete(:mo_user)
  end

  # Store User in session (id only).
  def set_session_user(user)
    session[:user_id] = user ? user.id : nil
    return user
  end

  # Retrieve the User from session.  Returns User object or nil.  (Does not
  # check verified status or anything.)
  def get_session_user
    result = nil
    if id = session[:user_id]
      result = User.find(id) rescue nil
    end
    result
  end

  ##############################################################################
  #
  #  :section: Internationalization
  #
  ##############################################################################

  # Get sorted list of locale codes (String's) that we have translations for.
  def all_locales
    Dir.glob(RAILS_ROOT + '/lang/ui/*.yml').sort.map do |file|
      file.sub(/.*?(\w+-\w+).yml/, '\\1')
    end
  end
  helper_method :all_locales

  # Translate the given pulldown menu.  Accepts and returns the same structure
  # the select menu helper takes:
  #
  #   <%
  #     menu = [
  #       [ :label1, value1 ],
  #       [ :label2, value2 ],
  #       ...
  #     ]
  #     select('object', 'field', translate_menu(menu), options => ...)
  #   %>
  #
  # (Just calls +l+ on each label.)  (*NOTE*: this is available to views.)
  #
  def translate_menu(menu)
    result = []
    for k,v in menu
      result << [ k.l, v ]
    end
    return result
  end
  helper_method :translate_menu

  # Before filter: Decide which locale to use for this request.  Sets the
  # Globalite default.  Tries to get the locale from:
  #
  # 1. parameters (user clicked on language in bottom left)
  # 2. user prefs (user edited their preferences)
  # 3. session (whatever we used last time)
  # 4. navigator (provides default)
  # 5. server (DEFAULT_LOCALE)
  #
  def set_locale
    code = if params[:user_locale]
      logger.debug "[globalite] loading locale: #{params[:user_locale]} from params"
      params[:user_locale]
    elsif @user && !@user.locale.blank?
      logger.debug "[globalite] loading locale: #{@user.locale} from @user"
      @user.locale
    elsif session[:locale]
      logger.debug "[globalite] loading locale: #{session[:locale]} from session"
      session[:locale]
    elsif locale = get_valid_locale_from_request_header
      logger.debug "[globalite] loading locale: #{locale} from request header"
      locale
    else
      DEFAULT_LOCALE
    end

    # Only change the Locale code if it needs changing.  There is about a 0.14
    # second performance hit every time we change it... even if we're only
    # changing it to what it already is!!
    code = standardize_locale(code)
    if Locale.code.to_s != code
      Locale.code = code
      session[:locale] = code
    end

    # One last sanity check.  (All translation YML files should have :en_US
    # defined.)
    if :en_US.l != 'English'
      logger.warn("No translation exists for: #{Locale.code}")
      Locale.code = DEFAULT_LOCALE
    end

    # Update user preference.
    if @user && @user.locale.to_s != Locale.code.to_s
      @user.locale = Locale.code.to_s
      @user.save
      Transaction.put_user(
        :id         => @user,
        :set_locale => Locale.code.to_s
      )
    end

    logger.debug "[globalite] Locale set to #{Locale.code}"

    # Tell Rails to continue to process request.
    return true
  end

  # Return Array of the browser's requested locales (HTTP_ACCEPT_LANGUAGE).
  # Example syntax:
  #
  #   en-au,en-gb;q=0.8,en;q=0.5,ja;q=0.3
  #
  def get_sorted_locales_from_request_header
    result = []
    if accepted_locales = request.env['HTTP_ACCEPT_LANGUAGE']

      # Extract locales and weights, creating map from locale to weight.
      locale_weights = {}
      accepted_locales.split(',').each do |term|
        if (term + ';q=1') =~ /^(.+?);q=([^;]+)/
          locale_weights[$1] = ($2.to_f rescue -1.0)
        end
      end

      # Now sort by decreasing weights.
      result = locale_weights.sort {|a,b| b[1] <=> a[1]}.map {|a| a[0]}
    end

    logger.debug "[globalite] client accepted locales: #{result.to_sentence}"
    return result
  end

  # Returns our locale that best suits the HTTP_ACCEPT_LANGUAGE request header.
  # Returns a String, or <tt>nil</tt> if no valid match found.
  def get_valid_locale_from_request_header
    match = nil

    # Get list of available locales.
    available_locales = Globalite.ui_locales.values.map(&:to_s).sort

    # Get list of languages browser requested, sorted in the order it prefers
    # them.  (And convert them to standardized format: 'en' or 'en-US'.)
    requested_locales = get_sorted_locales_from_request_header.map do |locale|
      if locale.match(/^(\w\w)-(\w+)$/)
        locale = "#{$1.downcase}-#{$2.upcase}"
      else
        locale = locale.downcase
      end
    end

    # Look for matches.
    fallback = nil
    requested_locales.each do |locale|
      logger.debug "[globalite] trying to match locale: #{locale}"

      # What is the "preferred" dialect for this language?  Default is 'xx-XX'.
      locale2 = { 'en' => 'en-US' }[locale[0,2]] ||
                "#{locale[0,2]}-#{locale[0,2].upcase}"

      # User requested "xx-YY" and we have it.
      if available_locales.include?(locale)
        match = locale
        logger.debug "[globalite] exact match: #{match}"

      # Check for "preferred" dialect 'xx-XX' first.
      elsif available_locales.include?(locale2)
        if locale.length > 2
          # User requestsed "xx-YY", we have "xx-XX".
          fallback ||= locale2
        else
          # User requested "xx", we have "xx-XX".
          match = locale2
          logger.debug "[globalite] default language-match: #{match}"
        end

      # Now we try for any other 'xx-YY'.
      else
        available_locales.each do |locale2|
          if locale2[0,2] == locale[0,2]
            if locale.length > 2
              # User requestsed "xx-YY", we have "xx-ZZ".
              fallback ||= locale2
            else
              # User requested "xx", we have "xx-YY".
              match = locale2
              logger.debug "[globalite] other language-match: #{match}"
            end
          end
        end
      end

      break if match
    end

    # Fallback can be set if the user requested only exact locales.  If none
    # of their exact locales worked, we give them default language-matches (in
    # the same order) instead.  Example:
    #
    #   request  = en-AU,pt-PT
    #   match    = --                   (no matches)
    #   fallback = en-US                (but "en" would have matched)
    #
    # We have neither en-AU nor pt-PT, but we do have en-US and pt-BR.  We give
    # them en-US because en-XX comes before pt-XX in their request.  Normally
    # they would request something like this instead, of course:
    #
    #   request = en-AU,en,pt-PT,pt
    #   match   = en-US                 (both "en" and "pt" match)
    #
    match || fallback
  end

  # Standardize locale code to the format Globalite uses: 'xx-YY'.  Returns a
  # String or raises a RuntimeError if it's invalid.  (*NOTE*: Globalite's
  # +Locale.code+ is a symbol!)
  #
  #   en_us  ->  en-US
  #   en-us  ->  en-US
  #   en_US  ->  en-US
  #   en-US  ->  en-US
  #   en     ->  (error)
  #   en-*   ->  (error)
  #   e-US   ->  (error)
  #   eng-US ->  (error)
  #
  def standardize_locale(code)
    if code.to_s.match(/^([a-z][a-z])[_\-](\w+)/i)
      $1.downcase + '-' + $2.upcase
    else
      raise "Invalid locale: '#{code}'"
    end
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
    session[:notice].to_s[1..-1]
  end
  helper_method :flash_get_notices

  # Get current notice level. (0 = notice, 1 = warning, 2 = error)
  def flash_notice_level
    level = session[:notice].to_s[0,1]
    level == '' ? nil : level.to_i
  end
  helper_method :flash_notice_level

  # Clear error/warning messages. *NOTE*: This is done automatically by the
  # application layout (app/views/layouts/application.rhtml) every time it
  # renders the latest error messages.
  def flash_clear
    if TESTING
      flash[:rendered_notice] = session[:notice]
    end
    session[:notice] = nil
  end
  helper_method :flash_clear

  # Report an informational message that will be displayed (in green) at the
  # top of the next page the User sees.
  def flash_notice(str)
    session[:notice] += '<br/>' if session[:notice]
    session[:notice] ||= '0'
    session[:notice] += str
  end
  helper_method :flash_notice

  # Report a warning message that will be displayed (in yellow) at the top of
  # the next page the User sees.
  def flash_warning(str)
    flash_notice(str)
    session[:notice][0,1] = '1' if session[:notice][0,1] == '0'
  end
  helper_method :flash_warning

  # Report an error message that will be displayed (in red) at the top of the
  # next page the User sees.
  def flash_error(str)
    flash_notice(str)
    session[:notice][0,1] = '2' if session[:notice][0,1] != '2'
  end
  helper_method :flash_error

  # Report the errors for a given ActiveRecord::Base instance.  These will be
  # displayed (in red) at the top of the next page the User sees.
  #
  #   if object.save
  #     flash_notice "Yay!"
  #   else
  #     flash_error "Failed to save changes."
  #     flash_object_error(object)
  #   end
  #
  def flash_object_errors(obj)
    if obj && obj.errors && obj.errors.length > 0
      flash_error obj.formatted_errors.join("<br/>")
    end
  end

  ##############################################################################
  #
  #  :section: Name validation
  #
  ##############################################################################

  # This is called by +create_name_helper+ (used by +create_observation+,
  # +create_naming+, and +edit_naming+) and +deprecate_name+.  It creates a new
  # name, first checking if it is a valid name, and that it has been approved
  # by the user.  Uses <tt>Name.names_from_string(@what)</tt> to do the
  # parsing.
  #
  # Inputs:
  #
  #   input_what    params[:approved_name]  (name that user typed before
  #                 getting the "this name not recognized" message)
  #   output_what   @what (name after "this name not recognized" message,
  #                 must be the same or it is not "approved")
  def create_needed_names(input_what, output_what)
    result = nil
    if input_what == output_what

      # This returns an array of Names: genus, species, then variety (if
      # applicable).  New names are created for any that don't exist... but
      # they need to be saved if they are new (just check if any is missing
      # an id).
      names = Name.names_from_string(output_what)
      if names.last.nil?
        flash_error :runtime_no_create_name.t(:type => :name,
                                              :value => output_what)
      else
        for n in names
          save_name(n, :log_updated_by) if n
        end
      end
      result = names.last
    end
    result
  end

  # Goes through list of names entered by user and creates (and saves) any that
  # are not in the database (but only if user has approved them).
  #
  # Used by: bulk_name_editor, change_synonyms, create/edit_species_list
  #
  # Inputs:
  #
  #   name_list         string, delimted by newlines (see below for syntax)
  #   approved_names    array of search_names (or string delimited by "/")
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
  def construct_approved_names(name_list, approved_names, deprecate=false)
    if approved_names
      if approved_names.is_a?(String)
        approved_names = approved_names.split(/\r?\n/)
      end
      for ns in name_list
        if !ns.blank?
          name_parse = NameParse.new(ns)
          construct_approved_name(name_parse, approved_names, deprecate)
        end
      end
    end
  end

  # Processes a single line from the list above.
  # Used only by construct_approved_names().
  def construct_approved_name(name_parse, approved_names, deprecate)

    # Don't do anything if the given names are not approved
    if approved_names.member?(name_parse.name)

      # Create name object for this name (and any parents, such as genus).
      names = Name.names_from_string(name_parse.search_name)

      # Parse must have failed.
      if names.last.nil?
        flash_error :runtime_no_create_name.t(:type => :name,
                                              :value => name_parse.name)

      # Was successful.
      else
        name = names.last
        name.rank = name_parse.rank if name_parse.rank

        # Process comments (for bulk name editor).
        if comment = name_parse.comment
          # Okay to add citation to any record without an existing citation.
          if comment.match(/^citation: *(.*)/)
            citation = $1
            name.citation = citation if name.citation.blank?
          # Only save comment if name didn't exist
          elsif names.new_record?
            name.notes = comment
          else
            flash_warning("Didn't save comment for #{name.search_name}, " +
                          "name already exists. (comment = \"#{comment}\")")
          end
        end

        # Only bulk name editor allows the synonym syntax now.  Tell it to
        # approve the left-hand name.
        deprecate2 = deprecate
        deprecate2 = false if name_parse.has_synonym

        # Save the names (deals with deprecation here).
        save_names(names, deprecate2)
      end
    end

    # Do the same thing for synonym (found the Approved = Synonym syntax).
    if name_parse.has_synonym and
       approved_names.member?(name_parse.synonym)

      # Create the synonym.
      synonyms = Name.names_from_string(name_parse.synonym_search_name)

      # Parse must have failed.
      if synonyms.last.nil?
        flash_error :runtime_no_create_name.t(:type => :name,
                                              :value => name_parse.synonym)

      # Was successful.
      else
        synonym = synonyms.last
        synonym.rank = name_parse.synonym_rank if name_parse.synonym_rank

        # Process comments (for bulk name editor).
        if comment = name_parse.synonym_comment
          # Only save comment if name didn't exist
          if synonym.new_record?
            synonym.notes = comment
          else
            flash_warning("Didn't save comment for #{synonym.search_name}, " +
                          "name already exists. (comment = \"#{comment}\")")
          end
        end

        # Deprecate and save.
        synonym.change_deprecated(true)
        save_name(synonym, :log_deprecated_by, :touch => true)
        save_names(synonyms[0..-2], nil) # Don't change higher taxa
      end
    end
  end

  # Makes sure an array of names are saved, deprecating them if you wish.
  # Inputs:
  #   names         array of name objects (unsaved)
  #   deprecate     create them deprecated to start with
  def save_names(names, deprecate)
    log = nil
    unless deprecate.nil?
      if deprecate
        log = :log_deprecated_by
      else
        log = :log_approved_by
      end
    end
    for n in names
      if n # Could be nil if parent is ambiguous with respect to the author
        n.change_deprecated(deprecate) if deprecate && n.new_record?
        save_name(n, log)
      end
    end
  end

  # Save any changes to this name (including creating it if it is a new
  # record), log the change, add the current user as the editor, and log the
  # transaction appropriately for syncing with foreign databases.
  def save_name(name, log=nil, args={})
    log ||= :log_name_updated

    # Get list of args we care about.  (intersection)
    changed_args = name.changed & [
      :rank,
      :text_name,
      :author,
      :citation,
      :synonym,
      :deprecated,
      :correct_spelling,
      :notes
    ]

    # Log transaction.
    xargs = { :id => name }
    if name.new_record?
      for arg in changed_args
        arg2 = arg.to_s.sub(/_id$/,'').to_sym
        xargs[arg2] = name.send(arg)
      end
      xargs[:method] = :post
    else
      for arg in changed_args
        arg2 = arg.to_s.sub(/_id$/,'').to_sym
        xargs["set_#{arg2}"] = name.send(arg)
      end
      xargs[:method] = :put
    end

    # Save any changes.
    args = { :touch => name.altered? }.merge(args)
    name.log(log, args) if name.changed?
    if name.save
      Transaction.create(xargs)
      result = true
    else
      flash_object_errors(name)
      result = false
    end

    return result
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
    session[:checklist_source] = query.id
  end

  # Get Query last stored on the "clipboard" (session).
  def get_query_from_session
    if id = session[:checklist_source]
      Query.safe_find(id)
    else
      nil
    end
  end

  # Return query parameter(s) necessary to pass query information along to
  # the next request. *NOTE*: This method is available to views.
  def query_params(query=nil)
    if query
      {:q => query.id.alphabetize}
    else
      @query_params || {}
    end
  end
  helper_method :query_params

  # Pass the in-coming query parameter(s) through to the next request.
  def pass_query_params
    @query_params = {}
    @query_params[:q] = params[:q] if !params[:q].blank?
    @query_params
  end

  # Change the query that +query_params+ passes along to the next request.
  # *NOTE*: This method is available to views.
  def set_query_params(query=nil)
    @query_params = {}
    @query_params[:q] = query.id.alphabetize if query
    @query_params
  end
  helper_method :set_query_params

  # Lookup an appropriate Query or create a default one if necessary.  If you
  # pass in arguments, it modifies the query as necessary to ensure they are
  # correct.  (Useful for specifying sort conditions, for example.)
  def find_or_create_query(model, args={})
    model = model.to_s
    if result = find_query(model, false)

      # Check if the existing query needs to be modified.
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
      result = create_query(model, :default, args)
    end

    if result && !is_robot?
      result.access_count += 1
      result.save
    end
    return result
  end

  # Lookup the given kind of Query, returning nil if it no longer exists.
  def find_query(model=nil, update=!is_robot?)
    model = model.to_s if model
    result = nil
    if !params[:q].blank?
      if query = Query.safe_find(params[:q].dealphabetize)
        # This is right kind of query.
        if !model or (query.model_string == model)
          result = query
        # If not, try coercing it.
        elsif query2 = query.coerce(model)
          result = query2
        # If that fails, try the outer query coercing if necessary.
        elsif query = query.outer
          if query.model_string == model
            result = query
          elsif query2 = query.coerce(model)
            result = query2
          end
        end
        if update && result
          result.access_count += 1
          result.save
        end
      end
    end
    return result
  end

  # Create a new Query of the given flavor for the given model.  Pass it
  # in all the args you would to Query#new. *NOTE*: Not all flavors are
  # capable of supplying defaults for every argument.
  def create_query(model, flavor=:default, args={})
    result = Query.lookup(model, flavor, args)
    result.save if !is_robot?
    return result
  end

  # This is the common code for all the 'prev/next_object' actions.  Pass in
  # the current object and direction (:prev or :next), and it looks up the
  # query, grabs the next object, and redirects to the appropriate
  # 'show_object' action.
  #
  #   def next_image
  #     redirect_to_next_object(:next, Image, params[:id])
  #   end
  #
  def redirect_to_next_object(method, model, id)
    if object = find_or_goto_index(model, id)

      # Special exception for prev/next in RssLog query: If go to "next" in
      # show_observation, for example, inside an RssLog query, go to the next
      # object, even if it's not an observation.
      if params[:q] and
         (query = Query.safe_find(params[:q].dealphabetize)) and
         (query.model_symbol == :RssLog) and
         (rss_log = object.rss_log rescue nil) and
         query.index(rss_log) and
         (query.current = object.rss_log) and
         (new_query = query.send(method)) and
         (rss_log = new_query.current)
        query  = new_query
        object = rss_log.object || rss_log
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
          type = object.class.name.underscore.to_sym
          flash_error(:runtime_object_not_in_index.t(:id => object.id, :type => type))
        elsif new_query = query.send(method)
          query = new_query
          id = query.current_id
        else
          type = object.class.name.underscore.to_sym
          flash_error(:runtime_no_more_search_objects.t(:type => type))
        end
      end

      # Redirect to the show_object page appropriate for the new object.
      redirect_to(:controller => object.show_controller,
                  :action => object.show_action, :id => id,
                  :params => query_params(query))
    end
  end

  # Create sorting links for index pages, "graying-out" the current order.
  def add_sorting_links(query, links, link_all=false)
    results = []
    this_by = query.params[:by] || query.default_order
    this_by = this_by.to_s.sub(/^reverse_/, '')

    for by, label in links
      str = label.t
      if !link_all and (by.to_s == this_by)
        results << str
      else
        results << [str, { :controller => query.model.show_controller,
                           :action => query.model.index_action,
                           :by => by, :params => query_params }]
      end
    end

    # Add a "reverse" button.
    str = :sort_by_reverse.t
    if query.params[:by].to_s.match(/^reverse_/)
      reverse_by = this_by
    else
      reverse_by = "reverse_#{this_by}"
    end
    results << [str, { :controller => query.model.show_controller,
                       :action => query.model.index_action,
                       :by => reverse_by, :params => query_params }]

    return results
  end

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
  # @links::        
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
  def show_index_of_objects(query, args={})
    letter_arg   = args[:letter_arg]   || :letter
    number_arg   = args[:number_arg]   || :page
    num_per_page = args[:num_per_page] || 50
    include      = args[:include]      || nil

    # Tell site to come back here on +redirect_back_or_default+.
    store_location

    # Clear out old query from session.  (Don't do it if caller just finished
    # storing *this* query in there, though!!)
    if session[:checklist_source] != query.id
      clear_query_in_session
    end

    # Pass this query on when clicking on results.
    set_query_params(query)

    # Supply a default title.
    @title ||= query.title

    # Add magic links for sorting.
    if (sorts = args[:sorting_links]) and
       (sorts.length > 1)
      @sorts = add_sorting_links(query, sorts, args[:link_all_sorts])
    else
      @sorts = nil
    end

    # Get user prefs for displaying results as a matrix.
    if args[:matrix]
      @layout = calc_layout_params
      num_per_page = @layout['count']
    end

    # Inform the query that we'll need the first letters as well as ids.
    if args[:letters]
      query.need_letters = args[:letters]
    end

    # Time query -- this caches the ids (and first letters if needed).
    @timer_start = Time.now
    @num_results = query.num_results
    @timer_end = Time.now

    # If only one result (before pagination), redirect to 'show' action.
    if (query.num_results == 1) and
       !args[:always_index]
      redirect_to(:controller => query.model.show_controller,
                  :action => query.model.show_action,
                  :id => query.result_ids.first,
                  :params => query_params)

    # Otherwise paginate results.  (Everything we need should be cached now.)
    else
      @pages = if args[:letters]
        paginate_letters(letter_arg, number_arg, num_per_page)
      else
        paginate_numbers(number_arg, num_per_page)
      end

      # Skip to correct place if coming back in to index from show_object.
      if !args[:id].blank? and
         params[@pages.letter_arg].blank? and
         params[@pages.number_arg].blank?
        @pages.show_index(query.index(args[:id]))
      end

      # Instantiate correct subset.
      @objects = query.paginate(@pages, :include => include)

      # Give the caller the opportunity to add extra columns.
      if block_given?
        @extra_data = @objects.inject({}) do |data,object|
          row = yield(object)
          row = [row] if !row.is_a?(Array)
          data[object.id] = row
          data
        end
      end

      # Render the list if given template.
      render(:action => args[:action]) if args[:action]
    end
  end

  # Lookup a given object, displaying a warm-fuzzy error and redirecting to the
  # appropriate index if it no longer exists.
  def find_or_goto_index(model, id, redirect=nil)
    result = model.safe_find(id)
    if !result
      type = object.class.name.underscore.to_sym
      flash_error(:runtime_object_not_found.t(:id => id, :type => type))
      goto_index(redirect)
    end
    return result
  end

  # Redirects to an appropriate fallback index in case of unrecoverable error.
  # Most such errors are dealt with on a case-by-case basis in the controllers,
  # however a few generic actions don't necessarily know where to send users
  # when things go south.  This makes a good stab at guessing, at least.
  def goto_index(redirect=nil)
    pass_query_params
    redirect = redirect.name.underscore if redirect.is_a?(Class)
    model = case (redirect || controller.name)
      when 'account'      ; RssLog
      when 'comment'      ; Comment
      when 'image'        ; Image
      when 'location'     ; Location
      when 'name'         ; Name
      when 'naming'       ; Observation
      when 'observation'  ; Observation
      when 'observer'     ; RssLog
      when 'project'      ; Project
      when 'rss_log'      ; RssLog
      when 'species_list' ; SpeciesList
      when 'user'         ; RssLog
      when 'vote'         ; Observation
    end
    raise "Not sure where to go from #{redirect || controller.name}." if !model
    redirect_to(:controller => model.show_controller,
                :action => model.index_action, :params => query_params)
  end

  ##############################################################################
  #
  #  :section: Pagination
  #
  ##############################################################################

  # Initialize Paginator object.  This now does very little thanks to the new
  # Query model.
  # arg::    Name of parameter to use.  (default is 'letter')
  #
  #   # In controller:
  #   query  = create_query(:Name, :by_user, :user => params[:id])
  #   query.need_letters('names.observation_name')
  #   @pages = paginate_letters(:letter, :page, 50)
  #   @names = query.paginate(@pages)
  #
  #   # In view:
  #   <%= pagination_letters(@pages) %>
  #   <%= pagination_numbers(@pages) %>
  #
  def paginate_letters(letter_arg=:letter, number_arg=:page, num_per_page=50)
    MOPaginator.new(
      :letter_arg   => letter_arg,
      :number_arg   => number_arg,
      :letter       => (params[letter_arg].to_s.match(/^([A-Z])$/i) ? $1.upcase : nil),
      :number       => (params[number_arg].to_s.to_i rescue 1),
      :num_per_page => num_per_page
    )
  end

  # Initialize Paginator object.  This now does very little thanks to
  # the new Query model.
  # arg::           Name of parameter to use.  (default is 'page')
  # num_per_page::  Number of results per page.  (default is 50)
  #
  #   # In controller:
  #   query    = create_query(:Name, :by_user, :user => params[:id])
  #   @numbers = paginate_numbers(:page, 50)
  #   @names   = query.paginate(@numbers)
  #
  #   # In view:
  #   <%= pagination_numbers(@numbers) %>
  #
  def paginate_numbers(arg=:page, num_per_page=50)
    MOPaginator.new(
      :number_arg   => arg,
      :number       => (params[arg].to_s.to_i rescue 1),
      :num_per_page => num_per_page
    )
  end

  ##############################################################################
  #
  #  :section: Memory usage.
  #
  ##############################################################################

  def count_objects
    ObjectSpace.each_object do |o| end
  end

  def extra_gc
    ObjectSpace.garbage_collect
  end

  def log_memory_usage
    sd = sc = pd = pc = 0
    File.new("/proc/#{$$}/smaps").each_line do |line|
      if line.match(/\d+/)
        val = $&.to_i
        line.match(/^Shared_Dirty/)  ? (sd += val) :
        line.match(/^Shared_Clean/)  ? (sc += val) :
        line.match(/^Private_Dirty/) ? (pd += val) :
        line.match(/^Private_Clean/) ? (pc += val) : 1
      end
    end
    uid = session[:user_id].to_i
    logger.warn "Memory Usage: pd=%d, pc=%d, sd=%d, sc=%d (pid=%d, uid=%d, uri=%s)\n" % \
        [pd, pc, sd, sc, $$, uid, request.request_uri]
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
      render_nothing "403 Forbidden"
      return false
    end
  end

  # Tell an object that someone has looked at it (unless a robot made the
  # request).
  def update_view_stats(object)
    if object.respond_to?(:update_view_stats) && !is_robot?
      object.update_view_stats
    end
  end

  # Get User's list layout preferences, providing defaults as necessary.
  # Returns a hash of options.  (Uses the current user from +@user+.)
  #
  #   opts = calc_layout_params
  #
  #   opts["rows"]              # Number of rows to display.
  #   opts["columns"]           # Number of columns to display.
  #   opts["alternate_rows"]    # Alternate colors for rows.
  #   opts["alternate_columns"] # Alternate colors for columns.
  #   opts["vertical_layout"]   # Stick text below thumbnail?
  #   opts["count"]             # Total number of items = rows * columns.
  #
  def calc_layout_params
    result = {}
    result["rows"]              = 5
    result["columns"]           = 3
    result["alternate_rows"]    = true
    result["alternate_columns"] = true
    result["vertical_layout"]   = true
    if @user
      result["rows"]              = @user.rows    if @user.rows
      result["columns"]           = @user.columns if @user.columns
      result["alternate_rows"]    = @user.alternate_rows
      result["alternate_columns"] = @user.alternate_columns
      result["vertical_layout"]   = @user.vertical_layout
    end
    result["count"] = result["rows"] * result["columns"]
    result
  end
end
