# frozen_string_literal: true

##############################################################################
#
#  :module: Seek
#
#  Bounded (keyset) neighbor lookup for `Query::Modules::Sequence`, used
#  when the query's ORDER BY is a plain list of columns -- turns "find
#  the next/prev id" from a full scan of every matching id into a single
#  indexed lookup. Falls back to the full-array approach (`Sequence`'s
#  own `legacy_*` methods) for order shapes this can't handle safely:
#  aggregates, CASE expressions, and FIND_IN_SET-based position
#  ordering.
#
##############################################################################

module Query::Modules::Seek
  # Not a real value -- lets `seek_within_transaction` return normally
  # from inside the `model.transaction` block below, as an ordinary
  # method call rather than a non-local `return`/`break`, while still
  # distinguishing "current row isn't seekable, fall back to the
  # block" from a legitimate `nil` boundary (no next/prev row).
  NOT_SEEKABLE = Object.new.freeze

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
  # unknown, so it can't match "any non-NULL value" when seeking up
  # from a NULL current value; `col < 5` never matches a NULL row
  # either, so seeking down from a non-NULL value skips straight past
  # the transition into NULL territory. Both need an explicit branch;
  # seeking up from a non-NULL value, or down from NULL (nothing sorts
  # below it), are already correct with a plain comparison.
  def seek_comparison(attr, value, increasing)
    if increasing
      value.nil? ? attr.not_eq(nil) : attr.gt(value)
    else
      value.nil? ? attr.lt(value) : attr.lt(value).or(attr.eq(nil))
    end
  end

  # Bounded id, boundary nil, or falls through to the block when the
  # order shape or current row isn't seekable.
  #
  # `current_sort_values` and the neighbor lookup are two separate
  # reads -- wrapped in a transaction so they share one consistent
  # snapshot (MySQL's default REPEATABLE READ). Without this, a
  # concurrent write to the current row's own sort columns (e.g.
  # another user's vote) landing between the two reads could seed the
  # neighbor search from a value that's already stale by the second
  # query. `result_ids` never had this problem -- it's one query.
  def seek_or(dir)
    return yield if need_letters
    return yield unless current_id

    cols = seekable_cols
    return yield unless cols

    result = model.transaction { seek_within_transaction(cols, dir) }
    result == NOT_SEEKABLE ? yield : result
  end

  def seek_within_transaction(cols, dir)
    current_row = current_sort_values(cols)
    return NOT_SEEKABLE unless current_row

    seek_bound_id(cols, current_row, dir)
  end

  # `nil` here is a legitimate boundary (no next/prev row) -- distinct
  # from `seek_or`'s `current_row.nil?` case above, which falls back.
  #
  # Going backward, `LIMIT 1` needs the reversed order to land on the
  # tuple closest to current (largest one still less than it) rather
  # than the smallest tuple satisfying the predicate.
  def seek_bound_id(cols, current_row, dir)
    forward = dir == :next
    predicate = build_seek_predicate(cols, current_row, forward:)
    rel = scope.where(predicate)
    rel = rel.reverse_order unless forward
    rel.limit(1).pick(model.arel_table[:id])
  end

  # No order-shape restriction needed -- LIMIT 1 on the (possibly
  # reversed) ordered scope matches result_ids.first/.last for any
  # order, including aggregates and FIND_IN_SET. If result_ids is
  # already memoized -- a caller already checked how many results
  # there are, say -- reuse it instead of firing another query.
  def seek_edge_id(dir)
    return nil if need_letters
    return edge_id_from_result_ids(dir) if defined?(@result_ids)

    rel = dir == :first ? scope : scope.reverse_order
    rel.pick(model.arel_table[:id])
  end

  def edge_id_from_result_ids(dir)
    dir == :first ? result_ids.first : result_ids.last
  end
end
