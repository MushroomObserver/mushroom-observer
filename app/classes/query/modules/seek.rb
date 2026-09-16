# frozen_string_literal: true

##############################################################################
#
#  :module: Seek
#
#  Keyset ("seek method") predicate machinery for bounded neighbor
#  fetches, used by `Query::Modules::WindowCache#compute_window` to
#  fetch a window of ids around the current position with two indexed
#  `LIMIT` queries instead of a full scan of every matching id. Only
#  applies when the query's ORDER BY is a plain list of columns --
#  `seekable_cols` returns nil for shapes a keyset comparison can't
#  express (aggregates, CASE expressions, FIND_IN_SET-based position
#  ordering), and the caller falls back to the full-array path.
#
##############################################################################

module Query::Modules::Seek
  private

  # Allow-list: anything not a plain column Ascending/Descending
  # (aggregate, CASE, FindInSet) falls back to the full-array path.
  # Memoizes the order columns themselves, not just whether they
  # qualify, so callers don't need to re-read `scope.order_values` --
  # `scope` itself is unmemoized and rebuilds the whole relation.
  def seekable_cols
    return @seekable_cols if defined?(@seekable_cols)

    values = scope.order_values
    seekable = values.present? && values.all? do |o|
      o.respond_to?(:direction) && o.expr.is_a?(Arel::Attributes::Attribute)
    end
    @seekable_cols = seekable ? values : nil
  end

  # Current row's own sort-column values, to seed the keyset
  # comparison. Memoized by current_id -- prev_id and next_id render
  # back-to-back for the same current_id (ShowPrevNextNav), and this
  # value doesn't depend on which direction is being looked up.
  #
  # A to-many join (e.g. Image.order_by(:confidence)) can produce more
  # than one row per id with different column values -- bail to the
  # fallback rather than seed from an arbitrary one.
  def current_sort_values(cols)
    @current_sort_values ||= {}
    return @current_sort_values[current_id] if
      @current_sort_values.key?(current_id)

    @current_sort_values[current_id] = fetch_current_sort_values(cols)
  end

  def fetch_current_sort_values(cols)
    attrs = cols.map(&:expr)
    rows = scope.where(model.arel_table[:id].eq(current_id)).
           limit(2).pluck(*attrs)
    return nil unless rows.size == 1

    attrs.size == 1 ? [rows.first] : rows.first
  end

  # Seek-method predicate for a compound order (a, b, ..., id) --
  # tuple comparison, since ties on the primary column are common.
  def build_seek_predicate(cols, current_row, forward:)
    legs = cols.each_index.map do |idx|
      seek_leg(cols, current_row, idx, forward:)
    end
    legs.reduce { |a, b| a.or(b) }
  end

  # One leg of the tuple comparison: columns before `idx` held equal,
  # column `idx` past the current row's value.
  def seek_leg(cols, current_row, idx, forward:)
    eq_prefix = (0...idx).map { |j| cols[j].expr.eq(current_row[j]) }
    ascending = cols[idx].is_a?(Arel::Nodes::Ascending)
    increasing = ascending == forward
    leg = seek_comparison(cols[idx].expr, current_row[idx], increasing)
    eq_prefix.reduce(leg) { |acc, eq| eq.and(acc) }
  end

  # MySQL sorts NULL as the smallest possible value, in both ASC and
  # DESC. Plain `>`/`<` can't express that: `col > NULL` is always
  # unknown in SQL, so it can't match "any non-NULL value" when
  # seeking up from a NULL current value; `col < 5` can't match a NULL
  # row either, so seeking down from a non-NULL value skips straight
  # past the transition into NULL territory. Both need an explicit
  # branch; seeking up from a non-NULL value, or down from NULL
  # (nothing sorts below it), are already correct with a plain
  # comparison.
  def seek_comparison(attr, value, increasing)
    if increasing
      value.nil? ? attr.not_eq(nil) : attr.gt(value)
    else
      value.nil? ? attr.lt(value) : attr.lt(value).or(attr.eq(nil))
    end
  end
end
