# frozen_string_literal: true

#  ==== QueryParamAliases
#  create_query_from_url_params:: Build a Query from raw request params,
#                                 resolving any registered `param_alias:`
#                                 shortcut params along the way.
#
module ApplicationController::QueryParamAliases
  # Builds a Query for `model_symbol` from raw request params, resolving
  # any of the target Query's registered `param_alias:` params (e.g.
  # `?project=123`) into their query_attr (`projects: [123]`) before
  # creating the query. Permits only params the Query subclass
  # recognizes (its query_attr names plus their param_alias names) -- the
  # generic replacement for a controller's own `index_active_params`
  # allowlist.
  #
  # A param_alias'd id that doesn't resolve to an existing record flashes
  # and redirects to the model's own index, via the same
  # `find_or_goto_index` used by every hand-written shortcut method --
  # returns nil in that case, so check the return value the same way you
  # would any other `find_or_goto_index`-backed lookup.
  #
  # `always_index: true` is set automatically whenever a record-backed
  # param_alias resolved a param (e.g. `project`, not the scalar `by`
  # sort alias), matching every hand-written shortcut's existing
  # `always_index: true` (an aliased single-result index should show the
  # list, not auto-redirect to the one result). A sort-order change has
  # no such single-result-redirect concern, so `by` alone doesn't trigger
  # it.
  #
  # Returns `[query, display_opts]`, or nil if a param_alias'd id failed to
  # resolve.
  def create_query_from_url_params(model_symbol, raw_params)
    klass = "Query::#{model_symbol.to_s.pluralize}".constantize
    permitted = raw_params.permit(*klass.permit_filters).
                to_h.symbolize_keys
    aliased_keys = klass.param_aliases.keys & permitted.keys
    resolved, record_backed = resolve_param_alias_records(
      klass, permitted, aliased_keys
    )
    return nil unless resolved

    query = create_query(model_symbol, resolved)
    [query, { always_index: record_backed }]
  end

  private

  # Resolves each `aliased_keys` entry to its target query_attr value,
  # looking up record-backed attrs (e.g. `projects: [Project]`) via
  # `find_or_goto_index` -- which flashes and redirects on a bad id, same
  # as every hand-written shortcut method. Returns `[nil, false]`
  # (redirect already performed) the moment one fails to resolve;
  # otherwise `[resolved_params, record_backed?]`, where `record_backed?`
  # is true iff at least one resolved alias was record-backed.
  def resolve_param_alias_records(klass, permitted, aliased_keys)
    record_backed = false
    aliased_keys.each do |alias_key|
      outcome = resolve_one_param_alias(klass, permitted, alias_key)
      return [nil, false] if outcome == :not_found

      record_backed ||= outcome == :record_backed
    end
    [permitted, record_backed]
  end

  # Resolves a single `alias_key` in place on `permitted` (mutating it),
  # returning :scalar, :record_backed, or :not_found -- see
  # `resolve_param_alias_records`. The alias wins over an already-present
  # value under the target attr name (see Query.resolve_param_aliases for
  # why), so it resolves and overwrites unconditionally.
  #
  # A found record still returns :scalar (not forcing always_index) when
  # the attr declares `always_index: false` -- the record-lookup/flash/
  # redirect-on-bad-id behavior below is unconditional either way, only
  # whether a *found* record forces always_index changes.
  def resolve_one_param_alias(klass, permitted, alias_key)
    attr = klass.param_aliases[alias_key]
    raw_value = permitted.delete(alias_key)
    model_class = alias_record_class(klass, attr)
    unless model_class
      permitted[attr] = wrap_if_array_attr(klass, attr, raw_value)
      return :scalar
    end

    resolve_record_backed_alias(klass, permitted, attr, model_class, raw_value)
  end

  # Looks up `raw_value` as `model_class`, flashing and redirecting on a
  # bad id (`find_or_goto_index`). :not_found on failure; otherwise
  # :record_backed, unless the attr opts out via `always_index: false`
  # (see `resolve_one_param_alias`), in which case :scalar.
  def resolve_record_backed_alias(klass, permitted, attr, model_class,
                                  raw_value)
    return :not_found unless (record = find_or_goto_index(model_class,
                                                          raw_value))

    accepts = klass.attribute_types[attr].accepts
    permitted[attr] = accepts.is_a?(Array) ? [record.id] : record.id
    klass.attribute_types[attr].always_index ? :record_backed : :scalar
  end

  # The ActiveRecord model class a query_attr's `accepts` type is backed
  # by, or nil when the attr isn't record-backed (e.g. `order_by`'s
  # `:string`, aliased from `by` -- no lookup needed, passed through raw).
  def alias_record_class(klass, attr)
    accepts = klass.attribute_types[attr].accepts
    model_class = accepts.is_a?(Array) ? accepts.first : accepts
    model_class if model_class.is_a?(Class) && model_class < ActiveRecord::Base
  end

  # Wraps `value` in an Array when the target attr itself accepts an
  # Array (e.g. `[:time]`) -- mirrors Query.resolve_param_aliases so a
  # non-record-backed alias (dates, floats, ...) gets the same
  # scalar-to-array treatment a record-backed one already does.
  def wrap_if_array_attr(klass, attr, value)
    accepts = klass.attribute_types[attr].accepts
    accepts.is_a?(Array) && !value.is_a?(Array) ? [value] : value
  end
end
