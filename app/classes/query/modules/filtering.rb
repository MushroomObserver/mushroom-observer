# frozen_string_literal: true

# Add user content filter params to Query params (including subqueries), if
# applicable. Runs after validation so filters can defer to intentionally
# sent params. For each subquery, the validator sends a Query instance to help
# with filtering.
module Query::Modules::Filtering
  attr_accessor :params, :subqueries

  def add_user_content_filters_to_params
    @preference_filter_applied = false
    # debugger
    subquery_parameters.each_key do |param|
      # debugger
      next unless (subquery = @subqueries[param])

      apply_preference_filters(subquery)
      @subqueries[param] = subquery
      @params[param] = subquery.params
    end

    apply_preference_filters(self)

    # NOTE: This param is needed by the controller to distinguish between
    # params that have been filtered by user.content_filter vs advanced search,
    # because they use the same params.
    @params[:preference_filter] = true if @preference_filter_applied
  end

  def apply_preference_filters(query)
    filters = users_preference_filters || {}
    # disable cop because Query::Filter is not an ActiveRecord model
    Query::Filter.all.each do |fltr| # rubocop:disable Rails/FindEach
      apply_one_preference_filter(fltr, query, filters[fltr.sym])
    end
  end

  def apply_one_preference_filter(fltr, query, user_filter)
    return unless query.is_a?(Query::Base)

    key = fltr.sym
    return unless query.takes_parameter?(key)
    return if query.params.key?(key)
    return unless fltr.on?(user_filter)

    query.params[key] = validate_value(fltr.type, fltr.sym, user_filter.to_s)
    @preference_filter_applied = true
  end

  def users_preference_filters
    User.current ? User.current.content_filter : MO.default_content_filter
  end
end
