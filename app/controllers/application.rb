#
#  This file is included in every controller.  Mostly it is made up of methods
#  and filters in the ApplicationController class which are made available to
#  all controllers.  But there are also several random class extensions thrown
#  in here for lack of more appropriate place to do so. 
#
################################################################################

require 'login_system'
require 'active_record_extensions'

if !defined? CSS
  CSS = ['Agaricus', 'Amanita', 'Cantharellaceae', 'Hygrocybe']
  SVN_REPOSITORY = "http://svn.collectivesource.com/mushroom_sightings"
end

module Enumerable
  # Select random value.
  def select_rand
    tmp = self.to_a
    tmp[Kernel.rand(tmp.size)]
  end
end

def rand_char(str)
  sprintf("%c", str[Kernel.rand(str.length)])
end

def random_password(len)
  result = ''
  for n in (0..len)
    result += rand_char('abcdefghijklmnopqrstuvwxyz0123456789')
  end
  result
end

module ActionView
  # This instructs ActionView how to mark form fields which have an error.
  # I just change the CSS class to "has_error", which gives it a red border.
  # This is superior to the default, which encapsulates the field in a div,
  # because that throws the layout off.  Just changing the border, while less
  # conspicuous, has no effect on the layout.
  Base.field_error_proc = Proc.new{ |html_tag, instance|
    html_tag.sub(/(<\w+)/, '\1 class="has_error"')
  }
end

module ActiveRecord
  class Base
    def self.find_by_sql_with_limit(sql, offset, limit)
      sql = sanitize_sql(sql)
      add_limit!(sql, {:limit => limit, :offset => offset})
      find_by_sql(sql)
    end

    def self.count_by_sql_wrapping_select_query(sql)
      sql = sanitize_sql(sql)
      count_by_sql("select count(*) from (#{sql}) as my_table")
    end
  end
end

################################################################################
#
#  Filters added to this controller will be run for all controllers in the
#  application.  Likewise, all methods here will be available for all
#  controllers.
#
#    paginate_by_sql(model, ...)  Same as paginate, but works on lower level.
#    paginate_array(list, per)    Just paginate pre-existing array.
#
#    field_search(fields, pat)    Creates sql query: any of a list of fields like a pattern?
#    query_ids(query)             Gets list of ids given sql query.
#    clean_sql_pattern(pattern)
#
#    map_loc(map, loc)            Overlay one location square on map.
#    make_map(locs)               Create and draw map.
#    finish_map(map)
#
#    make_table_row(list)         Turn list into "<tr><td>x</td>...</tr>".
#    calc_color(r1,c1, r2,c2)     Calculate background color in alternating list.
#    calc_layout_params           Gather user-pref stats for drawing matrix-list.
#
#    check_permission(user_id)    Make sure current user is a given user.
#    check_user_id(user_id)       Same, but flashes "denied" message, too.
#    verify_user()                Make sure current user has been verified.
#
#    flash_clear                  Clear error messages.
#    flash_notice(str)            Add a success message.
#    flash_warning(str)           Add a warning message.
#    flash_error(str)             Add an error message.
#    flash_object_notices(obj)    Add all errors for a given instance (as notices).
#    flash_object_warnings(obj)   Add all errors for a given instance (as warnings).
#    flash_object_errors(obj)     Add all errors for a given instance.
#
#    setup_sorter(...)            Sets up a NameSorter object. (???)
#    construct_approved_names(...) Makes sure a list of names exists.
#    construct_approved_name(...) (helper)
#    save_names(...)              (helper)
#    create_needed_names(...)     Processes a single name entered by user.
#
#    translate_menu(menu)         Translate keys in select-menu's options.
#
#    autologin                    Before filter that logs user in automatically.
#    set_autologin_cookie(user)   Set autologin cookie.
#    clear_autologin_cookie       Clear autologin cookie.
#    set_session_user(user)       Store user in session (ID only).
#    get_session_user             Retrieve user from session.
#
#  Private methods:
#
#    disable_link_prefetching     Prevents browser from prefetching destroy methods.
#
#    set_locale                   Internationalization stuff.
#    get_sorted_langs_from_accept_header
#    get_valid_lang_from_accept_header
#    standardize_locale(locale)
#    get_matching_ui_locale(locale)
#
#    pass_seq_params()
#    store_seq_state(state)
#    store_search_state(state)
#    calc_search(type, conditions, order)
#    calc_search_params
#
#    show_selected_objs(title, conditions, order, source, obj_type, dest, links=nil)
#    session_setup
#
################################################################################

