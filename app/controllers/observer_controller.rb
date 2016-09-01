# encoding: utf-8

# TODO: Create RssLogController with:
#  index
#  list_rss_logs::
#  index_rss_log::
#  show_rss_log::
#  next_rss_log::
#  prev_rss_log::
#  rss::

# TODO: Create ObservationController with:
#  ==== Observation's
#  show_observation::
#  next_observation::
#  prev_observation::
#  create_observation::
#  edit_observation::
#  destroy_observation::
#  index_observation::
#  list_observations::
# Should the following be separate methods or just params?
#  observations_by_name::
#  observations_of_name::
#  observations_by_user::
#  observations_at_location::
#  observations_at_where::
#  observation_search::
# Is this just a private helper?
#  show_selected_observations:: (helper)

# TODO: Create NotificationController with:
#  show_notifications::
#  list_notifications::

# TODO: Determine where this really goes
#  JPH: --> SearchController along with pattern_search? I foresee future
#       additions to out search capabilities, like an actually-usable refine
#       search page, and a way to store and share and edit searches.
#  advanced_search::

# TODO: Create SearchController with:
#  ==== Searches
#  pattern_search::
#  advanced_search_form::

# TODO: Create MarkupController with:
#  lookup_comment::
#  lookup_image::
#  lookup_location::
#  lookup_name::
#  lookup_observation::
#  lookup_project::
#  lookup_species_list::
#  lookup_user::
#  lookup_general:: (helper)

# TODO: Create AuthorController with:
#  review_authors:: Let authors/reviewers add/remove authors from descriptions.
#  author_request:: Let non-authors request authorship credit on descriptions.

# TODO: Create UserController with:
#  change_user_bonuses::
#  index_user::
#  users_by_name::
#  users_by_contribution::
#  show_user::
#  show_site_stats::

# TODO: Create EmailController with:
#  ask_webmaster_question::
#  email_features::
#  ask_user_question::
#  ask_observation_question::
#  commercial_inquiry::
#  email_question:: (helper)

# TODO: Create InfoController with:
#  intro::
#  how_to_help::
#  how_to_use::
#  news::
#  textile_sandbox::
#  translators_note::
#  wrapup_2011

# TODO: Create ThemeController with:
#  ==== Themes
#  color_themes::
#  Agaricus::
#  Amanita::
#  Cantharellus::
#  Hygrocybe::

# TODO: Figure out where this stuff goes
#  ==== Global Callbacks
#  turn_javascript_on::
#  turn_javascript_off::
#  recalc::
#  refresh_vote_cache::
#  clear_session::
#  w3c_tests::

# TODO: Are these useful?
#  throw_error::
#  throw_mobile_error::
#
################################################################################

