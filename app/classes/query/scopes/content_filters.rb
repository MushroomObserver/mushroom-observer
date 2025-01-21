# frozen_string_literal: true

module Query::Scopes::ContentFilters
  def initialize_content_filters_for_rss_log(model)
    conds = content_filter_scope_conds(model)
    return unless conds.any?

    # table = model.table_name
    # add_join(:"#{table}!") # "!" means left outer join
    # @where << "#{table}.id IS NULL OR (#{and_clause(*conds)})"
    @scopes = @scopes.left_outer_joins(:"#{model.table_name}").
              where(model.arel_table[:id].eq(nil).or(conds))
  end

  def initialize_content_filters(model)
    # @where += content_filter_sql_conds(model)
    conds = content_filter_scope_conds(model)
    return unless conds.any?

    @scopes = @scopes.where(conds)
  end

  def content_filter_scope_conds(model)
    ContentFilter.by_model(model).
      each_with_object([]) do |fltr, conds|
        next if params[fltr.sym].to_s == ""

        val = params[fltr.sym]
        result = fltr.scope_conditions(self, model, val)
        conds.push(*result)
      end
  end
end
