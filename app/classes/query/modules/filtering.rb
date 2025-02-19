# frozen_string_literal: true

# Add user content filters to Query params (including subqueries), if
# applicable. Runs after validation so filters can defer to intentionally
# sent params.
module Query::Modules::Filtering
  attr_accessor :params

  def add_user_content_filters_to_params
    @preference_filter_applied = false

    subquery_parameters.each do |param, param_type|
      submodel = param_type.values.first
      subquery = Query.new(submodel, val)
      apply_preference_filters(subquery)

      @params[param] = subquery.params
    end

    apply_preference_filters(self)

    # NOTE: This param is needed to distinguish between filtering by
    # user.content_filter vs advanced search, because they use the same params.
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
