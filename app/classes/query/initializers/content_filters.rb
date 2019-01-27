module Query
  module Initializers
    # Handles user content filters.
    module ContentFilters
      def content_filter_parameter_declarations(model)
        ContentFilter.by_model(model).each_with_object({}) do |fltr, decs|
          decs[:"#{fltr.sym}?"] = fltr.type
        end
      end

      def initialize_content_filters_for_rss_log(model)
        conds = content_filter_sql_conds(model)
        return unless conds.any?

        table = model.table_name
        add_join(:"#{table}!") # "!" means left outer join
        @where << "#{table}.id IS NULL OR (#{and_clause(*conds)})"
      end

      def initialize_content_filters(model)
        @where += content_filter_sql_conds(model)
      end

      def content_filter_sql_conds(model)
        ContentFilter.by_model(model).
          each_with_object([]) do |fltr, conds|
            next if params[fltr.sym].to_s == ""

            val = params[fltr.sym]
            result = fltr.sql_conditions(self, model, val)
            conds.push(*result)
          end
      end
    end
  end
end
