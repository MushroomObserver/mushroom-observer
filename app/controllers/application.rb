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
#    calc_search(type, conditions, order)
#    calc_search_params
#
#    show_selected_objs(title, conditions, order, source, obj_type, dest, links=nil)
#    session_setup
#
################################################################################

class ApplicationController < ActionController::Base
  include LoginSystem

  before_filter :browser_status
  before_filter :autologin
  around_filter :set_locale
  after_filter :extra_gc

  before_filter(:disable_link_prefetching, :only => [
    # account_controller methods
    :logout_user, :delete, :signup,

    # observer_controller methods
    :destroy_observation, :destroy_image,
    :destroy_comment, :destroy_species_list, :upload_image,
  ])

  def test_filter
    render :text => 'This is a test.'
  end

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

  # Return true if and only if the current user is a reviewer
  def is_reviewer
    result = false
    user = get_session_user
    if !user.nil?
      result = user.in_group('reviewers')
    end
    result
  end

  def make_table_row(list)
    result = list.map {|x| "<td>#{x}</td>"}
    result = "<tr>#{result.join}</tr>"
  end

  def map_loc(map, loc) # , icon)
    info = ("<span class=\"gmap\"><a href=\"/location/show_location/#{loc.id}\">#{loc.display_name.t}</a><table>" +
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

  # Update view stats for name, image, observation, etc.
  def update_view_stats(object)
    if !is_robot?
      object.num_views += 1
      object.last_view = Time.now
      object.save
    end
  end

################################################################################

  # Paginate a list which is implicitly created using the given SQL query.
  # Returns a list of "pages" and objects themselves.
  #
  # *NOTE*: The objects returned are NOT actually proper object instances --
  # they are merely wrappers masquerading as objects.  If your query incudes
  # multiple tables, all the values selected get crammed into the list of
  # attributes for +model+.  For example, if you are paginating observations
  # and including the user and name:
  #
  #   [pages, objs] = paginate_by_sql(Observation, %(
  #     SELECT o.*, u.login, n.search_name, n.deprecated
  #     FROM observations o, users u, names, n
  #     WHERE u.id = o.user_id AND n.id = o.name_id AND etc.
  #   ), 50)
  #
  #   for obj in objs
  #     obj.when            These observation attributes are as expected.
  #     obj.what
  #     obj.where
  #     obj.notes
  #     obj.login           This attribute comes from users.
  #     obj.search_name     These attributes come from names.
  #     obj.deprecated
  #   end
  #
  # Yikes!  Not exactly what I'd call Principle of Least Surprise...
  # See ActiveRecord::Base#find_by_sql for more information.
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
    list ||= []
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
    obj = nil

    if list && list.length > 0
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

      if used.keys.length > 1
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
      end
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
        flash_error :app_no_create_name.t(:name => output_what)
      else
        now = Time.now
        for n in names
          if n
            n.save_if_changed(user, :log_updated_by, { :user => user.login }, now, true)
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
      flash_error :app_permission_denied.t
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
      redirect_to(:controller => 'account', :action=> 'reverify', :id => get_session_user.id)
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
        flash_error :app_no_create_name.t(:name => name_parse.name)
      else # (this only happens if above genus, in which case names.length == 1)
        names.last.rank = name_parse.rank if name_parse.rank
        # only save comment if name didn't exist
        names.last.notes = name_parse.comment if !names.last.id && name_parse.comment
        # Save the names (deals with deprecation here).
        save_names(names, user, deprecate)
      end
    end
    # Do the same thing for synonym (found the Approved = Synonym syntax).
    if name_parse.has_synonym && approved_names.member?(name_parse.synonym_search_name)
      synonym_names = []
      # Create the deprecated synonym.
      synonym_names = Name.names_from_string(name_parse.synonym_search_name)
      if synonym_names.last.nil?
        flash_error :app_no_create_name.t(:name => name_parse.synonym)
      else
        synonym_name = synonym_names.last
        synonym_name.rank = name_parse.synonym_rank if name_parse.synonym_rank
        # only save comment if name didn't exist
        synonym_name.notes = name_parse.synonym_comment if !synonym_name.id && name_parse.synonym_comment
        synonym_name.change_deprecated(true)
        synonym_name.save_if_changed(user, :log_deprecated_by, { :user => user.login }, Time.now, true)
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
        n.change_deprecated(deprecate) unless deprecate.nil? or n.id
        n.save_if_changed(user, log, { :user => user.login }, Time.now, true)
      end
    end
  end

  # Helper function for determining if there are notifications for the given
  # user and flavor.
  def has_unshown_notifications(user, flavor=:naming)
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

    # Try to get the locale from:
    #   1) parameters (user overrides everything)
    #   2) user prefs (whatever user chose earlier)
    #   3) session (whatever we used last time)
    #   4) navigator (provides default)
    if RAILS_ENV == 'test'
      Locale.code = ENV['LANG'] || 'en-US'
    elsif params[:user_locale]
      logger.debug "[globalite] #{params[:user_locale]} locale passed"
      Locale.code = params[:user_locale]
      # Store the locale in the session
      session[:locale] = Locale.code
    elsif @user && @user.locale && @user.locale != ''
      logger.debug "[globalite] loading locale: #{@user.locale} from @user"
      Locale.code = @user.locale
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
    # existing translations.  (All translation YML files have :en_US defined.)
    if :en_US.l != 'English'
      logger.warn("No translation exists for: #{Locale.code}")
      Locale.code = "en-US"
    end

    # Update user preference.
    if @user && @user.locale != Locale.code
      @user.locale = Locale.code
      @user.save
    end

    # Locale.code = "en-US"
    logger.debug "[globalite] Locale set to #{Locale.code}"

    # render the page
    yield

    # reset the locale to its default value
    Locale.reset!
  end
  
  def count_objects
    ObjectSpace.each_object do |o| end
  end
  
  def extra_gc
    ObjectSpace.garbage_collect
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

  # If provided, link should be the arguments for link_to as a list of lists,
  # e.g. [[:action => 'blah'], [:action => 'blah']]
  def show_selected_objs(title, conditions, order, source, obj_type, dest, links=nil)
    search_state = SearchState.lookup(params, obj_type, logger)
    unless search_state.setup?
      search_state.setup(title, conditions, order, source)
    end
    search_state.save if !is_robot?

    store_location
    @user = get_session_user
    @layout = calc_layout_params
    @links = links
    @title = search_state.title
    @search_seq = search_state.id
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
    render(:action => dest) # 'list_observations'
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
    search = SearchState.lookup(params, type)
    if not search.setup?
      search.setup(nil, conditions, order, :nothing)
    end
    search.save if !is_robot?
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
