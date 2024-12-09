# frozen_string_literal: true

# see application_controller.rb
module ApplicationController::Indexes
  def self.included(base)
    base.helper_method(:paginate_numbers)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def index_subaction_param_keys
      @index_subaction_param_keys ||= []
    end

    def index_subaction_dispatch_table
      @index_subaction_dispatch_table ||= {}
    end
  end

  ##############################################################################
  #
  #  :section: Indexes
  #
  ##############################################################################

  # Dispatch to a subaction
  def index
    self.class.index_subaction_param_keys.each do |subaction|
      if params[subaction].present?
        return send(
          self.class.index_subaction_dispatch_table[subaction] ||
          subaction
        )
      end
    end
    default_index_subaction
  end

  # Render an index or set of search results as a list or matrix. Arguments:
  # query::     Query instance describing search/index.
  # args::      Hash of options.
  #
  # Options include these:
  # id::            Warp to page that includes object with this id.
  # action::        Template used to render results.
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
  # @extra_data::   Results of block yielded on every object if block given.
  #
  # Other side-effects:
  # store_location::          Sets this as the +redirect_back_or_default+
  #                           location.
  # clear_query_in_session::  Clears the query from the "clipboard"
  #                           (if you didn't just store this query on it!).
  # query_params_set::        Tells +query_params+ to pass this query on
  #                           in links on this page.
  #
  def show_index_of_objects(query, args = {})
    show_index_setup(query, args)
    if (@num_results == 1) && !args[:always_index]
      show_action_redirect(query)
    else
      calc_pages_and_objects(query, args)
      if block_given?
        @extra_data = @objects.each_with_object({}) do |object, data|
          row = yield(object)
          row = [row] unless row.is_a?(Array)
          data[object.id] = row
        end
      end
      show_index_render(args)
    end
  end

  private ##########

  def show_index_setup(query, args)
    apply_content_filters(query)
    store_location
    clear_query_in_session if session[:checklist_source] != query.id
    query_params_set(query)
    query.need_letters = args[:letters] if args[:letters]
    set_index_view_ivars(query, args)
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
  def set_index_view_ivars(query, args)
    @query = query
    @error ||= :runtime_no_matches.t(type: query.model.type_tag)
    @layout = calc_layout_params if args[:matrix]
    @num_results = query.num_results
  end

  ###########################################################################

  def show_action_redirect(query)
    redirect_with_query(controller: query.model.show_controller,
                        action: query.model.show_action,
                        id: query.result_ids.first)
  end

  def calc_pages_and_objects(query, args)
    number_arg = args[:number_arg] || :page
    @pages = if args[:letters]
               paginate_letters(args[:letter_arg] || :letter, number_arg,
                                num_per_page(args))
             else
               paginate_numbers(number_arg, num_per_page(args))
             end
    skip_if_coming_back(query, args)
    find_objects(query, args)
  end

  def num_per_page(args)
    return @layout["count"] if args[:matrix]

    args[:num_per_page] || 50
  end

  def skip_if_coming_back(query, args)
    if args[:id].present? &&
       params[@pages.letter_arg].blank? &&
       params[@pages.number_arg].blank?
      @pages.show_index(query.index(args[:id]))
    end
  end

  # NOTE: there are two places where cache args have to be sent to enable
  # efficient caching. Sending `cache: true` here to `show_index_of_objects`
  # allows us to optimize eager-loading, doing it only for records not cached.
  # (The other place is from the template to the `matrix_box` helper, which
  # actually caches the HTML.)
  def find_objects(query, args)
    logger.warn("QUERY starting: #{query.query.inspect}")
    @timer_start = Time.current

    # Instantiate correct subset, with or without includes.
    @objects = instantiated_object_subset(query, args)

    @timer_end = Time.current
    logger.warn("QUERY finished: model=#{query.model}, " \
                "flavor=#{query.flavor}, params=#{query.params.inspect}, " \
                "time=#{(@timer_end - @timer_start).to_f}")
  end

  def instantiated_object_subset(query, args)
    caching = args[:cache] || false
    include = args[:include] || nil

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

  def show_index_render(args)
    if args[:template]
      render(template: args[:template]) # Render the list if given template.
    elsif args[:action]
      render(action: args[:action])
    end
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
  #   query  = create_query(:Name, :by_user, :user => params[:id].to_s)
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
