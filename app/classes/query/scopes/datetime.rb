# frozen_string_literal: true

# Helper methods for adding date and time conditions to query.
module Query::Scopes::Datetime
  def add_date_condition(vals, *joins)
    return if vals.empty?

    earliest, latest = vals
    @scopes << latest ? when_in_range(earliest, latest) : when_after(earliest)
    add_joins(*joins)
  end

  def add_time_condition(col, vals, *joins)
    return unless vals

    add_half_time_condition(true, col, vals[0])
    add_half_time_condition(false, col, vals[1])
    add_joins(*joins)
  end

  # ----------------------------------------------------------------------------

  DATE_FORMAT = "STR_TO_DATE('%04d-%02d-%02d %02d:%02d:%02d', %s)"
  SQL_DATE_FORMAT = "'%Y-%m-%d %H:%i:%s'"

  def add_half_time_condition(min, col, val)
    return if val.blank?

    y, m, d, h, n, s = val.split("-")
    @where << format(
      "#{col} #{min ? ">" : "<"}= #{DATE_FORMAT}",
      y.to_i,
      (m || (min ? 1 : 12)).to_i,
      (d || (min ? 1 : 31)).to_i,
      (h || (min ? 0 : 23)).to_i,
      (n || (min ? 0 : 59)).to_i,
      (s || (min ? 0 : 59)).to_i,
      SQL_DATE_FORMAT
    )
  end
end