class ApplicationController < ActionController::Base
  include ExceptionNotifiable
  include LoginSystem

  around_filter :set_locale
  before_filter :browser_status
  before_filter :autologin

  before_filter(:disable_link_prefetching, :only => [
    # account_controller methods
    :logout_user, :delete, :signup,

    # observer_controller methods
    :destroy_observation, :destroy_image,
    :destroy_comment, :destroy_species_list, :upload_image])

  # Filter that should run before everything else.  Checks for auto-login cookie.
  def autologin
    if @user = get_session_user
      # Do nothing if already logged in: if user asked us to remember him the
      # cookie will already be there, if not then we want to leave it out.
      @user.reload if @user.id != 0

    # Log in if cookie is valid, and autologin is enabled.
    elsif (cookie = cookies[:mo_user])  &&
          (split = cookie.split("_")) &&
          (user = User.find(:first, :conditions => ['id = ? and password = ?', split[0], split[1]]))
      @user = set_session_user(user)

      # Reset cookie to push expiry forward.  This way it will continue to
      # remember the user until they are inactive for over a month.  (Else
      # they'd have to login every month, no matter how often they login.)
      set_autologin_cookie(user)

    # Delete invalid cookies.
    else
      clear_autologin_cookie
    end
  end

  # Store and remove auto-login cookie.
  def set_autologin_cookie(user)
    cookies[:mo_user] = {
      :value => "#{user.id}_#{user.password}",
      :expires => 1.month.from_now
    }
  end

  def clear_autologin_cookie
    cookies.delete :mo_user
  end

  # Store user in session (ID only).
  def set_session_user(user)
    session[:user_id] = user ? user.id : nil 
    return user
  end

  # Retrieve currently logged in user from session, if any.
  # Returns User object or nil.
  def get_session_user
    id = session[:user_id]
    id.nil? ? nil : id != 0 || !TESTING ? User.find(id) : begin
      # (for some reason I can't add this to the test fixtures)
      user = User.new
      user.login = 'root'
      user.name = 'root'
      user.verified = Time.now
      user.email = 'root@blah.com'
      user.id = 0
      user
    end
  end

  def make_table_row(list)
    result = list.map {|x| "<td>#{x}</td>"}
    result = "<tr>#{result.join}</tr>"
  end

  def map_loc(map, loc) # , icon)
    info = ("<span class=\"gmap\"><a href=\"/location/show_location/#{loc.id}\">#{loc.display_name}</a><table>" +
      make_table_row(['',loc.north,'']) +
      make_table_row([loc.west, '', loc.east]) +
      make_table_row(['', loc.south, '']) + "</table></span>")
    pline = GPolyline.new([[loc.north, loc.west],[loc.north, loc.east],
      [loc.south, loc.east], [loc.south, loc.west], [loc.north, loc.west]],"#00ff88",3,1.0)
    map.overlay_init(GMarker.new(loc.center(),
      :title => loc.display_name, :info_window => info)) # , :icon => icon))
    map.overlay_init(pline)
  end

  def make_map(locs)
    result = GMap.new("map_div")
    result.control_init(:large_map => true,:map_type => true)

    # Started playing with icons and the following got something to show up, but I decide
    # not to pursue it further right now.
    # result.icon_global_init( GIcon.new( :image => "/images/blue-dot.png", :icon_size => GSize.new( 24,38 ), :icon_anchor => GPoint.new(12,38), :info_window_anchor => GPoint.new(9,2) ), "blue_dot")
    # blue_dot = Variable.new("blue_dot")

    if respond_to?( "start_lat" ) && respond_to?( "start_long" )
        map.center_zoom_init( [start_lat, start_long], Constants::GM_ZOOM )
        map.overlay_init( GMarker.new( [start_lat, start_long], { :icon => icon_start, :title => name + " start", :info_window => "start" } ) )
    end

    result.center_zoom_on_points_init(*((locs.map {|l| l.south_west}) + (locs.map {|l| l.north_east})))
    for l in locs
      # map_loc(result, l, blue_dot)
      map_loc(result, l)
    end
    result
  end

  def finish_map(map)
    result = map.to_html(:no_script_tag => 1)
    "<script type=\"text/javascript\"><!--\n" + result + "--></script>"
  end

  def clean_sql_pattern(pattern)
    pattern.gsub(/[*']/,"%")
  end

  # Creates sql query: any of a list of fields like a pattern?
  def field_search(fields, sql_pattern)
    (fields.map{|n| "#{n} like '#{sql_pattern}'"}).join(' or ')
  end

  # Ultimately running large queries like this and storing the info in the session
  # may become unwieldy.  Storing the query and selecting chunks will scale better.
  def query_ids(query)
    result = []
    data = Observation.connection.select_all(query)
    for d in data
      id = d['id']
      if id
        result.push(id.to_i)
      end
    end
    result
  end

################################################################################

  def paginate_by_sql(model, sql, per_page, options={})
    if options[:count]
        if options[:count].is_a? Integer
            total = options[:count]
        else
            total = model.count_by_sql(options[:count])
        end
    else
        total = model.count_by_sql_wrapping_select_query(sql)
    end

    object_pages = Paginator.new self, total, per_page,
         params['page']
    objects = model.find_by_sql_with_limit(sql,
         object_pages.current.to_sql[1], per_page)
    return [object_pages, objects]
  end

  # Paginate a plain old list of stuff that you've already populated.
  # Returns Paginator object (which will draw the page number links)
  # and the subset of the array that the user is currently viewing.
  def paginate_array(list, per_page, page=nil)
    page = params['page'] ? params['page'] : 1 if page.nil?
    page = page.to_i
    pages = Paginator.new self, list.length, per_page, page
    return [pages, list[(page-1)*per_page, per_page]]
  end

  # Initialize PaginationLetters object.  Takes list of arbitrary items.
  # By default it takes first letter of <tt>item.to_s</tt>, but you can override
  # this by supplying a block.  Takes an optional hash of arguments:
  #   :arg    Name of argument in params to use.  (default is 'letter')
  #
  #   def action
  #     # Create list of objects.
  #     list = Model.find(...)
  #     # Initialize letter paginator.
  #     letters, list = paginate_letters(list, length) {|i| i.title[0,1]}
  #     # Initialize standard page-number paginator.
  #     numbers, list = paginate_array(list, length)
  #   end
  #
  #   view.rhtml:
  #     <%# Insert pagination links for letters. %>
  #     <div><%= pagination_letters(letters) %></div>
  #     <%# Insert pagination links for numbers. %>
  #     <div><%= pagination_numbers(numbers, letters) %></div>
  #
  # Note, pagination_links() does not know about this letter paginator, so it
  # will not supply the 'letter' parameter correctly.  Thus you need to use
  # this pagination_numbers() wrapper if you want to have both paginators.
  def paginate_letters(list, length=50, args={})
    # Don't draw links if too short.
    list = [] if !list
    return [nil, list] if list.length == 0

    obj = PaginationLetters.new
    obj.letters = letters = {}
    obj.used    = used    = {}
    obj.arg     = arg     = args[:arg] || 'letter'
    obj.letter  = letter  = params[arg]

    # Gather map of items to their first letter, as well as a hash of letters
    # that are used.
    for item in list
      if block_given?
        l = yield(item)
        l ||= "_"
        l = l[0,1].upcase
        l = "_" if !l.match(/^[A-Z]$/)
      elsif item.to_s.match(/([a-z])/i)
        l= $~[1].upcase
      else
        l= "_"
      end
      letters[item] = l
      used[l] = true
    end
    return [nil, list] if used.keys.length <= 1

    # If user has clicked on a letter, remove all items:
    # 1) above that letter (Douglas's preference)
    # 2) above and below that letter (Darvin's preference)  <---
    if letter && letter.match(/^([A-Z])/)
      letter = $~[1]
      list = list.select do |item|
        # letters[item] >= letter
        letters[item] == letter
      end
      obj.letter = letter
    else
      obj.letter = nil
    end

    return [obj, list]
  end

  # Simple class to handle pagination by letter.
  class PaginationLetters
    # Maps items to letters.
    attr_accessor :letters

    # Hash of letters that we have items for.
    attr_accessor :used

    # Argument in params to use.
    attr_accessor :arg

    # Current letter.
    attr_accessor :letter
  end

################################################################################

  helper_method :calc_color
  def calc_color(row, col, alt_rows, alt_cols)
    color = 0
    if alt_rows
      color = row % 2
    end
    if alt_cols
      if (col % 2) == 1
        color = 1 - color
      end
    end
    color
  end

  def calc_layout_params
    result = {}
    result["rows"] = 5
    result["columns"] = 3
    result["alternate_rows"] = true
    result["alternate_columns"] = true
    result["vertical_layout"] = true
    if user = get_session_user
      result["rows"] = user.rows if user.rows
      result["columns"] = user.columns if user.columns
      result["alternate_rows"] = user.alternate_rows
      result["alternate_columns"] = user.alternate_columns
      result["vertical_layout"] = user.vertical_layout
    end
    result["count"] = result["rows"] * result["columns"]
    result
  end

  # This is called by create_name_helper (used by create_observation and
  # create/edit_naming) and deprecate_name.  It creates a new name, first
  # checking if it is a valid name, and that it has been approved by the
  # user.  Uses Name.names_from_string(@what) to do the parsing.
  # Inputs:
  #   input_what    params[:approved_name]  (name that user typed before
  #                 getting the "this name not recognized" message)
  #   output_what   @what (name after "this name not recognized" message,
  #                 must be the same or it is not "approved")
  #   user
  def create_needed_names(input_what, output_what, user)
    result = nil
    if input_what == output_what
      # This returns an array of Names: genus, species, then variety (if
      # applicable).  New names are created for any that don't exist...
      # but they need to be saved if they are new (just check if any is
      # missing an id).
      names = Name.names_from_string(output_what)
      if names.last.nil?
        flash_error "Unable to create the name '#{output_what}'."
      else
        for n in names
          if n
            if n.id # (if it has an id it already exists)
              PastName.check_for_past_name(n, user, "Updated by #{user.login}.")
            else # (if it doesn't have an id it is new)
              n.user = user
            end
            n.save
          end
        end
      end
      result = names.last
    end
    result
  end

  def check_user_id(user_id)
    result = check_permission(user_id)
    unless result
      flash_error "Permission denied."
    end
    result
  end

  helper_method :check_permission
  def check_permission(user_id)
    user = get_session_user
    !user.nil? && user.verified && ((user_id == user.id) || (user.id == 0))
  end

  def verify_user()
    result = false
    if get_session_user.verified.nil?
      redirect_to :controller => 'account', :action=> 'reverify', :id => get_session_user.id
    else
      result = true
    end
    result
  end

  # Clear error/warning messages -- needed by post methods to clear old
  # messages out of the queue.  (Used by app layout.)
  helper_method :flash_clear
  def flash_clear
    flash[:test_notice] = flash[:notice] if TESTING
    flash[:notice] = nil
    flash[:notice_level] = 0
  end

  # Append an error/warning message to flash[:notice].
  def flash_notice(str)
    flash[:notice] += "<br/>" if flash[:notice]
    flash[:notice] = "" if !flash[:notice]
    flash[:notice] += str
  end

  def flash_warning(str)
    flash_notice(str)
    flash[:notice_level] = 1 if !flash[:notice_level] || flash[:notice_level] < 1
  end

  def flash_error(str)
    flash_notice(str)
    flash[:notice_level] = 2 if !flash[:notice_level] || flash[:notice_level] < 2
  end

  # Display errors for the given object (if there are any).
  def flash_object_notices(obj)
    if obj && obj.errors && obj.errors.length > 0
      flash_notice obj.formatted_errors.join("<br/>")
    end
  end

  def flash_object_warnings(obj)
    if obj && obj.errors && obj.errors.length > 0
      flash_warning obj.formatted_errors.join("<br/>")
    end
  end

  def flash_object_errors(obj)
    if obj && obj.errors && obj.errors.length > 0
      flash_error obj.formatted_errors.join("<br/>")
    end
  end

  def translate_menu(menu)
    result = []
    for k,v in menu
      result << [ k.l, v ]
    end
    return result
  end

################################################################################

  # Sets up a NameSorter object.
  # Used by: bulk_name_editor, create/edit_species_list
  # Inputs:
  #   species_list                        ?
  #   list                                ?
  #   params[:chosen_names]               ?
  #   params[:chosen_approved_names]      ?
  #   params[:approved_deprecated_names]  ?
  #   params[:checklist_data]             ?
  # Returns: NameSorter object
  def setup_sorter(params, species_list, list)
    sorter = NameSorter.new

    # Seems like valid selections should take precedence over multiple names,
    # but I haven't constructed a lot of examples.  If it makes more sense for multiples
    # to take precedence over valid names, then swap the next two lines.
    # If they need to be more carefully considered, then the lists may need to get
    # merged in the display.
    sorter.add_chosen_names(params[:chosen_names]) # hash
    sorter.add_chosen_names(params[:chosen_approved_names]) # hash

    sorter.add_approved_deprecated_names(params[:approved_deprecated_names])
    sorter.check_for_deprecated_checklist(params[:checklist_data])
    if species_list
      sorter.check_for_deprecated_names(species_list.observations.map {|o| o.name})
    end
    sorter.sort_names(list)
    sorter
  end

  # Makes sure a list of names exists.
  # Used by: bulk_name_editor, change_synonyms, create/edit_species_list
  # Inputs:
  #   name_list         string, delimted by newlines (see below for syntax)
  #   approved_names    array of search_names (or string delimited by "/")
  #   user              (used if need to create any names)
  #   deprecate?        are any created names to be deprecated?
  # Syntax: (NameParse class does the actual parsing)
  #   Xxx yyy
  #   Xxx yyy var. zzz
  #   Xxx yyy Author
  #   Xxx yyy sensu Blah
  #   Valid name Author = Deprecated name Author
  #   blah blah [comment]
  #   (this is described better in views/observer/bulk_name_edit.rhtml)
  def construct_approved_names(name_list, approved_names, user, deprecate=false)
    if approved_names
      if approved_names.class == String
        approved_names = approved_names.split("/")
      end
      for ns in name_list
        if ns.strip != ''
          name_parse = NameParse.new(ns)
          construct_approved_name(name_parse, approved_names, user, deprecate)
        end
      end
    end
  end

  # Processes a single line from the list above.
  # Used only by construct_approved_names().
  def construct_approved_name(name_parse, approved_names, user, deprecate)
    # Don't do anything if the given names are not approved
    if approved_names.member?(name_parse.search_name)
      # Create name object for this name (and any parents, such as genus).
      names = Name.names_from_string(name_parse.search_name)
      if names.last.nil?
        flash_error "Unable to create the name '#{name_parse.name}'."
      else # (this only happens if above genus, in which case names.length == 1)
        names.last.rank = name_parse.rank if name_parse.rank
        # only save comment if name didn't exist
        names.last.notes = name_parse.comment if !names.last.id && name_parse.comment
        # Save the names (deals with deprecation here).
        save_names(names, user, deprecate)
      end
    end
    # This will happen if the user did the "Valid name = Deprecated synonym"
    # syntax, AND the deprecated synonym doesn't currently exist, AND was
    # approved.
    if name_parse.has_synonym && approved_names.member?(name_parse.synonym_search_name)
      synonym_names = []
      # Create the deprecated synonym.
      synonym_names = Name.names_from_string(name_parse.synonym_search_name)
      if synonym_names.last.nil?
        flash_error "Unable to create the synonym '#{name_parse.synonym}'.\n"
      else
        synonym_name = synonym_names.last
        synonym_name.rank = name_parse.synonym_rank if name_parse.synonym_rank
        # only save comment if name didn't exist
        synonym_name.notes = name_parse.synonym_comment if !synonym_name.id && name_parse.synonym_comment
        synonym_name.change_deprecated(true)
        unless PastName.check_for_past_name(synonym_name, user, "Deprecated by #{user.login}")
          synonym_name.user = user
          synonym_name.save
        end
        save_names(synonym_names[0..-2], user, nil) # Don't change higher taxa
      end
    end
  end

  # Makes sure an array of names are saved, deprecating them if you wish.
  # Inputs:
  #   names         array of name objects (unsaved)
  #   user          needed in case have to create or deprecate any names
  #   deprecate     create them deprecated to start with
  def save_names(names, user, deprecate)
    msg = nil
    unless deprecate.nil?
      if deprecate
        msg = "Deprecated by #{user.login}"
      else
        msg = "Approved by #{user.login}"
      end
    end
    for n in names
      if n # Could be nil if parent is ambiguuous with respect to the author
        n.change_deprecated(deprecate) unless deprecate.nil? or n.id
        unless PastName.check_for_past_name(n, user, msg)
          unless n.id # Only save if it's brand new
            n.user = user
            n.save
          end
        end
      end
    end
  end

  # Helper function for determining if there are notifications for the given
  # user and flavor.
  def has_unshown_notifications(user, flavor=:naming)
    result = false
    for q in QueuedEmail.find_all_by_flavor_and_to_user_id(flavor, user.id)
      ints = q.get_integers([:shown], true)
      unless ints[:shown]
        result = true
        break
      end
    end
    result
  end

################################################################################

  private

  def disable_link_prefetching
    if request.env["HTTP_X_MOZ"] == "prefetch"
      logger.debug "prefetch detected: sending 403 Forbidden"
      render_nothing "403 Forbidden"
      return false
    end
  end

  # Set the locale from the parameters, the session, or the navigator
  # If none of these works, the Globalite default locale is set (en-*)
  def set_locale
    # Get the current path and request method (useful in the layout for changing the language)
    @current_path = request.env['PATH_INFO']
    @request_method = request.env['REQUEST_METHOD']

    # Try to get the locale from the parameters, from the session, and then from the navigator
    if params[:user_locale]
      logger.debug "[globalite] #{params[:user_locale][:code]} locale passed"
      Locale.code = params[:user_locale][:code] #get_matching_ui_locale(params[:user_locale][:code]) #|| session[:locale] || get_valid_lang_from_accept_header || Globalite.default_language
      # Store the locale in the session
      session[:locale] = Locale.code
    elsif session[:locale]
      logger.debug "[globalite] loading locale: #{session[:locale]} from session"
      Locale.code = session[:locale]
    else
      # Changed code from Globalite sample app since Locale.code= didn't like 'pt-br'
      # but did like 'pt-BR'.  standardize_locale was added to take a locale spec
      # and enforce this standard.
      locale = standardize_locale(get_valid_lang_from_accept_header)
      logger.debug "[globalite] found a valid http header locale: #{locale}"
      Locale.code = locale
    end

    # Add a last gasp default if the selected locale doesn't match any of our
    # existing translations.
    if :app_title.l == '__localization_missing__'
      logger.warn("No translation exists for: #{Locale.code}")
      Locale.code = "en-US"
    end

    # Locale.code = "en-US"
    logger.debug "[globalite] Locale set to #{Locale.code}"
    # render the page
    yield

    # reset the locale to its default value
    Locale.reset!
  end

  # Get a sorted array of the navigator languages
  def get_sorted_langs_from_accept_header
    accept_langs = (request.env['HTTP_ACCEPT_LANGUAGE'] || "en-us,en;q=0.5").split(/,/) rescue nil
    return nil unless accept_langs

    # Extract langs and sort by weight
    # Example HTTP_ACCEPT_LANGUAGE: "en-au,en-gb;q=0.8,en;q=0.5,ja;q=0.3"
    wl = {}
    accept_langs.each {|accept_lang|
        if (accept_lang + ';q=1') =~ /^(.+?);q=([^;]+).*/
            wl[($2.to_f rescue -1.0)]= $1
        end
    }
    logger.debug "[globalite] client accepted locales: #{wl.sort{|a,b| b[0] <=> a[0] }.map{|a| a[1] }.to_sentence}"
    sorted_langs = wl.sort{|a,b| b[0] <=> a[0] }.map{|a| a[1] }
  end

  # Returns a valid language that best suits the HTTP_ACCEPT_LANGUAGE request header.
  # If no valid language can be deduced, then <tt>nil</tt> is returned.
  def get_valid_lang_from_accept_header
    # Get the sorted navigator languages and find the first one that matches our available languages
    get_sorted_langs_from_accept_header.detect{|l| get_matching_ui_locale(l) }
  end

  # standardize_locale was added to take a locale spec and enforce the standard that
  # the lang be lower case and the country be upper case.  The Globalite Locale.code=
  # method seems to expect this standard, but Firefox uses all lower case.
  def standardize_locale(locale)
    lang = locale[0,2].downcase
    country = '*'
    if locale[3,5]
      country = locale[3,5].upcase
    end
    result = "#{lang}-#{country}".to_sym
    logger.debug "[globalite] trying to match #{result}"
    result
  end

  # Returns the UI locale that best matches with the parameter
  # or nil if not found
  def get_matching_ui_locale(locale)
    lang = locale[0,2].downcase
    if locale[3,5]
      country = locale[3,5].upcase
      logger.debug "[globalite] trying to match locale: #{lang}-#{country}"
      locale_code = "#{lang}-#{country}".to_sym
    else
      logger.debug "[globalite] trying to match #{lang}-*"
      locale_code = "#{lang}-*".to_sym
    end

    # Check with exact matching
    if Globalite.ui_locales.values.include?(locale)
      logger.debug "[globalite] Globalite does include #{locale}"
      locale_code
    end

    # Check on the language only
    Globalite.ui_locales.values.each do |value|
      value.to_s =~ /#{lang}-*/ ? value : nil
    end
  end

  # session[:seq_states]
  #  :count => Number of numeric keys allocated (used to allocate new ones)
  #  <number> => State for a particular search
  #         [:current_id, :current_index, :next_id, :prev_id, :timestamp, :count]
  # Use cases:
  #   Multiple tabs, back button
  # Only purge if a new state is being added
  # Keep any state that is less than 1 hour old.
  # Keep any state with :count > 0 whose timestamp is less than 24 hours ago.
  def store_seq_state(state)
    now = state.timestamp
    result = session[:seq_states]
    if result
      if not result.member?(state.key)
        result = {:count => result[:count]}
        for (key, value) in session[:seq_states]
          timestamp = value[:timestamp] || 0
          age = now - timestamp
          count = value[:access_count] || 0
          if (age < 1.hour) || ((count > 0) && (age < 24.hours))
            result[key] = value
          end
        end
      end
    else
      result = {:count => 0}
    end
    state.timestamp = now
    result[state.key] = state.session_data()
    session[:seq_states] = result
  end

  # session[:search_states]
  #  :count => Number of numeric keys allocated (used to allocate new ones)
  #  <number> => State for a particular search
  #         [:current_id, :current_index, :next_id, :prev_id, :timestamp, :count]
  # Use cases:
  #   Multiple tabs with different searches, back button
  # Only purge if a new state is being added
  # Keep any state that is less than 1 hour old.
  # Keep any state with :count > 0 whose timestamp is less than 24 hours ago.
  def store_search_state(state)
    now = state.timestamp
    result = session[:search_states]
    if result
      if not result.member?(state.key)
        result = {:count => result[:count]}
        for (key, value) in session[:search_states]
          timestamp = value[:timestamp] || 0
          age = now - timestamp
          count = value[:access_count] || 0
          if (age < 1.hour) || ((count > 0) && (age < 24.hours))
            result[key] = value
          end
        end
      end
    else
      result = {:count => 0}
    end
    state.timestamp = now
    result[state.key] = state.session_data()
    session[:search_states] = result
  end

  # If provided, link should be the arguments for link_to as a list of lists,
  # e.g. [[:action => 'blah'], [:action => 'blah']]
  def show_selected_objs(title, conditions, order, source, obj_type, dest, links=nil)
    search_state = SearchState.new(session, params, obj_type, logger)
    unless search_state.setup?
      search_state.setup(title, conditions, order, source)
    end
    store_search_state(search_state)

    store_location
    @user = get_session_user
    @layout = calc_layout_params
    @links = links
    @title = search_state.title
    @search_seq = search_state.key
    query = search_state.query
    session[:checklist_source] = search_state.source
    session_setup
    case obj_type
    when :observations
      type = Observation
    when :images
      type = Image
    end
    session[:observation] = nil

    @obj_pages, @objs = paginate_by_sql(type, query, @layout["count"])
    render :action => dest # 'list_observations'
  end

  def session_setup
    session[:observation_ids] = nil if session[:observation_ids]
    session[:observation] = nil if session[:observation]
    session[:image_ids] = nil if session[:image_ids]
    @user = get_session_user
  end

  # Unfortunately the conditions are currently raw SQL that require knowledge of the
  # queries in SearchState.query...
  def calc_search(type, conditions, order)
    search = SearchState.new(session, params, type)
    if not search.setup?
      search.setup(nil, conditions, order, :nothing)
    end
    store_search_state(search)
    search
  end

  def pass_seq_params()
    @seq_key = params[:seq_key]
    @search_seq = params[:search_seq]
    @obs = params[:obs]
  end

  def calc_search_params
    search_params = {}
    search_params[:search_seq] = @search_seq if @search_seq
    search_params[:seq_key] = @seq_key if @seq_key
    search_params[:obs] = @obs if @obs
    search_params
  end
end
