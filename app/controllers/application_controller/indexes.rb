# frozen_string_literal: true

#  ==== Indexes
#  show_index_of_objects::  Show paginated set of Query results as a list.
#  add_sorting_links::      Create sorting links for index pages.
#  find_or_goto_index::     Look up object by id, displaying error and
#                           redirecting on failure.
#  letter_pagination_data::       Paginate an Array by letter.
#  number_pagination_data::       Paginate an Array normally.
#
module ApplicationController::Indexes # rubocop:disable Metrics/ModuleLength
  def self.included(base)
    base.helper_method(:number_pagination_data)
  end

  ##############################################################################
  #
  #  :section: Filterable Indexes
  #
  #  These methods help to assemble filtered index results (from the query) and
  #  render the interface for the index pagination with info returned by Query.
  #
  #  Every param a controller's Query subclass recognizes (its query_attr
  #  names and their param_alias shortcuts) is a live top-level index
  #  filter -- no per-controller method or allowlist required. Unlike the
  #  old subaction dispatch, recognized params combine: `?by_user=X&
  #  has_notes=true` filters by both, instead of only the first one a
  #  controller happened to list.
  #
  #  `:pattern` gets first priority when both recognized and present,
  #  since it goes through `PatternSearch`'s keyword parsing instead of
  #  the generic per-attr resolution. `:by`/`:q`/`:id` (`sorted_index`)
  #  apply only when no other recognized param is present.
  #
  ##############################################################################
  #
  # Assemble query and display_args: a pattern search, any other
  # recognized filter param, :by/:q/:id, or the unfiltered index -- in
  # that priority order.
  def build_index_with_query
    query, display_opts = index_query_and_display_opts
    return nil if performed? || query.blank?

    filtered_index(query, display_opts)
  end

  # The Query subclass this controller's index filters against, e.g.
  # `Query::Observations` for `ObservationsController`.
  def controller_query_class
    @controller_query_class ||=
      "Query::#{controller_model_name.pluralize}".constantize
  end

  INDEX_BASIC_PARAMS = [:by, :q, :id].freeze

  def index_query_and_display_opts
    return pattern if pattern_param_present?
    return create_query_from_url_params(controller_model_name.to_sym, params) if
      other_filter_param_present?
    return sorted_index if INDEX_BASIC_PARAMS.any? { |p| params[p].present? }

    unfiltered_index
  end

  def pattern_param_present?
    controller_query_class.recognized_params.include?(:pattern) &&
      params[:pattern].present?
  end

  def other_filter_param_present?
    filter_params = controller_query_class.recognized_params -
                    INDEX_BASIC_PARAMS - [:pattern]
    filter_params.any? { |p| params[p].present? }
  end

  def check_for_spider_block(request, params)
    return false if @user

    begin
      if request.url.include?(permanent_observation_path(id: params[:id]))
        return false
      end
    rescue ActionController::UrlGenerationError
      # Still a spider...
    end

    Rails.logger.warn(:runtime_spiders_begone.t)
    render(json: :runtime_spiders_begone.t,
           status: :forbidden)
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

  # Generally this is the default index action, no params given.
  # In some controllers, you have to pass params[:all] to get this, however.
  def unfiltered_index
    return unless unfiltered_index_permitted?

    # Get once, otherwise accessing the hash may rerun some logic twice.
    index_opts = unfiltered_index_opts
    args = { order_by: default_sort_order }.merge(index_opts[:query_args])
    query = create_query(controller_model_name.to_sym, **args)

    [query, index_opts[:display_opts]]
  end

  # Can be overridden to prevent the unfiltered index from being called.
  def unfiltered_index_permitted?
    true
  end

  # Defaults for the unfiltered index; controllers may override with other opts.
  def unfiltered_index_opts
    { query_args: {}, display_opts: {} }.freeze
  end

  # This handles the index if you pass any of the basic params, and runs before
  # #filtered_index. The big difference from #unfiltered_index is that it runs
  # #find_or_create_query instead of #create_query
  def sorted_index
    return unless sorted_index_permitted?

    # Get once, otherwise accessing the hash reruns logic and may flash twice.
    index_opts = sorted_index_opts
    query = find_or_create_query(controller_model_name.to_sym,
                                 **index_opts[:query_args])

    [query, index_opts[:display_opts]]
  end

  def sorted_index_permitted?
    true
  end

  # This only deals with :by, :id, and :type passed in url params.
  def sorted_index_opts
    { query_args: {
        order_by: order_by_or_flash_if_unknown
        # id: params.dig(:q, :id)
      },
      display_opts: index_display_at_id_opts }.freeze
  end

  def order_by_or_flash_if_unknown
    # `query_from_q_param` is able to handle alphabetized :q params
    order_by = if (query = query_from_q_param)
                 query.params[:order_by]
               else
                 params[:by]
               end
    return nil if order_by.blank?

    scope = :"order_by_#{order_by.to_s.sub(/^reverse_/, "")}"
    return order_by if AbstractModel.private_methods(false).include?(scope)

    flash_error(
      :runtime_invalid_sort_order.t(
        type: controller_model_name.underscore.to_sym, order_by: order_by
      )
    )
    default_sort_order
  end

  # The filtered index.
  def filtered_index(query, extra_display_opts = {})
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

  # Sets @project/@observation-style ivars from a Query's resolved
  # params. Call it from filtered_index_final_hook. `attr` must be
  # Array-typed -- no-op when its value isn't an Array, or isn't a
  # 1-element one.
  def derive_ivar_from_query(ivar, query, attr, model_class)
    value = query.params[attr]
    return unless value.is_a?(Array) && value.size == 1

    id = value.first
    instance_variable_set(ivar, resolved_alias_record(attr, id) ||
                                 model_class.safe_find(id))
  end

  # Reuses the record already fetched for this attr, instead of
  # fetching it again. Returns nil if nothing was cached (a
  # bookmarked query) or the id doesn't match.
  def resolved_alias_record(attr, id)
    cached = @resolved_alias_records && @resolved_alias_records[attr]
    cached if cached&.id == id
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

  # e.g. Observations' checklist taxon links, its "did you mean" alert.
  def pattern
    model_name = controller_model_name.to_sym
    pattern = params[:pattern].to_s.strip_squeeze

    return if pattern_too_long?(pattern)

    save_pattern_if_it_wont_overfill_cookie_store(
      model_name.to_s.tableize.to_sym, pattern
    )

    [query_from_pattern(model_name, pattern), {}]
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
  # @title::                  Provides default title.
  # @layout::
  # @pagination_data::        PaginationData instance.
  # @objects::                Array of objects to be shown.
  #
  # Other side-effects:
  # store_location::          Sets this as the +redirect_back_or_default+
  #                           location.
  # clear_query_in_session::  Clears the query from the "clipboard"
  #                           (if you didn't just store this query on it!).
  # update_stored_query::        Tells +query_params+ to pass this query on
  #                           in links on this page.
  #
  def show_index_of_objects(query, display_opts = {})
    show_index_setup(query, display_opts)
    if (@num_results == 1) && !display_opts[:always_index]
      show_action_redirect(query)
    else
      calc_pages_and_objects(query, display_opts)
      return if redirect_past_last_page?

      render_index_view
    end
  end

  # `?page=99` on a 5-page result currently renders an empty result
  # area silently — clamp the URL to the last valid page so the
  # request self-corrects. Returns true (and performs the redirect)
  # when the current request was past the last page; false otherwise.
  def redirect_past_last_page?
    return false unless @pagination_data&.num_pages&.positive?
    return false unless @pagination_data.number > @pagination_data.num_pages

    page_arg = @pagination_data.number_arg.to_s
    redirect_to(
      url_for(params.to_unsafe_h.merge(
                page_arg => @pagination_data.num_pages, only_path: true
              ))
    )
    true
  end

  # Render the index view. Every index controller now renders a Phlex
  # view; this method must be overridden. (No ERB index templates remain;
  # the historical `render(action: :index)` default is gone.)
  def render_index_view
    raise(NotImplementedError.new(render_index_view_error_message))
  end

  def render_index_view_error_message
    "#{self.class}#render_index_view must render a Phlex view"
  end

  private ##########

  def show_index_setup(query, display_opts)
    store_location
    # clear_query_in_session if session[:query_record] != query.id
    update_stored_query(query)
    query.need_letters = display_opts[:letters] if display_opts[:letters]
    set_index_view_ivars(query, display_opts)
    flash_query_validation_errors(query)
  end

  ###########################################################################
  #
  # INDEX VIEW METHODS - MOVE VIEW CODE TO HELPERS

  def flash_query_validation_errors(query)
    return if query.valid || query.validation_errors.empty?

    flash_warning(query.validation_error_messages.join("\n"))
  end

  # Set some ivars used in all index views.
  # Makes @query available to the :index template for query-dependent tabs
  #
  def set_index_view_ivars(query, display_opts)
    @query = query
    @error ||= :runtime_no_matches.t(type: query.model.type_tag)
    @layout = calc_layout_params if display_opts[:matrix]
    @num_results = query.num_results
    @any_content_filters_applied = check_if_preference_filters_applied
    # "No matches" flash for the entire result set — gated on
    # `@num_results.zero?` rather than the current page being empty.
    # Empty-page-on-non-empty-result is handled by
    # `redirect_past_last_page?` clamping the URL to the last
    # valid page.
    flash_error(@error) if @num_results.zero?
  end

  def check_if_preference_filters_applied
    current_params = @query.params.flatten.compact_blank.keys
    return false unless current_params.include?(:preference_filter)

    true
  end

  ###########################################################################

  def show_action_redirect(query)
    redirect_to(controller: query.model.show_controller,
                action: query.model.show_action,
                id: query.result_ids.first)
  end

  def calc_pages_and_objects(query, display_opts)
    number_arg = display_opts[:number_arg] || :page
    @pagination_data =
      if display_opts[:letters]
        letter_pagination_data(display_opts[:letter_arg] || :letter,
                               number_arg, num_per_page(display_opts))
      else
        number_pagination_data(number_arg, num_per_page(display_opts))
      end
    skip_if_coming_back(query, display_opts)
    find_objects(query, display_opts)
  end

  def num_per_page(display_opts)
    return @layout["count"] if display_opts[:matrix]

    display_opts[:num_per_page] || 50
  end

  def skip_if_coming_back(query, display_opts)
    return unless display_opts[:id].present? &&
                  params[@pagination_data.letter_arg].blank? &&
                  params[@pagination_data.number_arg].blank?

    query.position_pagination_at(display_opts[:id], @pagination_data)
  end

  # NOTE: there are two places where cache args have to be sent to enable
  # efficient caching. Sending `cache: true` here to `show_index_of_objects`
  # allows us to optimize eager-loading, doing it only for records not cached.
  # (The other place is from the template to the `matrix_box` helper, which
  # actually caches the HTML.)
  def find_objects(query, display_opts)
    logger.warn("QUERY starting: #{query.sql.inspect}")
    @timer_start = Time.current

    # Instantiate correct subset, with or without includes. `.to_a`
    # materializes the page now so the Phlex index view's `:objects`
    # prop (typed as `_Array(...)`) validates at construction —
    # passing an AR Relation/CollectionProxy would fail Literal's
    # type check at the controller-view boundary.
    @objects = instantiated_object_subset(query, display_opts).to_a

    @timer_end = Time.current
    logger.warn("QUERY finished: model=#{query.model}, " \
                "params=#{query.params.inspect}, " \
                "time=#{(@timer_end - @timer_start).to_f}")
  end

  def instantiated_object_subset(query, display_opts)
    caching = display_opts[:cache] || false
    include = display_opts[:include] || default_index_includes_for_model

    if caching
      objects_with_only_needed_eager_loads(query, include)
    else
      query.paginate(@pagination_data, include: include)
    end
  end

  # Falls back to the model's `index_includes_tree` class method
  # when a controller's `index_display_opts` doesn't specify
  # `:include` explicitly. Lets a controller override `letters:` /
  # `num_per_page:` without re-stating its includes tree — the
  # model is the single source of truth.
  def default_index_includes_for_model
    return nil unless controller_model_name

    model = controller_model_name.safe_constantize
    return nil unless model.respond_to?(:index_includes_tree)

    model.index_includes_tree
  end

  # If caching, only uncached objects need to eager_load the includes
  def objects_with_only_needed_eager_loads(query, include)
    # When MatrixTable will bypass the cache for the whole request
    # (identify mode, project-admin view), every row is going to need
    # the full eager loads anyway — the two-query pre-check shape
    # (paginate simple, re-fetch with includes) is strictly more
    # work than just paginating with the includes the first time.
    #
    # Same story when `perform_caching` is off (the dev default):
    # low_level_cache then always executes its block, ignoring
    # cache_store -- so skipping eager-load here for "assumed cached"
    # objects triggers per-object N+1 fallbacks (e.g.
    # NamingConsensus#use_local_namings) for every one of them.
    unless matrix_caches_in_this_request? && perform_caching?
      return query.paginate(@pagination_data, include: include)
    end

    locale = I18n.locale
    # Preload the per-object association the cache pre-check reads
    # (`MatrixTable.should_cache_object?` consults
    # `obj.thumb_image.transferred`). Without this, the pre-check
    # itself fires SELECT-per-row from `objects_simple`, which is
    # explicitly NOT eager-loaded — defeating the optimization.
    objects_simple = query.paginate(
      @pagination_data, include: cache_precheck_includes(query.model)
    )

    # If temporarily disabling cached matrix boxes: eager load everything
    # ids_to_eager_load = objects_simple

    ids_to_eager_load = uncached_object_ids(objects_simple, locale)
    # now get the heavy loaded instances:
    objects_eager = query.model.where(id: ids_to_eager_load).includes(include)
    # our Array extension: collates new instances with old, in original order
    objects_simple.collate_new_instances(objects_eager)
  end

  # Which of `objects` need eager-loading because their `MatrixBox`
  # fragment isn't already cached. One `read_multi` round trip covers
  # every object's cache-key check, instead of one `Rails.cache.exist?`
  # query per object (Solid Cache is DB-backed, so that was one SQL
  # query per row on the index).
  #
  # Gate: `matrix_caches_in_this_request?` is already guaranteed true
  # by this method's only caller (`objects_with_only_needed_eager_loads`
  # returns early otherwise); `MatrixTable.should_cache_object?`
  # (per-object) is false when the object itself isn't cacheable (e.g.
  # an Observation with an untransferred thumb image) -- those always
  # need eager-loading, no cache lookup necessary.
  #
  # Uses the shared key from `MatrixTable.cache_key_for` so the read
  # matches what `MatrixTable#render_cached_boxes` writes.
  def uncached_object_ids(objects, locale)
    cacheable, uncacheable = objects.partition do |obj|
      ::Components::Matrix::Table.should_cache_object?(obj)
    end
    keys_by_object = cacheable.index_by do |obj|
      ::Components::Matrix::Table.cache_key_for(obj, locale)
    end
    cached_keys = if keys_by_object.empty?
                    []
                  else
                    Rails.cache.read_multi(
                      *keys_by_object.keys
                    ).keys
                  end

    uncached = keys_by_object.except(*cached_keys)
    (uncached.values + uncacheable).pluck(:id)
  end

  # Associations the per-object cache pre-check needs to consult
  # without firing a query. Currently only `:thumb_image` (read by
  # `MatrixTable.should_cache_object?`), and only when the model
  # exposes it. Returns nil if there's nothing to preload so the
  # underlying `query.paginate(...)` call receives no `include:` kw.
  def cache_precheck_includes(model)
    return nil unless model.respond_to?(:reflect_on_association) &&
                      model.reflect_on_association(:thumb_image)

    [:thumb_image]
  end

  # Overridable hook: does this request render the matrix in the
  # cached path? Controllers that always (or sometimes) render
  # `MatrixTable` in identify mode or project-admin view should
  # override. The default is `true` because the basic obs index
  # without an admin-viewable project uses caching.
  def matrix_caches_in_this_request?
    true
  end

  # Whether low_level_cache will actually consult cache_store --
  # phlex-rails gates it on this exact flag.
  def perform_caching?
    Rails.application.config.action_controller.perform_caching
  end

  public ##########

  # Lookup a given object, displaying a warm-fuzzy error and redirecting to the
  # appropriate index if it no longer exists.
  def find_or_goto_index(model, id)
    finder = model.respond_to?(:show_includes) ? model.show_includes : model
    finder.find_by(id: id) || flash_error_and_goto_index(model, id)
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

  # Initialize PaginationData object for pagination by letter.
  # This now does very little thanks to the new Query model.
  # arg::    Name of parameter to use.  (default is 'letter')
  #
  #   # In controller:
  #   query  = create_query(:Name, :by_users => params[:id].to_s)
  #   query.need_letters(true)
  #   @pagination_data = letter_pagination_data(:letter, :page, 50)
  #   @names = query.paginate(@pagination_data)
  #
  #   # In view:
  #   <%= letter_pagination_nav(@pagination_data) %>
  #   <%= number_pagination_nav(@pagination_data) %>
  #
  def letter_pagination_data(letter_arg = :letter,
                             number_arg = :page,
                             num_per_page = 50)
    PaginationData.new(
      letter_arg: letter_arg,
      number_arg: number_arg,
      letter: paginator_letter(letter_arg),
      number: paginator_number(number_arg),
      num_per_page: num_per_page
    )
  end

  # Initialize regular PaginationData object.
  # This now does very little thanks to the new Query model.
  #
  # arg::           Name of parameter to use.  (default is 'page')
  # num_per_page::  Number of results per page.  (default is 50)
  #
  #   # In controller:
  #   query    = create_query(:Name, :by_users => params[:id].to_s)
  #   @numbers = number_pagination_data(:page, 50)
  #   @names   = query.paginate(@numbers)
  #
  #   # In view:
  #   <%= number_pagination_nav(@numbers) %>
  #
  def number_pagination_data(arg = :page, num_per_page = 50)
    PaginationData.new(
      number_arg: arg,
      number: paginator_number(arg),
      num_per_page: num_per_page
    )
  end
  # helper_method :number_pagination_data

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
