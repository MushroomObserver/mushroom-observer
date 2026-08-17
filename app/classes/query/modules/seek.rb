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
#  ordering. See `#5101`.
#
##############################################################################

module Query::Modules::Seek
  # Not a real value -- distinguishes "fall back to the block" from a
  # legitimate `nil` boundary (no next/prev row) inside `seek_or`'s
  # transaction, where a bare `return`/`break` would be a non-local
  # exit Rails may interpret as a rollback signal.
  NOT_SEEKABLE = Object.new.freeze

  private

  # Allow-list: anything not a plain column Ascending/Descending
  # (aggregate, CASE, FindInSet) falls back to the full-array path.
  def seekable_order?
    return @seekable_order if defined?(@seekable_order)

    values = scope.order_values
    @seekable_order = values.present? && values.all? do |o|
      o.respond_to?(:direction) && o.expr.is_a?(Arel::Attributes::Attribute)
    end
  end

  # Current row's own sort-column values, to seed the keyset
  # comparison. A to-many join (e.g. Image.order_by(:confidence)) can
  # produce more than one row per id with different column values --
  # bail to the fallback rather than seed from an arbitrary one.
  def current_sort_values(cols)
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
    op = ascending == forward ? :gt : :lt
    leg = cols[idx].expr.public_send(op, current_row[idx])
    eq_prefix.reduce(leg) { |acc, eq| eq.and(acc) }
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
    return yield unless seekable_order?

    cols = scope.order_values
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
  # order, including aggregates and FIND_IN_SET.
  def seek_edge_id(dir)
    return nil if need_letters

    rel = dir == :first ? scope : scope.reverse_order
    rel.pick(model.arel_table[:id])
  end
end
