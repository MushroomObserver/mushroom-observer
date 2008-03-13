# Filters added to this controller will be run for all controllers in the application.
# Likewise, all the methods added will be available for all controllers.
require 'login_system'
require 'active_record_extensions'

CSS = ['Agaricus', 'Amanita', 'Cantharellaceae', 'Hygrocybe']
SVN_REPOSITORY = "http://svn.collectivesource.com/mushroom_sightings"

module Enumerable
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

# This instructs ActionView how to mark form fields which have an error.
# I just change the CSS class to "has_error", which gives it a red border.
# This is superior to the default, which encapsulates the field in a div,
# because that throws the layout off.  Just changing the border, while less
# conspicuous, has no effect on the layout.
module ActionView
  Base.field_error_proc = Proc.new{ |html_tag, instance|
    html_tag.sub(/(<\w+)/, '\1 class="has_error"')
  }
end

################################################################################
#
#  Extend ActiveRecord class.
#
#  find_by_sql_with_limit(sql, offset, limit)
#  count_by_sql_wrapping_select_query(sql)
#
################################################################################

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
#  These methods will be available to all controllers.
#
#  make_table_row(list)         Turn list into "<tr><td>x</td>...</tr>".
#  paginate_by_sql(model, ...)  Same as paginate, but works on lower level.
#  field_search(fields, pat)    Creates sql query: any of a list of fields like a pattern?
#  query_ids(query)             Gets list of ids given sql query.
#  disable_link_prefetching     Prevents browser from prefetching destroy methods.
#  create_needed_names(...)     Processes a single name entered by user.
#  translate_menu(menu)         Translate keys in a [ [:sym => val], [:sym => val], ... ] structure.
#  auto_complete_name(...)      AJAX request for autocomplete on name.
#  auto_complete_location(...)  AJAX request for autocomplete on location.
#
#  map_loc(map, loc)            Overlay one location square on map.
#  make_map(locs)               Create and draw map.
#
#  calc_color(r1,c1, r2,c2)     Calculate background color in alternating list.
#  calc_layout_params           Gather user-pref stats for drawing matrix-list.
#
#  check_permission(user_id)    Make sure current user is a given user.
#  check_user_id(user_id)       Same, but flashes "denied" message, too.
#  verify_user()                Make sure current user has been verified.
#
#  flash_clear                  Clear error messages.
#  flash_notice(str)            Add a success message.
#  flash_warning(str)           Add a warning message.
#  flash_error(str)             Add an error message.
#  flash_object_notices(obj)    Add all errors for a given instance (as notices).
#  flash_object_warnings(obj)   Add all errors for a given instance (as warnings).
#  flash_object_errors(obj)     Add all errors for a given instance.
#
#  setup_sorter(...)              Sets up a NameSorter object. (???)
#  construct_approved_names(...)  Makes sure a list of names exists.
#  construct_approved_name(...)   (helper)
#  save_names(...)                (helper)
#
#  set_locale
#  get_sorted_langs_from_accept_header
#  get_valid_lang_from_accept_header
#  standardize_locale(locale)
#  get_matching_ui_locale(locale)
#
################################################################################

class ApplicationController < ActionController::Base
  include ExceptionNotifiable
  include LoginSystem

  around_filter :set_locale

  before_filter(:disable_link_prefetching, :only => [
     # account_controller methods
    :logout_user, :delete, :signup,

    # observer_controller methods
    :destroy_observation, :destroy_image,
    :destroy_comment, :destroy_species_list, :upload_image])

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
    user = session['user']
    if user
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
          if n.id # (if it has an id it already exists)
            PastName.check_for_past_name(n, user, "Updated by #{user.login}.")
          else # (if it doesn't have an id it is new)
            n.user = user
          end
          n.save
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
    user = session['user']
    !user.nil? && user.verified && ((user_id == session['user'].id) || (session['user'].id == 0))
  end

  def verify_user()
    result = false
    if session['user'].verified.nil?
      redirect_to :controller => 'account', :action=> 'reverify', :id => session['user'].id
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

  # Process AJAX request for autocompletion of mushroom name.  Pass in the
  # name of the field (eg. :proposed, :name), and it renders the result.
  # Inputs: params[arg1][arg2]
  def auto_complete_name(arg1, arg2)
    # Added ?: after an exception was thrown in which name was nil
    part = params[arg1] ? params[arg1][arg2].downcase.gsub(/[*']/,"%") : ''
    @items = []
    if (part.index(' ').nil?)
      @items = Name.find(:all, {
        :conditions => "LOWER(text_name) LIKE '#{part}%' AND text_name NOT LIKE '% %'",
        :order => "text_name ASC",
        :limit => 100
      })
    end
    if (@items.length < 100)
      @items += Name.find(:all, {
        :conditions => "LOWER(text_name) LIKE '#{part}%'",
        :order => "text_name ASC",
        :limit => 100 - @items.length
      })
      @items.sort! {|a,b| a['text_name'] <=> b['text_name']}
    end
    render :inline => "<%= content_tag('ul', @items.map { |entry| content_tag('li', content_tag('nobr', h(entry['text_name']))) }.uniq) %>"
  end

  # Process AJAX request for autocompletion of location name.  Pass in the
  # name of the field (eg. :observation, :place_name), and it renders the result.
  # Inputs: params[arg1][arg2]
  def auto_complete_location(arg1, arg2)
    part = params[arg1] ? params[arg1][arg2].downcase.gsub(/[*']/,"%") : ''
    @items = Observation.find(:all, {
      :include => :location,
      :conditions => "LOWER(observations.where) LIKE '#{part}%' or LOWER(locations.display_name) LIKE '#{part}%'",
      :order => "observations.where ASC, locations.display_name ASC",
      :limit => 10,
    })
    render :inline => "<%= content_tag('ul', @items.map { |entry| content_tag('li', content_tag('nobr', h(entry.place_name))) }.uniq) %>"
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
  #   session['user']                     (needed to resolve observation names)
  # Returns: NameSorter object
  def setup_sorter(params, species_list, list)
    sorter = NameSorter.new
    user = session['user']

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
      sorter.check_for_deprecated_names(species_list.observations.map {|o| o.preferred_name(user)})
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
      n.change_deprecated(deprecate) unless deprecate.nil? or n.id
      unless PastName.check_for_past_name(n, user, msg)
        unless n.id # Only save if it's brand new
          n.user = user
          n.save
        end
      end
    end
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

end
