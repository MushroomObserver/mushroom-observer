# frozen_string_literal: true

#  ==== Queries
#  create_query::           Create a new Query from scratch.
#  find_or_create_query::   Find appropriate Query or create as necessary.
#  find_query::             Find a given Query or return nil.
#
#  update_stored_query::    Saves a passed query and stores id in the session.
#  clear_query_in_session:: Clears out Query stored in session below.
#  store_query_in_session:: Stores Query in session for use by
#                           create_species_list.
#  query_from_session::     Gets Query that was stored in the session above.
#
#  current_query::          Returns @query, #query_from_q_param or
#                           #query_from_session (in order of precedence)
#  query_from_q_param::     Query instance from current params[:q]
#  query_from_session::     Query instance from the session[:query_record]
#  add_q_param::            Adds :q param to path or hash. Accepts passed query.
#  q_param::                Returns :q param hash. Accepts passed query.
#  redirect_to_next_object:: Find next object from a Query and redirect to its
#                            show page.
#
module ApplicationController::Queries
  def self.included(base)
    base.helper_method(
      :query_from_session, :query_params, :add_q_param, :q_param,
      :find_or_create_query
    )
  end

  ##############################################################################
  #
  #  :section: Queries
  #
  #  Call these public methods to create a query for results shown on an index
  #  action.
  #
  ##############################################################################

  # Create a new Query object for a model, without saving a QueryRecord or
  # setting the session[:query_record]. Can be used to create a link/permalink,
  # or retrieve records, without altering the current user's Query context.
  #
  # Prefer this instead of directly calling Query.lookup or PatternSearch#query.
  # Takes the same query_params as Query#new or Query#lookup, but this is the
  # only place where user content filters are applied.
  #
  # (NOTE: Related query links will preserve content filters in the subquery.)
  def create_query(model_symbol, query_params = {})
    query_params = add_user_content_filter_parameters(query_params,
                                                      model_symbol)
    # NOTE: This param `:preference_filter` is used by the controller to
    # know when params have been filtered by @user.content_filter vs any
    # other search, which may send the same params.
    query_params[:preference_filter] = true if @preference_filters_applied
    Query.lookup(model_symbol, query_params)
  end

  # Lookup an appropriate Query or create a default one if necessary. If you
  # pass in arguments, it modifies the query as necessary to ensure they are
  # correct. (Useful for specifying sort conditions, for example.)
  # Saves the query and stores in session. Analogous to Query.lookup_and_save.
  def find_or_create_query(model_symbol, args = {})
    map_past_bys(args)
    model = model_symbol.to_s
    # New: the stored query may have content filters, need to update to compare
    args = add_user_content_filter_parameters(args, model_symbol)
    found_query = existing_updated_or_default_query(model, args)
    save_query_record_unless_bot(found_query)
    found_query
  end

  # Lookup the given kind of Query, returning nil if it no longer exists.
  def find_query(model = nil, update: !browser.bot?)
    model = model.to_s if model
    return nil unless (query = current_query) # invalid ok, will report errors

    found_query = find_new_query_for_model(model, query)
    save_updated_query_record(found_query) if update && found_query
    found_query
  end

  BY_MAP = { "modified" => :updated_at, "created" => :created_at }.freeze

  private ##########

  # Lookup the query and,
  # If it exists, return it or - if its arguments need modification -
  # a new query based on the existing one but with modified arguments.
  # If it does not exist, resturn default query.
  def existing_updated_or_default_query(model, args)
    query = find_query(model, update: false)
    if query
      # If existing query needs updates, we need to create a new query,
      # otherwise the modifications won't persist.
      # Use the existing query as the template, though.
      if query_needs_update?(query, args)
        query = create_query(model, query.params.merge(args))
      end
    # If no query found, just create a default one.
    else
      query = create_query(model, args)
    end
    query
  end

  # Checks if new_args are different from query_params - also if applied user
  # content_filters have been stored in the query, might need to be cleared.
  def query_needs_update?(query, new_args)
    new_args.any? { |arg, val| query.params[arg] != val } ||
      query.params.any? { |arg, val| new_args[arg] != val }
  end

  # Turn old query into a new query for given model,
  # (re-using the old query if it's still correct),
  # and returning nil if no new query can be found.
  def find_new_query_for_model(model, old_query)
    old_query_correct_for_model(model, old_query) || nil
  end

  def old_query_correct_for_model(model, old_query)
    old_query if !old_query || (old_query.model.to_s == model)
  end

  def save_query_record_unless_bot(query)
    return unless query && !browser.bot?

    save_updated_query_record(query)
  end

  # Set the session[:query_record] here
  def save_updated_query_record(query)
    query.increment_access_count
    query.save
    store_query_in_session(query)
  end

  def map_past_bys(args)
    return unless args.member?(:order_by)

    args[:order_by] = (BY_MAP[args[:order_by].to_s] || args[:order_by])
  end

  def add_user_content_filter_parameters(query_params, model)
    filters = current_user_preference_filters || {}
    return query_params if filters.blank?

    # disable cop because Query::Filter is not an ActiveRecord model
    Query::Filter.all.each do |fltr| # rubocop:disable Rails/FindEach
      apply_one_content_filter(fltr, query_params, model, filters[fltr.sym])
    end
    query_params
  end

  def apply_one_content_filter(fltr, query_params, model, user_filter)
    query_class = "Query::#{model.to_s.pluralize}".constantize
    key = fltr.sym
    return unless query_class.has_attribute?(key)
    return if query_params.key?(key)
    return unless fltr.on?(user_filter)

    query_params[key] = user_filter.to_s
    @preference_filters_applied = true
  end

  def current_user_preference_filters
    @user ? @user.content_filter : MO.default_content_filter
  end

  public ##########

  ##############################################################################
  #
  #  :section: Query parameters and session[:query_record]
  #
  #  The general idea is that the user executes a search or requests an index,
  #  then clicks on a result.  This takes the user to a show_object page.
  #  This page "knows" about the search or index via session[:query_record].
  #  When the user then clicks on "prev" or "next", it can then step through
  #  the query results.
  #
  ##############################################################################

  # Change the query stored in session[:query_record].
  # NOTE: ApplicationController::Indexes#show_index_setup calls this.
  def update_stored_query(query = nil)
    # clear_query_in_session
    return if browser.bot? || !query

    store_query_in_session(query)
  end

  # This clears the search/index saved in the session.
  def clear_query_in_session
    session[:query_record] = nil
  end

  # This stores the latest search/index used for use by links.
  # (Stores the Query id in `session[:query_record]`.)
  def store_query_in_session(query)
    query.save unless query.id
    session[:query_record] = query.id
  end

  # NOTE: If we're going to cache user stuff that depends on their present q,
  # we'll need a helper to make the current QueryRecord (not just the id)
  # available to templates as an ApplicationController ivar. Something like:
  #
  def current_query
    @query || query_from_q_param || query_from_session
  end

  # Opposite is `q_param` below
  def query_from_q_param
    # The first condition is for backwards compatibility with old q params.
    # We can delete it when `QueryRecord.where.not(permalink: true).count == 0`
    if query_record_id?(params[:q]) # i.e. QueryRecord.id.alphabetize
      query_from_q_record_id
    elsif params[:q].present?
      query_from_q_param_hash
    end
  end

  # Check if the :q param is an older alphabetized QueryRecord id.
  def query_record_id?(str)
    str.is_a?(String) && str&.match(/^[a-zA-Z0-9]*$/)
  end

  # Get the id of the query_record last stored in the session.
  def query_from_session
    return unless (id = session[:query_record])

    Query.safe_find(id)
  end
  # helper_method :query_from_session

  def query_from_q_record_id
    Query.safe_find(params[:q].to_s.dealphabetize) # this may return nil
  end

  # ShowPrevNextHelper#page_input may send an encoded string.
  # We could try to parse it but we have it
  def query_from_q_param_hash
    q_param = params[:q]
    return query_from_session if q_param.is_a?(String)

    return nil if q_param[:model].blank?

    Query.lookup(q_param[:model].to_sym,
                 **q_param.except(:model).to_unsafe_hash)
  end

  # Add a :q param to a path helper like `names_path`,
  # or a hash like { controller: "/names", action: :index }
  # How many cases would it cover if we add :by and :id in here?
  # Check sorter, other params
  def add_q_param(path_or_params, query = nil)
    return path_or_params if browser.bot? || !(q_param = q_param(query))

    if path_or_params.is_a?(String) # i.e., if "path_or_params" arg is a path
      append_q_param_to_path(path_or_params, q_param)
    else
      path_or_params[:q] = q_param
      path_or_params
    end
  end
  # helper_method :add_q_param

  private

  def append_q_param_to_path(path, q_param)
    return path unless q_param

    # Figure out if there's an existing URI query_string, like "flow=next"
    # This query_string is not our q param, it's all the other params.
    uri = URI.parse(path)
    query_string = uri.query

    # Parse the query_string as a Ruby hash, and add `q`
    hash = query_string ? Rack::Utils.parse_query(query_string) : {}
    hash["q"] = q_param
    uri.query = hash.to_query
    uri.to_s
  end

  public

  # Allows us to add any passed query, or the current to a path helper:
  #   link_to(@object.show_link_args.merge(q: q_param))
  # Saves the query, but does not set session[:query_record]
  def q_param(query = nil)
    return nil if browser.bot?

    query.save if query && !query.id
    query ||= current_query
    query&.q_param
  end
  # helper_method :q_param

  # NOTE: these two methods add q: param to urls built from controllers/actions.
  def redirect_with_query(args, query = nil)
    redirect_to(add_q_param(args, query))
  end

  def url_with_query(args, query = nil)
    url_for(add_q_param(args, query))
  end

  # Handle advanced_search actions with an invalid q param,
  # so that they get just one flash msg if the query has expired.
  # This method avoids a call to find_safe, which would add
  # "undefined method `id' for nil:NilClass" if there's no QueryRecord for q
  def handle_advanced_search_invalid_q_param?
    return false unless invalid_q_param?

    flash_error(:advanced_search_bad_q_error.t)
    redirect_to(search_advanced_path)
  end

  def invalid_q_param?
    params && params[:q] && query_invalid?
  end

  def query_invalid?
    return true unless (query = current_query)

    query.invalid?
  end

  # Need to pass list of tags used in this action to next page if redirecting.
  def redirect_to(*args)
    flash[:tags_on_last_page] = Language.save_tags if Language.tracking_usage?
    if args.member?(:back)
      redirect_back(fallback_location: "/")
    else
      super
    end
  end

  # Objects that belong to a single observation:
  def redirect_to_back_object_or_object(back_obj, obj)
    if back_obj
      redirect_to(back_obj.show_link_args)
    elsif obj
      redirect_with_query(obj.index_link_args)
    else
      redirect_with_query("/")
    end
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
    return unless (object = find_or_goto_index(model, id))

    next_params = find_query_and_next_object(object, method, id)
    object = next_params[:object]
    id =     next_params[:id]
    query =  next_params[:query]

    # Redirect to the show_object page appropriate for the new object.
    redirect_to({ controller: object.show_controller,
                  action: object.show_action,
                  id:, q: q_param(query) })
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
    # observations/show, for example, inside an RssLog query, go to the next
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
    return false unless (query = current_query)

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
    query = find_or_create_query(object.class.to_s.to_sym)
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
end
