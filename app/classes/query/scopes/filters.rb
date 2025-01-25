# frozen_string_literal: true

module Query::Scopes::Filters
  def initialize_content_filters_for_rss_log(model)
    conditions = content_filter_scope_conditions(model)
    return unless conditions.any?

    # table = model.table_name
    # add_join(:"#{table}!") # "!" means left outer join
    # @where << "#{table}.id IS NULL OR (#{and_clause(*conditions)})"
    @scopes = @scopes.left_outer_joins(:"#{model.table_name}").
              where(model.arel_table[:id].eq(nil).or(and_clause(*conditions)))
  end

  def initialize_content_filters(model)
    # @where += content_filter_sql_conds(model)
    conditions = content_filter_scope_conditions(model)
    return unless conditions.any?

    @scopes = @scopes.where(and_clause(*conditions))
  end

  def content_filter_scope_conditions(model)
    Query::Filter.by_model(model).
      each_with_object([]) do |fltr, conditions|
        next if params[fltr.sym].to_s == ""

        val = params[fltr.sym]
        result = fltr.scope_conditions(self, model, val)
        conditions.push(*result)
      end
  end
end
