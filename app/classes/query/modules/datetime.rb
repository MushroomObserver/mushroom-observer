# frozen_string_literal: true

# Helper methods for adding date and time conditions to query.
module Query::Modules::Datetime
  def add_date_condition(col, vals, *joins)
    return if vals.empty?

    # Special case for search by month/day where range of months wraps
    # around from December to January.
    if vals[0].to_s.match(/^\d\d-\d\d$/) &&
       vals[1].to_s.match(/^\d\d-\d\d$/) &&
       vals[0].to_s > vals[1].to_s
      add_wrapped_date_condition(col, vals)
    else
      add_half_date_condition(true, col, vals[0])
      add_half_date_condition(false, col, vals[1])
    end
    add_joins(*joins)
  end

  def add_time_condition(col, vals, *joins)
    return unless vals

    add_half_time_condition(true, col, vals[0])
    add_half_time_condition(false, col, vals[1])
    add_joins(*joins)
  end

  # ----------------------------------------------------------------------------

  private

  def add_wrapped_date_condition(col, vals)
    m1, d1 = vals[0].to_s.split("-")
    m2, d2 = vals[1].to_s.split("-")
    @where << "MONTH(#{col}) > #{m1} OR " \
              "MONTH(#{col}) < #{m2} OR " \
              "(MONTH(#{col}) = #{m1} AND DAY(#{col}) >= #{d1}) OR " \
              "(MONTH(#{col}) = #{m2} AND DAY(#{col}) <= #{d2})"
  end

  def add_half_date_condition(min, col, val)
    dir = min ? ">" : "<"
    if /^\d\d\d\d/.match?(val.to_s)
      y, m, d = val.split("-")
      @where << format("#{col} #{dir}= '%04d-%02d-%02d'",
                       y.to_i,
                       (m || (min ? 1 : 12)).to_i,
                       (d || (min ? 1 : 31)).to_i)
    elsif /-/.match?(val.to_s)
      m, d = val.split("-")
      @where << "MONTH(#{col}) #{dir} #{m} OR " \
                "(MONTH(#{col}) = #{m} AND " \
                "DAY(#{col}) #{dir}= #{d})"
    elsif val.present?
      @where << "MONTH(#{col}) #{dir}= #{val}"
    end
  end

  def add_half_time_condition(min, col, val)
    return if val.blank?

    y, m, d, h, n, s = val.split("-")
    @where << format(
      "#{col} #{min ? ">" : "<"}= '%04d-%02d-%02d %02d:%02d:%02d'",
      y.to_i,
      (m || (min ? 1 : 12)).to_i,
      (d || (min ? 1 : 31)).to_i,
      (h || (min ? 0 : 24)).to_i,
      (n || (min ? 0 : 60)).to_i,
      (s || (min ? 0 : 60)).to_i
    )
  end
end