# The original MO controller and hence a real mess!  The Clitocybe of Controllers
class ObserverController < ApplicationController
  require "find"
  require "set"

  require_dependency "observation_report"
  require_dependency "pattern_search"

  before_action :login_required, except: MO.themes + [
    :advanced_search,
    :advanced_search_form,
    :ask_webmaster_question,
    :checklist,
    :color_themes,
    :download_observations,
    :hide_thumbnail_map,
    :how_to_help,
    :how_to_use,
    :risd_terminology,
    :index,
    :index_observation,
    :index_rss_log,
    :index_user,
    :intro,
    :list_observations,
    :list_rss_logs,
    :lookup_comment,
    :lookup_image,
    :lookup_location,
    :lookup_name,
    :lookup_observation,
    :lookup_project,
    :lookup_species_list,
    :lookup_user,
    :map_observations,
    :news,
    :next_observation,
    :observation_search,
    :observations_by_name,
    :observations_of_name,
    :observations_by_user,
    :observations_for_project,
    :observations_at_where,
    :observations_at_location,
    :pattern_search,
    :prev_observation,
    :rss,
    :show_obs,
    :show_observation,
    :show_rss_log,
    :show_site_stats,
    :show_user,
    :test,
    :textile,
    :textile_sandbox,
    :throw_error,
    :throw_mobile_error,
    :translators_note,
    :turn_javascript_nil,
    :turn_javascript_off,
    :turn_javascript_on,
    :user_search,
    :users_by_contribution,
    :w3c_tests,
    :wrapup_2011
  ]

  before_action :disable_link_prefetching, except: [
    :create_observation,
    :edit_observation,
    :show_obs,
    :show_observation,
    :show_user,
  ]

  ##############################################################################
  #
  #  :section: General Stuff
  #
  ##############################################################################

  # Default page.  Just displays latest happenings.  The actual action is
  # buried way down toward the end of this file.
  def index # :nologin:
    list_rss_logs
  end

  # Provided just as a way to verify the before_action.
  # This page should always require the user to be logged in.
  # def login # :norobots:
  #   list_rss_logs
  # end

  # Another test method.  Repurpose as needed.
  # def throw_error # :nologin: :norobots:
  #   fail "Something bad happened."
  # end

  # Used for initial investigation of specialized mobile support
  # def throw_mobile_error # :nologin: :norobots:
  #   if request.env["HTTP_USER_AGENT"].index("BlackBerry")
  #     fail "This is a BlackBerry!"
  #   else
  #     fail request.env["HTTP_USER_AGENT"].to_s
  #   end
  # end

  # def test
  #   flash_notice params.inspect
  # end

  def test_flash_redirection
    tags = params[:tags].to_s.split(",")
    if tags.any?
      flash_notice(tags.pop.to_sym.t)
      redirect_to(
        controller: :observer,
        action: :test_flash_redirection,
        tags: tags.join(",")
      )
    else
      # (sleight of hand to prevent localization_file_text from complaining
      # about missing test_flash_redirection_title tag)
      @title = "test_flash_redirection_title".to_sym.t
      render(layout: "application", text: "")
    end
  end

  def wrapup_2011 # :nologin:
  end

  # Intro to site.
  def intro # :nologin:
  end

  # Recent features.
  def news # :nologin:
  end

  # Help page.
  def how_to_use # :nologin:
    @min_pos_vote = Vote.confidence(Vote.min_pos_vote)
    @min_neg_vote = Vote.confidence(Vote.min_neg_vote)
    @maximum_vote = Vote.confidence(Vote.maximum_vote)
  end

  # A few ways in which users can help.
  def how_to_help # :nologin:
  end

  # Terminology description for RISD illustration class
  def risd_terminology # :nologin:
  end

  # Info on color themes.
  def color_themes # :nologin:
  end

  # Simple form letting us test our implementation of Textile.
  def textile_sandbox # :nologin:
    if request.method != "POST"
      @code = nil
    else
      @code = params[:code]
      @submit = params[:commit]
    end
    render(action: :textile_sandbox)
  end

  # I keep forgetting the stupid "_sandbox" thing.
  alias_method :textile, :textile_sandbox # :nologin:

  # Force javascript on.
  def turn_javascript_on # :nologin: :norobots:
    session[:js_override] = :on
    flash_notice(:turn_javascript_on_body.t)
    redirect_to(:back)
  rescue ActionController::RedirectBackError
    redirect_to("/")
  end

  # Force javascript off.
  def turn_javascript_off # :nologin: :norobots:
    session[:js_override] = :off
    flash_notice(:turn_javascript_off_body.t)
    redirect_to(:back)
  rescue ActionController::RedirectBackError
    redirect_to("/")
  end

  # Enable auto-detection.
  def turn_javascript_nil # :nologin: :norobots:
    session[:js_override] = nil
    flash_notice(:turn_javascript_nil_body.t)
    redirect_to(:back)
  rescue ActionController::RedirectBackError
    redirect_to("/")
  end

  # Simple list of all the files in public/html that are linked to the W3C
  # validator to make testing easy.
  def w3c_tests # :nologin:
    render(layout: false)
  end

  # Allow translator to enter a special note linked to from the lower left.
  def translators_note # :nologin:
  end

  # Update banner across all translations.
  def change_banner # :root: :norobots:
    if !is_in_admin_mode?
      flash_error(:permission_denied.t)
      redirect_to(action: "list_rss_logs")
    elsif request.method == "POST"
      @val = params[:val].to_s.strip
      @val = "X" if @val.blank?
      time = Time.now
      Language.all.each do |lang|
        if (str = lang.translation_strings.where(tag: "app_banner_box")[0])
          str.update!(
            text: @val,
            updated_at: (str.language.official ? time : time - 1.minute)
          )
        else
          str = lang.translation_strings.create!(
            tag: "app_banner_box",
            text: @val,
            updated_at: time - 1.minute
          )
        end
        str.update_localization
        str.language.update_localization_file
        str.language.update_export_file
      end
      redirect_to(action: "list_rss_logs")
    else
      @val = :app_banner_box.l.to_s
    end
  end

  ##############################################################################
  #
  #  :section: Searches and Indexes
  #
  ##############################################################################

  def lookup_comment
    lookup_general(Comment)
  end # :nologin

  def lookup_image
    lookup_general(Image)
  end # :nologin

  def lookup_location
    lookup_general(Location)
  end # :nologin

  def lookup_name
    lookup_general(Name)
  end # :nologin

  def lookup_accepted_name
    lookup_general(Name, true)
  end # :nologin

  def lookup_observation
    lookup_general(Observation)
  end # :nologin

  def lookup_project
    lookup_general(Project)
  end # :nologin

  def lookup_species_list
    lookup_general(SpeciesList)
  end # :nologin

  def lookup_user
    lookup_general(User)
  end # :nologin

  # MarkupController:
  # Alternative to controller/show_object/id.  These were included for the
  # benefit of the textile wrapper: We don't want to be looking up all these
  # names and objects every time we display comments, etc.  Instead we make
  # _object_ link to these lookup_object methods, and defer lookup until the
  # user actually clicks on one.  These redirect to the appropriate
  # controller/action after looking up the object.
  # inputs: model Class, true/false
  def lookup_general(model, accepted = false)
    matches = []
    suggestions = []
    type = model.type_tag
    id = params[:id].to_s.gsub(/[+_]/, " ").strip_squeeze
    begin
      if id.match(/^\d+$/)
        obj = find_or_goto_index(model, id)
        return unless obj
        matches = [obj]
      else
        case model.to_s
        when "Name"
          if (parse = Name.parse_name(id))
            matches = Name.where(search_name: parse.search_name)
            matches = Name.where(text_name: parse.text_name) if matches.empty?
            matches = fix_name_matches(matches, accepted)
          end
          if matches.empty?
            suggestions = Name.suggest_alternate_spellings(id)
            suggestions = fix_name_matches(suggestions, accepted)
          end
        when "Location"
          pattern = "%#{id}%"
          conditions = ["name LIKE ? OR scientific_name LIKE ?",
                        pattern, pattern]
          # matches = Location.find(:all, # Rails 3
          #                        limit: 100,
          #                        conditions: conditions)
          matches = Location.limit(100).where(conditions)
        when "Project"
          pattern = "%#{id}%"
          # matches = Project.find(:all, # Rails 3
          #                        limit: 100,
          #                        conditions: ["title LIKE ?", pattern])
          matches = Project.limit(100).where("title LIKE ?", pattern)
        when "SpeciesList"
          pattern = "%#{id}%"
          # matches = SpeciesList.find(:all, # Rails 3
          #                            limit: 100,
          #                            conditions: ["title LIKE ?", pattern])
          matches = SpeciesList.limit(100).where("title LIKE ?", pattern)
        when "User"
          matches = User.where(login: id)
          matches = User.where(name: id) if matches.empty?
        end
      end
    rescue => e
      flash_error(e.to_s) unless Rails.env == "production"
    end

    if matches.empty? && suggestions.empty?
      flash_error(:runtime_object_no_match.t(match: id, type: type))
      action = model == User ? :index_rss_log : model.index_action
      redirect_to(controller: model.show_controller,
                  action: action)
    elsif matches.length == 1 || suggestions.length == 1
      obj = matches.first || suggestions.first
      if suggestions.any?
        flash_warning(:runtime_suggest_one_alternate.t(match: id, type: type))
      end
      redirect_to(controller: obj.show_controller,
                  action: obj.show_action,
                  id: obj.id)
    else
      obj = matches.first || suggestions.first
      query = Query.lookup(model, :in_set, ids: matches + suggestions)
      if suggestions.any?
        flash_warning(:runtime_suggest_multiple_alternates.t(match: id,
                                                             type: type))
      else
        flash_warning(:runtime_object_multiple_matches.t(match: id,
                                                         type: type))
      end
      redirect_to(add_query_param({ controller: obj.show_controller,
                                    action: obj.index_action },
                                  query))
    end
  end

  def fix_name_matches(matches, accepted)
    matches.map do |name|
      if accepted && name.deprecated
        name.approved_synonyms.first
      else
        name.correct_spelling || name
      end
    end.reject(&:nil?)
  end

  # This is the action the search bar commits to.  It just redirects to one of
  # several "foreign" search actions:
  #   comment/image_search
  #   image/image_search
  #   location/location_search
  #   name/name_search
  #   observer/observation_search
  #   observer/user_search
  #   project/project_search
  #   species_list/species_list_search
  def pattern_search # :nologin: :norobots:
    pattern = param_lookup([:search, :pattern]) { |p| p.to_s.strip_squeeze }
    type = param_lookup([:search, :type], &:to_sym)

    # Save it so that we can keep it in the search bar in subsequent pages.
    session[:pattern] = pattern
    session[:search_type] = type

    case type
    when :observation, :user
      ctrlr = :observer
    when :comment, :herbarium, :image, :location,
      :name, :project, :species_list, :specimen
      ctrlr = type
    when :google
      if pattern.blank?
        redirect_to(action: :list_rss_logs)
      else
        search = URI.escape("site:#{MO.domain} #{pattern}")
        redirect_to("http://google.com?q=#{search}")
      end
      return
    else
      flash_error(:runtime_invalid.t(type: :search, value: type.inspect))
      redirect_back_or_default(action: :list_rss_logs)
      return
    end

    # If pattern is blank, this would devolve into a very expensive index.
    if pattern.blank?
      redirect_to(controller: ctrlr, action: "list_#{type}s")
    else
      redirect_to(controller: ctrlr, action: "#{type}_search",
                  pattern: pattern)
    end
  end

  # Advanced search form.  When it posts it just redirects to one of several
  # "foreign" search actions:
  #   image/advanced_search
  #   location/advanced_search
  #   name/advanced_search
  #   observer/advanced_search
  def advanced_search_form # :nologin: :norobots:
    return unless request.method == "POST"
    model = params[:search][:type].to_s.camelize.constantize


    # Pass along filled-in text field and search content filters with Query
    search = filled_in_text_fields
    if model == Observation
      search[:has_images] = params[:search][:has_images]
    end

    # Create query (this just validates the parameters).
    query = create_query(model, :advanced_search, search)

    # Let the individual controllers execute and render it.
    redirect_to(add_query_param({ controller: model.show_controller,
                                  action: "advanced_search" },
                                query))
  end

  def filled_in_text_fields
    result = {}
    [:content, :location, :name].each do |field|
      if (val = params[:search][field].to_s).present?
        result[field] = val
      end
    end
    # Treat User field differently; remove angle-bracketed user name,
    # since it was included by the auto-completer only as a hint.
    if (x = params[:search][:user].to_s).present?
      result[:user] = x.sub(/ <.*/, "")
    end
    result
  end

  # Displays matrix of selected Observation's (based on current Query).
  def index_observation # :nologin: :norobots:
    query = find_or_create_query(:Observation, by: params[:by])
    show_selected_observations(query, id: params[:id].to_s, always_index: true)
  end

  # Displays matrix of all Observation's, sorted by date.
  def list_observations # :nologin:
    query = create_query(:Observation, :all, by: :date)
    show_selected_observations(query)
  end

  # Displays matrix of all Observation's, alphabetically.
  def observations_by_name # :nologin: :norobots:
    query = create_query(:Observation, :all, by: :name)
    show_selected_observations(query)
  end

  # Displays matrix of Observations with the given text_name (or search_name).
  def observations_of_name # :nologin: :norobots:
    args = {
      name: params[:name],
      synonyms: :all,
      nonconsensus: :no,
      by: :created_at
    }
    args[:user] = params[:user_id] unless params[:user_id].blank?
    args[:project] = params[:project_id] unless params[:project_id].blank?

    unless params[:species_list_id].blank?
      args[:species_list] = params[:species_list_id]
    end

    query = create_query(:Observation, :of_name, args)
    show_selected_observations(query)
  end

  # Displays matrix of User's Observation's, by date.
  def observations_by_user # :nologin: :norobots:
    return unless user = find_or_goto_index(User, params[:id].to_s)
    query = create_query(:Observation, :by_user, user: user)
    show_selected_observations(query)
  end

  # Displays matrix of Observation's at a Location, by date.
  def observations_at_location # :nologin: :norobots:
    return unless (location = find_or_goto_index(Location, params[:id].to_s))
    query = create_query(:Observation, :at_location, location: location)
    show_selected_observations(query)
  end

  alias_method :show_location_observations, :observations_at_location

  # Display matrix of Observation's whose "where" matches a string.
  def observations_at_where # :nologin: :norobots:
    where = params[:where].to_s
    params[:location] = where
    query = create_query(:Observation, :at_where,
                         user_where: where,
                         location: Location.user_name(@user, where))
    show_selected_observations(query, always_index: 1)
  end

  # Display matrix of Observation's attached to a given project.
  def observations_for_project # :nologin: :norobots:
    return unless (project = find_or_goto_index(Project, params[:id].to_s))
    query = create_query(:Observation, :for_project, project: project)
    show_selected_observations(query, always_index: 1)
  end

  # Display matrix of Observation's whose notes, etc. match a string pattern.
  def observation_search # :nologin: :norobots:
    pattern = params[:pattern].to_s
    if pattern.match(/^\d+$/) &&
       (observation = Observation.safe_find(pattern))
      redirect_to(action: "show_observation", id: observation.id)
    else
      search = PatternSearch::Observation.new(pattern)
      if search.errors.any?
        search.errors.each do |error|
          flash_error(error.to_s)
        end
        render(action: :list_observations)
      else
        @suggest_alternate_spellings = search.query.params[:pattern]
        show_selected_observations(search.query)
      end
    end
  end

  # Displays matrix of advanced search results.
  def advanced_search # :nologin: :norobots:
    if params[:name] || params[:location] || params[:user] || params[:content]
      search = {}
      search[:name] = params[:name] unless params[:name].blank?
      search[:location] = params[:location] unless params[:location].blank?
      search[:user] = params[:user] unless params[:user].blank?
      search[:content] = params[:content] unless params[:content].blank?
      search[:search_location_notes] = !params[:search_location_notes].blank?
      query = create_query(:Observation, :advanced_search, search)
    else
      query = find_query(:Observation)
    end
    show_selected_observations(query)
  rescue => err
    flash_error(err.to_s) unless err.blank?
    redirect_to(controller: "observer", action: "advanced_search_form")
  end

  # Show selected search results as a matrix with "list_observations" template.
  def show_selected_observations(query, args = {})
    store_query_in_session(query)
    @links ||= []
    args = {
      action: "list_observations",
      matrix: true,
      include: [:name, :location, :user, :rss_log, { thumb_image: :image_votes }]
    }.merge(args)

    # Add some extra links to the index user is sent to if they click on an
    # undefined location.
    if query.flavor == :at_where
      @links += [[:list_observations_location_define.l,
                  { controller: "location",
                    action: "create_location",
                    where: query.params[:user_where] }],
                 [:list_observations_location_merge.l,
                  { controller: "location",
                    action: "list_merge_options",
                    where: query.params[:user_where] }],
                 [:list_observations_location_all.l,
                  { controller: "location",
                    action: "list_locations" }]]
    end

    # Add some alternate sorting criteria.
    links = [["name", :sort_by_name.t],
             ["date", :sort_by_date.t],
             ["user", :sort_by_user.t],
             ["created_at", :sort_by_posted.t],
             [(query.flavor == :by_rss_log ? "rss_log" : "updated_at"),
              :sort_by_updated_at.t],
             ["confidence", :sort_by_confidence.t],
             ["thumbnail_quality", :sort_by_thumbnail_quality.t],
             ["num_views", :sort_by_num_views.t]]
    args[:sorting_links] = links

    link = [:show_object.t(type: :map),
            add_query_param({ controller: "observer",
                              action: "map_observations" },
                            query)]
    @links << link

    # Add "show location" link if this query can be coerced into a
    # location query.
    if query.is_coercable?(:Location)
      @links << [:show_objects.t(type: :location),
                 add_query_param({ controller: "location",
                                   action: "index_location" },
                                 query)]
    end

    # Add "show names" link if this query can be coerced into a name query.
    if query.is_coercable?(:Name)
      @links << [:show_objects.t(type: :name),
                 add_query_param({ controller: "name", action: "index_name" },
                                 query)]
    end

    # Add "show images" link if this query can be coerced into an image query.
    if query.is_coercable?(:Image)
      @links << [:show_objects.t(type: :image),
                 add_query_param({ controller: "image",
                                   action: "index_image" },
                                 query)]
    end

    @links << [:list_observations_download_as_csv.t,
               add_query_param({ controller: "observer",
                                 action: "download_observations" },
                               query)]

    # Paginate by letter if sorting by user.
    if (query.params[:by] == "user") ||
       (query.params[:by] == "reverse_user")
      args[:letters] = "users.login"
    # Paginate by letter if names are included in query.
    elsif query.uses_table?(:names)
      args[:letters] = "names.sort_name"
    end

    # Restrict to subset within a geographical region (used by map
    # if it needed to stuff multiple locations into a single marker).
    query = restrict_query_to_box(query)

    show_index_of_objects(query, args)
  end

  # Map results of a search or index.
  def map_observations # :nologin: :norobots:
    @query = find_or_create_query(:Observation)
    @title = :map_locations_title.t(locations: @query.title)
    @query = restrict_query_to_box(@query)
    @timer_start = Time.now

    # Get matching observations.
    locations = {}
    columns = %w(id lat long location_id).map { |x| "observations.#{x}" }
    args = {
      select: columns.join(", "),
      where: "observations.lat IS NOT NULL OR " \
      "observations.location_id IS NOT NULL"
    }
    @observations = @query.select_rows(args).map do |id, lat, long, location_id|
      locations[location_id.to_i] = nil unless location_id.blank?
      MinimalMapObservation.new(id, lat, long, location_id)
    end

    if locations.length > 0
      # Eager-load corresponding locations.
      @locations = Location.connection.select_rows(%(
        SELECT id, name, north, south, east, west FROM locations
        WHERE id IN (#{locations.keys.sort.map(&:to_s).join(",")})
      )).map do |id, name, n, s, e, w|
        locations[id.to_i] = MinimalMapLocation.new(id, name, n, s, e, w)
      end
      @observations.each do |obs|
        obs.location = locations[obs.location_id] if obs.location_id
      end
    end
    @num_results = @observations.count
    @timer_end = Time.now
  end

  def download_observations # :nologin: :norobots:
    query = find_or_create_query(:Observation, by: params[:by])
    fail "no robots!" if browser.bot?
    set_query_params(query)
    @format = params[:format] || "raw"
    @encoding = params[:encoding] || "UTF-8"
    if params[:commit] == :CANCEL.l
      redirect_with_query(action: :index_observation, always_index: true)
    elsif params[:commit] == :DOWNLOAD.l
      report = create_observation_report(
        query: query,
        format: @format,
        encoding: @encoding
      )
      render_report(report)
      # serve form
    end
  rescue => e
    flash_error("Internal error: #{e}", *e.backtrace[0..10])
  end

  def create_observation_report(args)
    format = args[:format].to_s
    case format
    when "raw"
      ObservationReport::Raw.new(args)
    when "adolf"
      ObservationReport::Adolf.new(args)
    when "darwin"
      ObservationReport::Darwin.new(args)
    when "symbiota"
      ObservationReport::Symbiota.new(args)
    else
      fail("Invalid download type: #{format.inspect}")
    end
  end

  def render_report(report)
    send_data(report.body, {
      type: report.mime_type,
      charset: report.encoding,
      disposition: "attachment",
      filename: report.filename
    }.merge(report.header || {}))
  end

  ##############################################################################
  #
  #  :section: Show Observation
  #
  ##############################################################################

  # Display observation and related namings, comments, votes, images, etc.
  # This should be a redirection, not rendered, due to large number of
  # @variables that need to be set up for the view.  Lots of views are used:
  #   show_observation
  #   _show_observation
  #   _show_images
  #   _show_namings
  #   _show_comments
  #   _show_footer
  # Linked from countless views as a fall-back.
  # Inputs: params[:id]
  # Outputs:
  #   @observation
  #   @votes                        (user's vote for each naming.id)
  def show_observation # :nologin: :prefetch:
    pass_query_params
    store_location

    # Make it really easy for users to elect to go public with their votes.
    if params[:go_public] == "1"
      @user.votes_anonymous = :no
      @user.save
      flash_notice(:show_votes_gone_public.t)
    elsif params[:go_private] == "1"
      @user.votes_anonymous = :yes
      @user.save
      flash_notice(:show_votes_gone_private.t)
    end

    # Make it easy for users to change thumbnail size.
    unless params[:set_thumbnail_size].blank?
      set_default_thumbnail_size(params[:set_thumbnail_size])
    end

    @observation = find_or_goto_index(Observation, params[:id].to_s)
    return unless @observation
    update_view_stats(@observation)
    @canonical_url = "#{MO.http_domain}/observer/show_observation/#{@observation.id}"

    # Decide if the current query can be used to create a map.
    query = find_query(:Observation)
    @mappable = query && query.is_coercable?(:Location)

    # Provide a list of user's votes to view.
    if @user
      @votes = {}
      @observation.namings.each do |naming|
        vote = naming.votes.find { |x| x.user_id == @user.id }
        vote ||= Vote.new(value: 0)
        @votes[naming.id] = vote
      end
    end
  end

  def show_obs
    redirect_to(action: "show_observation", id: params[:id].to_s)
  end

  # Go to next observation: redirects to show_observation.
  def next_observation # :nologin: :norobots:
    redirect_to_next_object(:next, Observation, params[:id].to_s)
  end

  # Go to previous observation: redirects to show_observation.
  def prev_observation # :nologin: :norobots:
    redirect_to_next_object(:prev, Observation, params[:id].to_s)
  end

  ##############################################################################
  #
  #  :section: Create and Edit Observations
  #
  ##############################################################################

  # Form to create a new observation, naming, vote, and images.
  # Linked from: left panel
  #
  # Inputs:
  #   params[:observation][...]         observation args
  #   params[:name][:name]              name
  #   params[:approved_name]            old name
  #   params[:approved_where]           old place name
  #   params[:chosen_name][:name_id]    name radio boxes
  #   params[:vote][...]                vote args
  #   params[:reason][n][...]           naming_reason args
  #   params[:image][n][...]            image args
  #   params[:good_images]              images already downloaded
  #   params[:was_js_on]                was form javascripty? ("yes" = true)
  #
  # Outputs:
  #   @observation, @naming, @vote      empty objects
  #   @what, @names, @valid_names       name validation
  #   @reason                           array of naming_reasons
  #   @images                           array of images
  #   @licenses                         used for image license menu
  #   @new_image                        blank image object
  #   @good_images                      list of images already downloaded
  #
  def create_observation # :prefetch: :norobots:
    # These are needed to create pulldown menus in form.
    @licenses = License.current_names_and_ids(@user.license)
    @new_image = init_image(Time.now)

    # Clear search list. [Huh? -JPH 20120513]
    clear_query_in_session

    # Create empty instances first time through.
    if request.method != "POST"
      create_observation_get
    else
      create_observation_post(params)
    end
  end

  def create_observation_post(params)
    rough_cut(params)
    success = true
    success = false unless validate_name(params)
    success = false unless validate_place_name(params)
    success = false unless validate_object(@observation)
    success = false unless validate_specimen(params)
    success = false if @name && !validate_object(@naming)
    success = false if @name && !validate_object(@vote)
    success = false if @bad_images != []
    success = false if success && !save_observation(@observation)

    # Once observation is saved we can save everything else.
    if success
      save_everything_else(params[:reason]) # should always succeed
      flash_notice(:runtime_observation_success.t(id: @observation.id))
      @observation.log(:log_observation_created_at)
      redirect_to_next_page

    # If anything failed reload the form.
    else
      reload_the_form(params[:reason])
    end
  end

  def rough_cut(params)
    # Create everything roughly first.
    @observation = create_observation_object(params[:observation])
    @naming      = Naming.construct(params[:naming], @observation)
    @vote        = Vote.construct(params[:vote], @naming)
    @good_images = update_good_images(params[:good_images])
    @bad_images  = create_image_objects(params[:image],
                                        @observation, @good_images)
  end

  def validate_name(params)
    given_name = param_lookup([:name, :name], "").to_s
    chosen_name = param_lookup([:chosen_name, :name_id], "").to_s
    (success, @what, @name, @names, @valid_names, @parent_deprecated, @suggest_corrections) =
      Name.resolve_name(given_name, params[:approved_name], chosen_name)
    @naming.name = @name if @name
    success
  end

  def validate_place_name(params)
    success = true
    @place_name = @observation.place_name
    @dubious_where_reasons = []
    if @place_name != params[:approved_where] && @observation.location.nil?
      db_name = Location.user_name(@user, @place_name)
      @dubious_where_reasons = Location.dubious_name?(db_name, true)
      success = false if @dubious_where_reasons != []
    end
    success
  end

  def validate_specimen(params)
    success = true
    if params[:specimen]
      herbarium_name = params[:specimen][:herbarium_name]
      if herbarium_name
        herbarium_name = herbarium_name.strip_html
        herbarium = Herbarium.where(name: herbarium_name)[0]
        if herbarium
          herbarium_label = herbarium_label_from_params(params)
          success = herbarium.label_free?(herbarium_label)
          duplicate_error(herbarium_name, herbarium_label) unless success
        end
      end
    end
    success
  end

  def duplicate_error(name, label)
    err = :edit_herbarium_duplicate_label.t(herbarium_name: name,
                                            herbarium_label: label)
    flash_error(err)
  end

  def herbarium_label_from_params(params)
    Herbarium.default_specimen_label(params[:name][:name],
                                     params[:specimen][:herbarium_id])
  end

  def save_everything_else(reason)
    if @name
      @naming.create_reasons(reason, params[:was_js_on] == "yes")
      save_with_log(@naming)
      @observation.reload
      @observation.change_vote(@naming, @vote.value)
    end
    attach_good_images(@observation, @good_images)
    update_projects(@observation, params[:project])
    update_species_lists(@observation, params[:list])
    save_specimen(@observation, params)
  end

  def save_specimen(obs, params)
    return unless params[:specimen] && obs.specimen
    herbarium_name = params[:specimen][:herbarium_name]
    return unless herbarium_name && !herbarium_name.empty?
    if params[:specimen][:herbarium_id] == ""
      params[:specimen][:herbarium_id] = obs.id.to_s
    end
    herbarium_label = herbarium_label_from_params(params)
    herbarium = Herbarium.where(name: herbarium_name)[0]
    if herbarium.nil?
      herbarium = Herbarium.new(name: herbarium_name, email: @user.email)
      if herbarium_name == @user.personal_herbarium_name
        herbarium.personal_user = @user
      end
      herbarium.curators.push(@user)
      herbarium.save
    end
    specimen = Specimen.new(herbarium: herbarium,
                            herbarium_label: herbarium_label,
                            user: @user,
                            when: obs.when)
    specimen.save
    specimen.add_observation(obs)
  end

  def redirect_to_next_page
    if @observation.location.nil?
      redirect_to(controller: "location",
                  action: "create_location",
                  where: @observation.place_name,
                  set_observation: @observation.id)
    elsif has_unshown_notifications?(@user, :naming)
      redirect_to(action: "show_notifications", id: @observation.id)
    else
      redirect_to(action: "show_observation", id: @observation.id)
    end
  end

  def reload_the_form(reason)
    @reason          = @naming.init_reasons(reason)
    @images          = @bad_images
    @new_image.when  = @observation.when
    init_specimen_vars_for_reload
    init_project_vars_for_reload(@observation)
    init_list_vars_for_reload(@observation)
  end

  def create_observation_get
    @observation     = Observation.new
    @naming          = Naming.new
    @vote            = Vote.new
    @what            = "" # can't be nil else rails tries to call @name.name
    @names           = nil
    @valid_names     = nil
    @reason          = @naming.init_reasons
    @images          = []
    @good_images     = []
    init_specimen_vars_for_create
    init_project_vars_for_create
    init_list_vars_for_create
    defaults_from_last_observation_created
  end

  def defaults_from_last_observation_created
    # Grab defaults for date and location from last observation the user
    # edited if it was less than an hour ago.
    last_observation = Observation.where(user_id: @user.id).
                       order(:created_at).last
    return unless last_observation && last_observation.created_at > 1.hour.ago
    @observation.when     = last_observation.when
    @observation.where    = last_observation.where
    @observation.location = last_observation.location
    @observation.lat      = last_observation.lat
    @observation.long     = last_observation.long
    @observation.alt      = last_observation.alt
    last_observation.projects.each do |project|
      @project_checks[project.id] = true
    end
    last_observation.species_lists.each do |list|
      if check_permission(list)
        @lists << list unless @lists.include?(list)
        @list_checks[list.id] = true
      end
    end
  end

  # Form to edit an existing observation.
  # Linked from: left panel
  #
  # Inputs:
  #   params[:id]                       observation id
  #   params[:observation][...]         observation args
  #   params[:image][n][...]            image args
  #   params[:log_change][:checked]     log change in RSS feed?
  #
  # Outputs:
  #   @observation                      populated object
  #   @images                           array of images
  #   @licenses                         used for image license menu
  #   @new_image                        blank image object
  #   @good_images                      list of images already attached
  #
  def edit_observation # :prefetch: :norobots:
    pass_query_params
    includes = [:name, :images, :location]
    @observation = find_or_goto_index(Observation, params[:id].to_s)
    return unless @observation
    @licenses = License.current_names_and_ids(@user.license)
    @new_image = init_image(@observation.when)

    # Make sure user owns this observation!
    if !check_permission!(@observation)
      redirect_with_query(action: "show_observation",
                          id: @observation.id)

      # Initialize form.
    elsif request.method != "POST"
      @images      = []
      @good_images = @observation.images
      init_project_vars_for_edit(@observation)
      init_list_vars_for_edit(@observation)

    else
      any_errors = false

      update_whitelisted_observation_attributes

      # Validate place name
      @place_name = @observation.place_name
      @dubious_where_reasons = []
      if @place_name != params[:approved_where] && @observation.location.nil?
        db_name = Location.user_name(@user, @place_name)
        @dubious_where_reasons = Location.dubious_name?(db_name, true)
        any_errors = true if @dubious_where_reasons.any?
      end

      # Now try to upload images.
      @good_images = update_good_images(params[:good_images])
      @bad_images  = create_image_objects(params[:image],
                                          @observation, @good_images)
      attach_good_images(@observation, @good_images)
      any_errors = true if @bad_images.any?

      # Only save observation if there are changes.
      if @dubious_where_reasons == []
        if @observation.changed?
          @observation.updated_at = Time.now
          if save_observation(@observation)
            id = @observation.id
            flash_notice(:runtime_edit_observation_success.t(id: id))
            touch = (param_lookup([:log_change, :checked]) == "1")
            @observation.log(:log_observation_updated, touch: touch)
          else
            any_errors = true
          end
        end
      end

      # Update project and species_list attachments.
      update_projects(@observation, params[:project])
      update_species_lists(@observation, params[:list])

      # Reload form if anything failed.
      if any_errors
        @images         = @bad_images
        @new_image.when = @observation.when
        init_project_vars_for_reload(@observation)
        init_list_vars_for_reload(@observation)

        # Redirect to show_observation or create_location on success.
      elsif @observation.location.nil?
        redirect_with_query(controller: "location",
                            action: "create_location",
                            where: @observation.place_name,
                            set_observation: @observation.id)
      else
        redirect_with_query(action: "show_observation",
                            id: @observation.id)
      end
    end
  end

  def update_whitelisted_observation_attributes
    @observation.attributes = whitelisted_observation_params || {}
  end

  # Callback to destroy an observation (and associated namings, votes, etc.)
  # Linked from: show_observation
  # Inputs: params[:id] (observation)
  # Redirects to list_observations.
  def destroy_observation # :norobots:
    param_id = params[:id].to_s
    return unless (@observation = find_or_goto_index(Observation, param_id))
    obs_id = @observation.id
    next_state = nil
    # decide where to redirect after deleting observation
    if (this_state = find_query(:Observation))
      this_state.current = @observation
      next_state = this_state.next
    end
    if !check_permission!(@observation)
      flash_error(:runtime_destroy_observation_denied.t(id: obs_id))
      redirect_to(add_query_param({ action: "show_observation", id: obs_id },
                                  this_state))
    elsif !@observation.destroy
      flash_error(:runtime_destroy_observation_failed.t(id: obs_id))
      redirect_to(add_query_param({ action: "show_observation", id: obs_id },
                                  this_state))
    else
      flash_notice(:runtime_destroy_observation_success.t(id: param_id))
      if next_state
        redirect_to(add_query_param({ action: "show_observation",
                                      id: next_state.current_id },
                                    next_state))
      else
        redirect_to(action: "list_observations")
      end
    end
  end

  # I'm tired of tweaking show_observation to call calc_consensus for
  # debugging.  I'll just leave this stupid action in and have it
  # forward to show_observation.
  def recalc # :root: :norobots:
    pass_query_params
    id = params[:id].to_s
    begin
      @observation = Observation.find(id)
      display_name = @observation.name.display_name
      flash_notice(:observer_recalc_old_name.t(name: display_name))
      text = @observation.calc_consensus(true)
      flash_notice text unless text.blank?
      flash_notice(:observer_recalc_new_name.t(name: display_name))
    rescue => err
      flash_error(:observer_recalc_caught_error.t(error: err))
    end
    # render(text: "", layout: true)
    redirect_with_query(action: "show_observation", id: id)
  end

  ##############################################################################
  #
  #  :section: Reviewer Utilities
  #
  ##############################################################################

  # Form to compose email for the authors/reviewers.  Linked from show_<object>.
  # TODO: Use queued_email mechanism.
  def author_request # :norobots:
    pass_query_params
    @object = AbstractModel.find_object(params[:type], params[:id].to_s)
    return unless request.method == "POST"
    subject = param_lookup([:email, :subject], "")
    content = param_lookup([:email, :content], "")
    (@object.authors + UserGroup.reviewers.users).uniq.each do |receiver|
      AuthorEmail.build(@user, receiver, @object, subject, content).deliver_now
    end
    flash_notice(:request_success.t)
    redirect_with_query(controller: @object.show_controller,
                        action: @object.show_action, id: @object.id)
  end

  # Form to adjust permissions for a user with respect to a project.
  # Linked from: show_(object) and author_request email
  # Inputs:
  #   params[:id]
  #   params[:type]
  #   params[:add]
  #   params[:remove]
  # Success:
  #   Redraws itself.
  # Failure:
  #   Renders show_name.
  #   Outputs: @name, @authors, @users
  def review_authors # :norobots:
    pass_query_params
    @object = AbstractModel.find_object(params[:type], params[:id].to_s)
    @authors = @object.authors
    parent = @object.parent
    if @authors.member?(@user) || @user.in_group?("reviewers")
      @users = User.all.order("login, name").to_a
      new_author = params[:add] ? User.find(params[:add]) : nil
      if new_author && !@authors.member?(new_author)
        @object.add_author(new_author)
        flash_notice("Added #{new_author.legal_name}")
        # Should send email as well
      end
      old_author = params[:remove] ? User.find(params[:remove]) : nil
      if old_author && @authors.member?(old_author)
        @object.remove_author(old_author)
        flash_notice("Removed #{old_author.legal_name}")
        # Should send email as well
      end
    else
      flash_error(:review_authors_denied.t)
      redirect_with_query(controller: parent.show_controller,
                          action: parent.show_action, id: parent.id)
    end
  end

  # Callback to let reviewers change the export status of a Name from the
  # show_name page.
  def set_export_status # :norobots:
    pass_query_params
    id    = params[:id].to_s
    type  = params[:type].to_s
    value = params[:value].to_s
    model_class = type.camelize.safe_constantize
    if !is_reviewer?
      flash_error(:runtime_admin_only.t)
      redirect_back_or_default("/")
    elsif !model_class ||
          !model_class.respond_to?(:column_names) ||
          !model_class.column_names.include?("ok_for_export")
      flash_error(:runtime_invalid.t(type: '"type"', value: type))
      redirect_back_or_default("/")
    elsif !value.match(/^[01]$/)
      flash_error(:runtime_invalid.t(type: '"value"', value: value))
      redirect_back_or_default("/")
    elsif (obj = find_or_goto_index(model_class, id))
      obj.ok_for_export = (value == "1")
      obj.save_without_our_callbacks
      if params[:return]
        redirect_back_or_default("/")
      else
        controller = params[:return_controller] || obj.show_controller
        action = params[:return_action] || obj.show_action
        redirect_with_query(controller: controller,
                            action: action, id: id)
      end
    end
  end

  ##############################################################################
  #
  #  :section: Notifications
  #
  ##############################################################################

  # Displays notifications related to a given naming and users.
  # Inputs: params[:naming], params[:observation]
  # Outputs:
  #   @notifications
  def show_notifications # :norobots:
    pass_query_params
    data = []
    @observation = find_or_goto_index(Observation, params[:id].to_s)
    return unless @observation
    name_tracking_emails(@user.id).each do |q|
      fields = [:naming, :notification, :shown]
      naming_id, notification_id, shown = q.get_integers(fields)
      next unless shown.nil?
      notification = Notification.find(notification_id)
      if notification.note_template
        data.push([notification, Naming.find(naming_id)])
      end
      q.add_integer(:shown, 1)
    end
    @data = data.sort_by { rand }
  end

  def name_tracking_emails(user_id)
    QueuedEmail.where(flavor: "QueuedEmail::NameTracking", to_user_id: user_id)
  end

  # Lists notifications that the given user has created.
  # Inputs: none
  # Outputs:
  #   @notifications
  def list_notifications # :norobots:
    # @notifications = Notification.find_all_by_user_id(@user.id, order: :flavor)
    @notifications = Notification.where(user_id: @user.id).order(:flavor)
  end

  ##############################################################################
  #
  #  :section: User support
  #
  ##############################################################################

  # User index, restricted to admins.
  def index_user # :nologin: :norobots:
    if is_in_admin_mode? || find_query(:User)
      query = find_or_create_query(:User, by: params[:by])
      show_selected_users(query, id: params[:id].to_s, always_index: true)
    else
      flash_error(:runtime_search_has_expired.t)
      redirect_to(action: "list_rss_logs")
    end
  end

  # People guess this page name frequently for whatever reason, and
  # since there is a view with this name, it crashes each time.
  alias_method :list_users, :index_user

  # User index, restricted to admins.
  def users_by_name # :norobots:
    if is_in_admin_mode?
      query = create_query(:User, :all, by: :name)
      show_selected_users(query)
    else
      flash_error(:permission_denied.t)
      redirect_to(action: "list_rss_logs")
    end
  end

  # Display list of User's whose name, notes, etc. match a string pattern.
  def user_search # :nologin: :norobots:
    pattern = params[:pattern].to_s
    if pattern.match(/^\d+$/) &&
       (user = User.safe_find(pattern))
      redirect_to(action: "show_user", id: user.id)
    else
      query = create_query(:User, :pattern_search, pattern: pattern)
      show_selected_users(query)
    end
  end

  def show_selected_users(query, args = {})
    store_query_in_session(query)
    @links ||= []
    args = {
      action: "list_users",
      include: :user_groups,
      matrix: !is_in_admin_mode?
    }.merge(args)

    # Add some alternate sorting criteria.
    if is_in_admin_mode?
      args[:sorting_links] = [
        ["id",          :sort_by_id.t],
        ["login",       :sort_by_login.t],
        ["name",        :sort_by_name.t],
        ["created_at",  :sort_by_created_at.t],
        ["updated_at",  :sort_by_updated_at.t],
        ["last_login",  :sort_by_last_login.t]
      ]
    else
      args[:sorting_links] = [
        ["login",         :sort_by_login.t],
        ["name",          :sort_by_name.t],
        ["created_at",    :sort_by_created_at.t],
        ["location",      :sort_by_location.t],
        ["contribution",  :sort_by_contribution.t]
      ]
    end

    # Paginate by "correct" letter.
    if (query.params[:by] == "login") ||
       (query.params[:by] == "reverse_login")
      args[:letters] = "users.login"
    else
      args[:letters] = "users.name"
    end

    show_index_of_objects(query, args)
  end

  # users_by_contribution.rhtml
  def users_by_contribution # :nologin: :norobots:
    SiteData.new
    @users = User.order("contribution desc, name, login")
  end

  # show_user.rhtml
  def show_user # :nologin: :prefetch:
    store_location
    id = params[:id].to_s
    @show_user = find_or_goto_index(User, id)
    return unless @show_user
    @user_data = SiteData.new.get_user_data(id)
    @life_list = Checklist::ForUser.new(@show_user)
    @query = Query.lookup(:Observation, :by_user,
                          user: @show_user, by: :owners_thumbnail_quality)
    @observations = @query.results(limit: 6)
    return unless @observations.length < 6
    @query = Query.lookup(:Observation, :by_user,
                          user: @show_user, by: :thumbnail_quality)
    @observations = @query.results(limit: 6)
  end

  # Go to next user: redirects to show_user.
  def next_user # :norobots:
    redirect_to_next_object(:next, User, params[:id].to_s)
  end

  # Go to previous user: redirects to show_user.
  def prev_user # :norobots:
    redirect_to_next_object(:prev, User, params[:id].to_s)
  end

  # Display a checklist of species seen by a User, Project,
  # SpeciesList or the entire site.
  def checklist # :nologin: :norobots:
    store_location
    user_id = params[:user_id] || params[:id]
    proj_id = params[:project_id]
    list_id = params[:species_list_id]
    if !user_id.blank?
      if (@show_user = find_or_goto_index(User, user_id))
        @data = Checklist::ForUser.new(@show_user)
      end
    elsif !proj_id.blank?
      if (@project = find_or_goto_index(Project, proj_id))
        @data = Checklist::ForProject.new(@project)
      end
    elsif !list_id.blank?
      if (@species_list = find_or_goto_index(SpeciesList, list_id))
        @data = Checklist::ForSpeciesList.new(@species_list)
      end
    else
      @data = Checklist::ForSite.new
    end
  end

  # Admin util linked from show_user page that lets admin add or change bonuses
  # for a given user.
  def change_user_bonuses # :root: :norobots:
    return unless (@user2 = find_or_goto_index(User, params[:id].to_s))
    if is_in_admin_mode?
      if request.method != "POST"
        # Reformat bonuses as string for editing, one entry per line.
        @val = ""
        if @user2.bonuses
          vals = @user2.bonuses.map do |points, reason|
            sprintf("%-6d %s", points, reason.gsub(/\s+/, " "))
          end
          @val = vals.join("\n")
        end
      else
        # Parse new set of values.
        @val = params[:val]
        line_num = 0
        errors = false
        bonuses = []
        @val.split("\n").each do |line|
          line_num += 1
          if (match = line.match(/^\s*(\d+)\s*(\S.*\S)\s*$/))
            bonuses.push([match[1].to_i, match[2].to_s])
          else
            flash_error("Syntax error on line #{line_num}.")
            errors = true
          end
        end
        # Success: update user's contribution.
        unless errors
          contrib = @user2.contribution.to_i
          # Subtract old bonuses.
          if @user2.bonuses
            @user2.bonuses.each do |points, _reason|
              contrib -= points
            end
          end
          # Add new bonuses
          bonuses.each do |points, _reason|
            contrib += points
          end
          # Update database.
          @user2.bonuses      = bonuses
          @user2.contribution = contrib
          @user2.save
          redirect_to(action: "show_user", id: @user2.id)
        end
      end
    else
      redirect_to(action: "show_user", id: @user2.id)
    end
  end

  ##############################################################################
  #
  #  :section: Site Stats
  #
  ##############################################################################

  # show_site_stats.rhtml
  def show_site_stats # :nologin: :norobots:
    store_location
    @site_data = SiteData.new.get_site_data

    # Add some extra stats.
    @site_data[:observed_taxa] = Name.connection.select_value %(
      SELECT COUNT(DISTINCT name_id) FROM observations
    )
    @site_data[:listed_taxa] = Name.connection.select_value %(
      SELECT COUNT(*) FROM names
    )

    # Get the last six observations whose thumbnails are highly rated.
    query = Query.lookup(:Observation, :all,
                         by: :updated_at,
                         where: "images.vote_cache >= 3",
                         join: :"images.thumb_image")
    @observations = query.results(limit: 6,
                                  include: { thumb_image: :image_votes })
  end

  # server_status.rhtml
  # Restricted to the admin user
  # Reports on the health of the system
  def server_status # :root: :norobots:
    if is_in_admin_mode?
      case params[:commit]
      when :system_status_gc.l
        ObjectSpace.garbage_collect
        flash_notice("Collected garbage")
      when :system_status_clear_caches.l
        String.clear_textile_cache
        flash_notice("Cleared caches")
      end
      @textile_name_size = String.textile_name_size
    else
      redirect_to(action: "list_observations")
    end
  end

  ##############################################################################
  #
  #  :section: Email Stuff
  #
  ##############################################################################

  # email_features.rhtml
  # Restricted to the admin user
  def email_features # :root: :norobots:
    if is_in_admin_mode?
      @users = User.where("email_general_feature=1 && verified is not null")
      if request.method == "POST"
        @users.each do |user|
          QueuedEmail::Feature.create_email(user,
                                            params[:feature_email][:content])
        end
        flash_notice(:send_feature_email_success.t)
        redirect_to(action: "users_by_name")
      end
    else
      flash_error(:permission_denied.t)
      redirect_to(action: "list_rss_logs")
    end
  end

  def ask_webmaster_question # :nologin: :norobots:
    @email = params[:user][:email] if params[:user]
    @content = params[:question][:content] if params[:question]
    @email_error = false
    if request.method != "POST"
      @email = @user.email if @user
    elsif @email.blank? || @email.index("@").nil?
      flash_error(:runtime_ask_webmaster_need_address.t)
      @email_error = true
    elsif /http:/ =~ @content || /<[\/a-zA-Z]+>/ =~ @content
      flash_error(:runtime_ask_webmaster_antispam.t)
    elsif @content.blank?
      flash_error(:runtime_ask_webmaster_need_content.t)
    else
      WebmasterEmail.build(@email, @content).deliver_now
      flash_notice(:runtime_ask_webmaster_success.t)
      redirect_to(action: "list_rss_logs")
    end
  end

  def ask_user_question # :norobots:
    return unless (@target = find_or_goto_index(User, params[:id].to_s)) &&
                  email_question(@user) &&
                  request.method == "POST"
    subject = params[:email][:subject]
    content = params[:email][:content]
    UserEmail.build(@user, @target, subject, content).deliver_now
    flash_notice(:runtime_ask_user_question_success.t)
    redirect_to(action: "show_user", id: @target.id)
  end

  def ask_observation_question # :norobots:
    @observation = find_or_goto_index(Observation, params[:id].to_s)
    return unless @observation &&
                  email_question(@observation) &&
                  request.method == "POST"
    question = params[:question][:content]
    ObservationEmail.build(@user, @observation, question).deliver_now
    flash_notice(:runtime_ask_observation_question_success.t)
    redirect_with_query(action: "show_observation", id: @observation.id)
  end

  def commercial_inquiry # :norobots:
    return unless (@image = find_or_goto_index(Image, params[:id].to_s)) &&
                  email_question(@image, :email_general_commercial) &&
                  request.method == "POST"
    commercial_inquiry = params[:commercial_inquiry][:content]
    CommercialEmail.build(@user, @image, commercial_inquiry).deliver_now
    flash_notice(:runtime_commercial_inquiry_success.t)
    redirect_with_query(controller: "image", action: "show_image",
                        id: @image.id)
  end

  def email_question(target, method = :email_general_question)
    result = false
    user = target.is_a?(User) ? target : target.user
    if user.send(method)
      result = true
    else
      flash_error(:permission_denied.t)
      redirect_with_query(controller: target.show_controller,
                          action: target.show_action, id: target.id)
    end
    result
  end

  ##############################################################################
  #
  #  :section: RSS support
  #
  ##############################################################################

  # Displays matrix of selected RssLog's (based on current Query).
  def index_rss_log # :nologin: :norobots:
    if request.method == "POST"
      types = RssLog.all_types.select { |type| params["show_#{type}"] == "1" }
      types = "all" if types.length == RssLog.all_types.length
      types = "none" if types.empty?
      types = types.map(&:to_s).join(" ") if types.is_a?(Array)
      query = find_or_create_query(:RssLog, type: types)
    elsif !params[:type].blank?
      types = params[:type].split & (["all"] + RssLog.all_types)
      query = find_or_create_query(:RssLog, type: types.join(" "))
    else
      query = find_query(:RssLog)
      query ||= create_query(:RssLog, :all,
                             type: @user ? @user.default_rss_type : "all")
    end
    show_selected_rss_logs(query, id: params[:id].to_s, always_index: true)
  end

  # This is the main site index.  Nice how it's buried way down here, huh?
  def list_rss_logs # :nologin:
    query = create_query(:RssLog, :all,
                         type: @user ? @user.default_rss_type : "all")
    show_selected_rss_logs(query)
  end

  # Show selected search results as a matrix with "list_rss_logs" template.
  def show_selected_rss_logs(query, args = {})
    store_query_in_session(query)
    set_query_params(query)

    args = {
      action: "list_rss_logs",
      matrix: true,
      include: {
        location: :user,
        name: :user,
        observation: [:location, :name, { thumb_image: :image_votes }, :user],
        project: :user,
        species_list: [:location, :user]
      }
    }.merge(args)

    @types = query.params[:type].to_s.split.sort
    @links = []

    # Let the user make this their default and fine tune.
    if @user
      if params[:make_default] == "1"
        @user.default_rss_type = @types.join(" ")
        @user.save_without_our_callbacks
      elsif @user.default_rss_type.to_s.split.sort != @types
        @links << [:rss_make_default.t,
                   add_query_param(action: "index_rss_log", make_default: 1)]
      end
    end

    show_index_of_objects(query, args)
  end

  # Show a single RssLog.
  def show_rss_log # :nologin:
    pass_query_params
    store_location
    @rss_log = find_or_goto_index(RssLog, params["id"])
  end

  # Go to next RssLog: redirects to show_<object>.
  def next_rss_log # :norobots:
    redirect_to_next_object(:next, RssLog, params[:id].to_s)
  end

  # Go to previous RssLog: redirects to show_<object>.
  def prev_rss_log # :norobots:
    redirect_to_next_object(:prev, RssLog, params[:id].to_s)
  end

  # this is the site's rss feed.
  def rss # :nologin:
    @logs = RssLog.includes(:name, :species_list, observation: :name).
            where("datediff(now(), updated_at) <= 31").
            order(updated_at: :desc).
            limit(100)

    render_xml(layout: false)
  end

  ##############################################################################
  #
  #  :section: create and edit helpers
  #
  #    create_observation_object(...)     create rough first-drafts.
  #
  #    save_observation(...)              Save validated objects.
  #
  #    update_observation_object(...)     Update and save existing objects.
  #
  #    init_image()                       Handle image uploads.
  #    create_image_objects(...)
  #    update_good_images(...)
  #    attach_good_images(...)
  #
  ##############################################################################

  # Roughly create observation object.  Will validate and save later
  # once we're sure everything is correct.
  # INPUT: params[:observation] (and @user)
  # OUTPUT: new observation
  def create_observation_object(args)
    now = Time.now
    if args
      observation = Observation.new(args.permit(whitelisted_observation_args))
    else
      observation = Observation.new
    end
    observation.created_at = now
    observation.updated_at = now
    observation.user = @user
    observation.name = Name.unknown
    if Location.is_unknown?(observation.place_name) ||
       (observation.lat && observation.long && observation.place_name.blank?)
      observation.location = Location.unknown
      observation.where = nil
    end
    observation
  end

  def init_specimen_vars_for_create
    @herbarium_name = @user.preferred_herbarium_name
    @herbarium_id = ""
  end

  def init_specimen_vars_for_reload
    @herbarium_name, @herbarium_id =
      if (specimen = params[:specimen])
        [specimen[:herbarium_name], specimen[:herbarium_id]]
      else
        [@user.preferred_herbarium_name, ""]
      end
  end

  def init_project_vars
    @projects = User.current.projects_member.sort_by(&:title)
    @project_checks = {}
  end

  def init_project_vars_for_create
    init_project_vars
  end

  def init_project_vars_for_edit(obs)
    init_project_vars
    obs.projects.each do |proj|
      @projects << proj unless @projects.include?(proj)
      @project_checks[proj.id] = true
    end
  end

  def init_project_vars_for_reload(obs)
    init_project_vars
    obs.projects.each do |proj|
      @projects << proj unless @projects.include?(proj)
    end
    @projects.each do |proj|
      p = params[:project]
      @project_checks[proj.id] = p.nil? ? false : p["id_#{proj.id}"] == "1"
    end
  end

  def init_list_vars
    @lists = User.current.all_editable_species_lists.sort_by(&:title)
    @list_checks = {}
  end

  def init_list_vars_for_create
    init_list_vars
  end

  def init_list_vars_for_edit(obs)
    init_list_vars
    obs.species_lists.each do |list|
      @lists << list unless @lists.include?(list)
      @list_checks[list.id] = true
    end
  end

  def init_list_vars_for_reload(obs)
    init_list_vars
    obs.species_lists.each do |list|
      @lists << list unless @lists.include?(list)
    end
    @lists.each do |list|
      @list_checks[list.id] = param_lookup([:list, "id_#{list.id}"]) == "1"
    end
  end

  def update_projects(obs, checks)
    return unless checks
    User.current.projects_member.each do |project|
      before = obs.projects.include?(project)
      after = checks["id_#{project.id}"] == "1"
      next unless before != after
      if after
        project.add_observation(obs)
        flash_notice(:attached_to_project.t(object: :observation,
                                            project: project.title))
      else
        project.remove_observation(obs)
        flash_notice(:removed_from_project.t(object: :observation,
                                             project: project.title))
      end
    end
  end

  def update_species_lists(obs, checks)
    return unless checks
    User.current.all_editable_species_lists.each do |list|
      before = obs.species_lists.include?(list)
      after = checks["id_#{list.id}"] == "1"
      next unless before != after
      if after
        list.add_observation(obs)
        flash_notice(:added_to_list.t(list: list.title))
      else
        list.remove_observation(obs)
        flash_notice(:removed_from_list.t(list: list.title))
      end
    end
  end

  # Save observation now that everything is created successfully.
  def save_observation(observation)
    return true if observation.save
    flash_error(:runtime_no_save_observation.t)
    flash_object_errors(observation)
    false
  end

  # Update observation, check if valid.
  def update_observation_object(observation, args)
    success = true
    unless observation.update(args.permit(observation_whitelisted_args))
      flash_object_errors(observation)
      success = false
    end
    success
  end

  # Attempt to upload any images.  We will attach them to the observation
  # later, assuming we can create it.  Problem is if anything goes wrong, we
  # cannot repopulate the image forms (security issue associated with giving
  # file upload fields default values).  So we need to do this immediately,
  # even if observation creation fails.  Keep a list of images we've downloaded
  # successfully in @good_images (stored in hidden form field).
  #
  # INPUT: params[:image], observation, good_images (and @user)
  # OUTPUT: list of images we couldn't create
  def create_image_objects(args, observation, good_images)
    bad_images = []
    if args
      i = 0
      while (args2 = args[i.to_s])
        unless (upload = args2[:image]).blank?
          if upload.respond_to?(:original_filename)
            name = upload.original_filename.force_encoding("utf-8")
          end
          # image = Image.new(args2) # Rails 3.2
          image = Image.new(args2.permit(whitelisted_image_args))
          # image = Image.new(args2.permit(:all))
          image.created_at = Time.now
          image.updated_at = image.created_at
          # If image.when is 1950 it means user never saw the form
          # field, so we should use default instead.
          image.when = observation.when if image.when.year == 1950
          image.user = @user
          if !image.save
            bad_images.push(image)
            flash_object_errors(image)
          elsif !image.process_image
            logger.error("Unable to upload image")
            name_str = name ? "'#{name}'" : "##{image.id}"
            flash_notice(:runtime_no_upload_image.t(name: name_str))
            bad_images.push(image)
            flash_object_errors(image)
          else
            name = image.original_name
            name = "##{image.id}" if name.empty?
            flash_notice(:runtime_image_uploaded.t(name: name))
            good_images.push(image)
            if observation.thumb_image_id == -i
              observation.thumb_image_id = image.id
            end
          end
        end
        i += 1
      end
    end
    if observation.thumb_image_id && observation.thumb_image_id.to_i <= 0
      observation.thumb_image_id = nil
    end
    bad_images
  end

  # List of images that we've successfully downloaded, but which
  # haven't been attached to the observation yet.  Also supports some
  # mininal editing.  INPUT: params[:good_images] (also looks at
  # params[:image_<id>_notes]) OUTPUT: list of images
  def update_good_images(arg)
    # Get list of images first.
    images = (arg || "").split(" ").map do |id|
      Image.safe_find(id.to_i)
    end.reject(&:nil?)

    # Now check for edits.
    images.each do |image|
      next unless check_permission(image)
      args = param_lookup([:good_image, image.id.to_s])
      next unless args
      image.attributes = args.permit(whitelisted_image_args)
      next unless image.when_changed? ||
                  image.notes_changed? ||
                  image.copyright_holder_changed? ||
                  image.license_id_changed? ||
                  image.original_name_changed?
      image.updated_at = Time.now
      if image.save
        flash_notice(:runtime_image_updated_notes.t(id: image.id))
      else
        flash_object_errors(image)
      end
    end

    images
  end

  # Now that the observation has been successfully created, we can attach
  # any images that were downloaded earlier
  def attach_good_images(observation, images)
    return unless images
    images.each do |image|
      unless observation.image_ids.include?(image.id)
        observation.add_image(image)
        observation.log_create_image(image)
      end
    end
  end

  # Initialize image for the dynamic image form at the bottom.
  def init_image(default_date)
    image = Image.new
    image.when             = default_date
    image.license          = @user.license
    image.copyright_holder = @user.legal_name
    image
  end

  def hide_thumbnail_map # :nologin:
    pass_query_params
    id = params[:id].to_s
    if @user
      @user.update_attribute(:thumbnail_maps, false)
      flash_notice(:show_observation_thumbnail_map_hidden.t)
    else
      session[:hide_thumbnail_maps] = true
    end
    redirect_with_query(action: :show_observation, id: id)
  end

  ##############################################################################
  #
  #  :stopdoc: These are for backwards compatibility.
  #
  ##############################################################################

  def rewrite_url(obj, new_method)
    url = request.fullpath
    if url.match(/\?/)
      base = url.sub(/\?.*/, "")
      args = url.sub(/^[^?]*/, "")
    elsif url.match(/\/\d+$/)
      base = url.sub(/\/\d+$/, "")
      args = url.sub(/.*(\/\d+)$/, "\1")
    else
      base = url
      args = ""
    end
    base.sub!(%r{/\w+/\w+$}, "")
    "#{base}/#{obj}/#{new_method}#{args}"
  end

  # Create redirection methods for all of the actions we've moved out
  # of this controller.  They just rewrite the URL, replacing the
  # controller with the new one (and optionally renaming the action).
  def self.action_has_moved(obj, old_method, new_method = nil)
    new_method = old_method unless new_method
    class_eval(<<-EOS)
      def #{old_method}
        redirect_to rewrite_url("#{obj}", "#{new_method}")
      end
    EOS
  end

  action_has_moved "comment", "add_comment"
  action_has_moved "comment", "destroy_comment"
  action_has_moved "comment", "edit_comment"
  action_has_moved "comment", "list_comments"
  action_has_moved "comment", "show_comment"
  action_has_moved "comment", "show_comments_for_user"

  action_has_moved "image", "add_image"
  action_has_moved "image", "destroy_image"
  action_has_moved "image", "edit_image"
  action_has_moved "image", "license_updater"
  action_has_moved "image", "list_images"
  action_has_moved "image", "next_image"
  action_has_moved "image", "prev_image"
  action_has_moved "image", "remove_images"
  action_has_moved "image", "reuse_image"
  action_has_moved "image", "show_image"

  action_has_moved "name", "approve_name"
  action_has_moved "name", "bulk_name_edit"
  action_has_moved "name", "change_synonyms"
  action_has_moved "name", "deprecate_name"
  action_has_moved "name", "edit_name"
  action_has_moved "name", "map"
  action_has_moved "name", "observation_index"
  action_has_moved "name", "show_name"
  action_has_moved "name", "show_past_name"

  action_has_moved "observer", "show_user_observations", "observations_by_user"

  action_has_moved "species_list", "add_observation_to_species_list"
  action_has_moved "species_list", "create_species_list"
  action_has_moved "species_list", "destroy_species_list"
  action_has_moved "species_list", "edit_species_list"
  action_has_moved "species_list", "list_species_lists"
  action_has_moved "species_list", "manage_species_lists"
  action_has_moved "species_list", "remove_observation_from_species_list"
  action_has_moved "species_list", "show_species_list"
  action_has_moved "species_list", "species_lists_by_title"
  action_has_moved "species_list", "upload_species_list"

  ##############################################################################

  private

  def whitelisted_observation_args
    [:place_name, :where, :lat, :long, :alt, :when, "when(1i)", "when(2i)",
     "when(3i)", :notes, :specimen, :thumb_image_id, :is_collection_location]
  end

  def whitelisted_observation_params
    return unless params[:observation]
    params[:observation].permit(whitelisted_observation_args)
  end
end
