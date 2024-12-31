# frozen_string_literal: true

##############################################################################
#
#  :section: Indexes
#
##############################################################################
# see application_controller.rb
# rubocop:disable Metrics/ModuleLength
module ApplicationController::Indexes
  def self.included(base)
    base.helper_method(:paginate_numbers)
  end

  # Get args from a param subaction, or if none given, the unfiltered_index.
  def build_index_with_query
    we_need_to_bail, we_have_a_query, query_args, display_opts =
      try_building_query_args_from_params

    return if we_need_to_bail
    return filtered_index(query_args, display_opts) if we_have_a_query

    # Otherwise, display the unfiltered index.
    new_query_args, display_opts = unfiltered_index
    return unless new_query_args

    filtered_index(new_query_args, display_opts)
  end

  def try_building_query_args_from_params
    all_query_args = {}
    all_display_opts = {}
    we_have_a_query = false
    we_need_to_bail = false

    index_active_params.each do |subaction|
      next if params[subaction].blank?

      query_args, display_opts = send(index_param_method_or_default(subaction))
      # Some actions may redirect instead of returning a query, such as pattern
      # searches that resolve to a single object or get no results.
      # So if we had the param, but got a blank query, we should bail to allow
      # the redirect without rendering a blank index.
      if query_args.blank?
        we_need_to_bail = true
        break
      end

      # NOTE: we are merging, which may overwrite some keys.
      all_query_args = all_query_args.merge(query_args)
      all_display_opts = all_display_opts.merge(display_opts)
      # Mark that we have enough for a query.
      we_have_a_query = true
    end

    [we_need_to_bail, we_have_a_query, all_query_args, all_display_opts]
  end

  # It's not always the controller_name, e.g. ContributorsController -> User
  def controller_model_name
    controller_name.classify
  end

  # Currently some controller tests expect nil: Even though the sort order
  # resulting from `nil` is the default, passing no explicit :by param
  # means the index is titled "____ Index", rather than "____ by ____".
  # NOTE: Could be standardized.
  def default_sort_order
    # query_base = "::Query::#{controller_model_name.pluralize}".constantize
    # query_base.send(:default_order) || nil
    nil
  end

  # Provide defaults for the params an index can handle.
  INDEX_BASIC_PARAMS = [:by, :q, :id].freeze

  # Overrides should include any of the above basics, if relevant.
  def index_active_params
    ApplicationController::Indexes::INDEX_BASIC_PARAMS
  end

  # Figure which of the active params should get handled by :sorted_index.
  # Some controllers don't handle all three basics, so we derive what's there.
  def index_basic_params
    index_active_params.intersection(INDEX_BASIC_PARAMS)
  end

  # Should this param be handled by :sorted_index or a named method?
  def index_param_method_or_default(subaction)
    index_basic_params.include?(subaction) ? :sorted_index : subaction
  end

  # Generally this is the default index action, no params given.
  # In some controllers, you have to pass params[:all] to get this, however.
  def unfiltered_index
    return unless unfiltered_index_permitted?

    query_args = { by: default_sort_order }.
                 merge(unfiltered_index_opts[:query_args])

    [query_args, unfiltered_index_opts[:display_opts]]
  end

  # Can be overridden to prevent the unfiltered index from being called.
  def unfiltered_index_permitted?
    true
  end

  # Defaults for the unfiltered index. Controllers may pass their own opts.
  def unfiltered_index_opts
    { query_args: {}, display_opts: {} }
  end

  # This handles the index if you pass any of the basic params.
  def sorted_index
    return unless sorted_index_permitted?

    [sorted_index_opts[:query_args], sorted_index_opts[:display_opts]]
  end

  def sorted_index_permitted?
    true
  end

  def sorted_index_opts
    { query_args: { by: params[:by] }, display_opts: index_display_at_id_opts }
  end

  # The filtered index.
  def filtered_index(query_args, extra_display_opts = {})
    query = create_query(controller_model_name.to_sym, **query_args)
    query = filtered_index_final_hook(query, extra_display_opts)
    display_opts = index_display_opts(extra_display_opts, query)

    show_index_of_objects(query, display_opts)
  end

  # This is a hook for controllers to modify the query before it is used,
  # or do anything else before the index is displayed.
  # NOTE: Must return the query (if writing an override).
  def filtered_index_final_hook(query, _display_opts)
    query
  end

  # Default for the display_opts hash passed to show_index_of_objects.
  # These are pretty different per controller.
  def index_display_opts(extra_display_opts, _query)
    {}.merge(extra_display_opts)
  end

  # Default for the display_opts hash passed to show_index_of_objects
  # when the index is called with an id.
  def index_display_at_id_opts
    { id: params[:id].to_s, always_index: true }
  end

  # Most pattern searches follow this, um, pattern.
  def pattern
    pattern = params[:pattern].to_s
    if (obj = maybe_pattern_is_an_id(pattern))
      redirect_to(send(:"#{controller_model_name.underscore}_path", obj.id))
      [nil, {}]
    else
      [{ pattern: }, {}]
    end
  end

  # If so, redirect to the show page for that object.
  def maybe_pattern_is_an_id(pattern)
    if /^\d+$/.match?(pattern)
      return controller_model_name.constantize.safe_find(pattern)
    end

    false
  end

  # Render an index or set of search results as a list or matrix. Arguments:
  # query::         Query instance describing search/index.
  # display_opts::  Hash of options.
  #
  # Options include these:
  # id::            Load the page that includes object with this id.
  # matrix::        Displaying results as matrix?
  # cache::         Cache the HTML of the results?
  # letters::       Paginating by letter?
  # letter_arg::    Param used to store letter for pagination.
  # number_arg::    Param used to store page number for pagination.
  # num_per_page::  Number of results per page.
  # always_index::  Always show index, even if only one result.
  #
  # Side-effects: (sets/uses the following instance variables for the view)
  # @title::        Provides default title.
  # @layout::
  # @pages::        Paginator instance.
  # @objects::      Array of objects to be shown.
  #
  # Other side-effects:
  # store_location::          Sets this as the +redirect_back_or_default+
  #                           location.
  # clear_query_in_session::  Clears the query from the "clipboard"
  #                           (if you didn't just store this query on it!).
  # query_params_set::        Tells +query_params+ to pass this query on
  #                           in links on this page.
  #
  def show_index_of_objects(query, display_opts = {})
    show_index_setup(query, display_opts)
    if (@num_results == 1) && !display_opts[:always_index]
      show_action_redirect(query)
    else
      calc_pages_and_objects(query, display_opts)
      render(action: :index) # must be explicit for names' `test_index` action
    end
  end

  private ##########

  def show_index_setup(query, display_opts)
    apply_content_filters(query)
    store_location
    clear_query_in_session if session[:checklist_source] != query.id
    query_params_set(query)
    query.need_letters = display_opts[:letters] if display_opts[:letters]
    set_index_view_ivars(query, display_opts)
  end

  def apply_content_filters(query)
    filters = users_content_filters || {}
    @any_content_filters_applied = false
    # disable cop because ContentFilter is not an ActiveRecord model
    ContentFilter.all.each do |fltr| # rubocop:disable Rails/FindEach
      apply_one_content_filter(fltr, query, filters[fltr.sym])
    end
  end

  def apply_one_content_filter(fltr, query, user_filter)
    key = fltr.sym
    return unless query.takes_parameter?(key)
    return if query.params.key?(key)
    return unless fltr.on?(user_filter)

    # This is a "private" method used by Query#validate_params.
    # It would be better to add these parameters before the query is
    # instantiated. Or alternatively, make query validation lazy so
    # we can continue to add parameters up until we first ask it to
    # execute the query.
    query.params[key] = query.validate_value(fltr.type, fltr.sym,
                                             user_filter.to_s)
    @any_content_filters_applied = true
  end

  ###########################################################################
  #
  # INDEX VIEW METHODS - MOVE VIEW CODE TO HELPERS

  # Set some ivars used in all index views.
  # Makes @query available to the :index template for query-dependent tabs
  #
  def set_index_view_ivars(query, display_opts)
    @query = query
    @error ||= :runtime_no_matches.t(type: query.model.type_tag)
    @layout = calc_layout_params if display_opts[:matrix]
    @num_results = query.num_results
  end

  ###########################################################################

  def show_action_redirect(query)
    redirect_with_query(controller: query.model.show_controller,
                        action: query.model.show_action,
                        id: query.result_ids.first)
  end

  def calc_pages_and_objects(query, display_opts)
    number_arg = display_opts[:number_arg] || :page
    @pages = if display_opts[:letters]
               paginate_letters(display_opts[:letter_arg] || :letter,
                                number_arg, num_per_page(display_opts))
             else
               paginate_numbers(number_arg, num_per_page(display_opts))
             end
    skip_if_coming_back(query, display_opts)
    find_objects(query, display_opts)
  end

  def num_per_page(display_opts)
    return @layout["count"] if display_opts[:matrix]

    display_opts[:num_per_page] || 50
  end

  def skip_if_coming_back(query, display_opts)
    if display_opts[:id].present? &&
       params[@pages.letter_arg].blank? &&
       params[@pages.number_arg].blank?
      @pages.show_index(query.index(display_opts[:id]))
    end
  end

  # NOTE: there are two places where cache args have to be sent to enable
  # efficient caching. Sending `cache: true` here to `show_index_of_objects`
  # allows us to optimize eager-loading, doing it only for records not cached.
  # (The other place is from the template to the `matrix_box` helper, which
  # actually caches the HTML.)
  def find_objects(query, display_opts)
    logger.warn("QUERY starting: #{query.query.inspect}")
    @timer_start = Time.current

    # Instantiate correct subset, with or without includes.
    @objects = instantiated_object_subset(query, display_opts)

    @timer_end = Time.current
    logger.warn("QUERY finished: model=#{query.model}, " \
                "params=#{query.params.inspect}, " \
                "time=#{(@timer_end - @timer_start).to_f}")
  end

  def instantiated_object_subset(query, display_opts)
    caching = display_opts[:cache] || false
    include = display_opts[:include] || nil

    if caching
      objects_with_only_needed_eager_loads(query, include)
    else
      query.paginate(@pages, include: include)
    end
  end

  # If caching, only uncached objects need to eager_load the includes
  def objects_with_only_needed_eager_loads(query, include)
    # Not currently caching on user.
    # user = User.current ? "logged_in" : "no_user"
    locale = I18n.locale
    objects_simple = query.paginate(@pages)

    # If temporarily disabling cached matrix boxes: eager load everything
    # ids_to_eager_load = objects_simple

    ids_to_eager_load = objects_simple.reject do |obj|
      object_fragment_exist?(obj, locale)
    end.pluck(:id)
    # now get the heavy loaded instances:
    objects_eager = query.model.where(id: ids_to_eager_load).includes(include)
    # our Array extension: collates new instances with old, in original order
    objects_simple.collate_new_instances(objects_eager)
  end

  # Check if a cached partial exists for this object.
  # digest_path_from_template from ActionView::Helpers::CacheHelper :nodoc:
  # https://stackoverflow.com/a/77862353/3357635
  def object_fragment_exist?(obj, locale)
    template = lookup_context.find(action_name, lookup_context.prefixes)
    digest_path = helpers.digest_path_from_template(template)

    fragment_exist?([digest_path, obj, locale])
  end

  def users_content_filters
    @user ? @user.content_filter : MO.default_content_filter
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

    # Assure that this method calls a top level controller namespace by
    # the show_controller in a string after a leading slash.
    # The name must be anchored with a slash to avoid namespacing it.
    # Currently handled upstream in AbstractModel#show_controller.
    # references: http://guides.rubyonrails.org/routing.html#controller-namespaces-and-routing
    # https://stackoverflow.com/questions/20057910/rails-url-for-behaving-differently-when-using-namespace-based-on-current-cont
    redirect_with_query(controller: model.show_controller,
                        action: model.index_action)
    nil
  end

  # Like find_or_goto_index, but allows redirect to a different index
  def find_obj_or_goto_index(model:, obj_id:, index_path:)
    model.safe_find(obj_id) ||
      flash_obj_not_found_and_goto_index(
        model: model, obj_id: obj_id, index_path: index_path
      )
  end

  private ##########

  def flash_obj_not_found_and_goto_index(model:, obj_id:, index_path:)
    flash_error(
      :runtime_object_not_found.t(id: obj_id, type: model.type_tag)
    )
    redirect_with_query(index_path)
    nil
  end

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
  #   query  = create_query(:Name, :user => params[:id].to_s)
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
  #   query    = create_query(:Name, :user => params[:id].to_s)
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
  # helper_method :paginate_numbers

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
end
# rubocop:enable Metrics/ModuleLength
