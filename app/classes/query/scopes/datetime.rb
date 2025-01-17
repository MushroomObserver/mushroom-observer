# frozen_string_literal: true

# Helper methods for adding date and time conditions to query.
module Query::Scopes::Datetime
  def add_date_condition(col, vals, *joins)
    return if vals.empty?

    earliest, latest = vals
    @scope = if latest
               @scope.date_between(col, earliest, latest)
             else
               @scope.date_after(col, earliest)
             end

    add_joins(*joins)
  end

  def add_time_condition(col, vals, *joins)
    return unless vals

    earliest, latest = vals
    @scope = if latest
               @scope.datetime_between(col, earliest, latest)
             else
               @scope.datetime_after(col, earliest)
             end

    add_joins(*joins)
  end
end
