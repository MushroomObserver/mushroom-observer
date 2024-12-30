# frozen_string_literal: true

# see application_controller.rb
# rubocop:disable Metrics/ModuleLength
module ApplicationController::Queries
  def self.included(base)
    base.helper_method(
      :query_from_session, :passed_query, :query_params, :add_query_param,
      :get_query_param, :query_params_set
    )
  end
  ##############################################################################
  #
  #  :section: Queries
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
  # helper_method :query_from_session

  # Get instance of Query which is being passed to subsequent pages.
  def passed_query
    Query.safe_find(query_params[:q].to_s.dealphabetize)
  end
  # helper_method :passed_query

  # NOTE: If we're going to cache user stuff that depends on their present q,
  # we'll need a helper to make the current QueryRecord (not just the id)
  # available to templates as an ApplicationController ivar. Something like:
  #
  # def current_query_record
  #   current_query = passed_query || query_from_session # could both be nil!
  #   current_query_record = current_query&.record || "no_query"
  # end

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
  # helper_method :query_params

  def add_query_param(params, query = nil)
    return params if browser.bot?

    query_param = get_query_param(query)
    if params.is_a?(String) # i.e., if params is a path
      append_query_param_to_path(params, query_param)
    else
      params[:q] = query_param if query_param
      params
    end
  end
  # helper_method :add_query_param

  def append_query_param_to_path(path, query_param)
    return path unless query_param

    if path.include?("?") # Does path already have a query string?
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
  # helper_method :get_query_param

  # NOTE: these two methods add q: param to urls built from controllers/actions.
  def redirect_with_query(args, query = nil)
    redirect_to(add_query_param(args, query))
  end

  def url_with_query(args, query = nil)
    url_for(add_query_param(args, query))
  end

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
  # helper_method :query_params_set

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
  def find_query(model = nil, update: !browser.bot?)
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
    return false unless invalid_q_param?

    flash_error(:advanced_search_bad_q_error.t)
    redirect_to(search_advanced_path)
  end

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
    result = find_query(model, update: false)
    if result
      # If existing query needs updates, we need to create a new query,
      # otherwise the modifications won't persist.
      # Use the existing query as the template, though.
      if query_needs_update?(args, result)
        result = create_query(model, result.params.merge(args))
      end
    # If no query found, just create a default one.
    else
      result = create_query(model, args)
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
      !QueryRecord.exists?(id: params[:q].dealphabetize)
  end

  # Create a new Query of the given model.  Pass it
  # in all the args you would to Query#new.
  def create_query(model_symbol, args = {})
    Query.lookup(model_symbol, args)
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
    tweaked_params = query.params.merge(tweaked_bounding_box_params)
    Query.lookup(model, tweaked_params)
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

  # Need to pass list of tags used in this action to next page if redirecting.
  def redirect_to(*args)
    flash[:tags_on_last_page] = Language.save_tags if Language.tracking_usage
    if args.member?(:back)
      redirect_back(fallback_location: "/")
    else
      super
    end
  end

  # Objects that belong to a single observation:
  def redirect_to_back_object_or_object(back_obj, obj)
    if back_obj
      redirect_with_query(back_obj.show_link_args)
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
    query = find_or_create_query(object.class.to_sym)
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
# rubocop:enable Metrics/ModuleLength
