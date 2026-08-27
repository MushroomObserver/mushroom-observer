# frozen_string_literal: true

#  ==== QueryParamAliases
#  create_query_from_url_params:: Build a Query from raw request params,
#                                 resolving any registered `param_alias:`
#                                 index filter params along the way.
#
module ApplicationController::QueryParamAliases
  # Builds a Query for `model_symbol` from raw request params, resolving
  # any of the target Query's registered `param_alias:` params (e.g.
  # `?project=123`) into their query_attr (`projects: [123]`) before
  # creating the query. Permits only params the Query subclass
  # recognizes (its query_attr names plus their param_alias names) --
  # the generic replacement for a controller's `index_active_params`
  # allowlist.
  #
  # A record-backed value that doesn't resolve to an existing record
  # flashes and redirects -- to the calling controller's index by
  # default, or to the looked-up model's index when the attr declares
  # `redirect_to: :model_index` (matching `find_or_goto_index`) -- see
  # `resolve_record_backed_value`. Returns nil in that case, so check
  # the return value the same way you would any other index-redirecting
  # lookup.
  #
  # `always_index: true` is set automatically whenever a resolved attr
  # declares it (default true -- see `query_attr`), matching every
  # hand-written index filter param's existing `always_index: true` (a
  # single-result index should show the list, not auto-redirect to the
  # one result). A sort-order change has no such single-result-redirect
  # concern, so `by` alone doesn't trigger it.
  #
  # Returns `[query, display_opts]`, or nil if a record-backed value
  # failed to resolve.
  def create_query_from_url_params(model_symbol, raw_params)
    klass = "Query::#{model_symbol.to_s.pluralize}".constantize
    permitted = raw_params.permit(*klass.permit_filters).
                to_h.symbolize_keys
    resolved, force_index = resolve_query_param_records(klass, permitted)
    return nil unless resolved

    query = create_query(model_symbol, resolved)
    [query, { always_index: force_index }]
  end

  private

  # Resolves every permitted param -- whether it arrived under its attr
  # name or a `param_alias:` shortcut -- looking up record-backed attrs
  # (e.g. `projects: [Project]`) via `resolve_record_backed_value`,
  # which flashes and redirects on a bad id. Returns `[nil, false]`
  # (redirect already performed) the moment one fails to resolve;
  # otherwise `[resolved_params, force_index?]`, where `force_index?` is
  # true iff at least one resolved attr declares `always_index: true`
  # (record-backed or scalar).
  def resolve_query_param_records(klass, permitted)
    force_index = false
    # `keys` snapshots into a plain Array first -- resolving a param may
    # add a new key to `permitted` (e.g. renaming an alias), and
    # iterating the live Hash during that (`each_key`) raises.
    keys = permitted.keys
    keys.each do |key|
      attr = klass.param_aliases[key] || key
      outcome = resolve_one_query_param(klass, permitted, key, attr)
      return [nil, false] if outcome == :not_found

      force_index ||= outcome == :forces_index
    end
    [permitted, force_index]
  end

  # Resolves a single `key` in place on `permitted` (mutating it),
  # returning :forces_index, :no_force, or :not_found -- see
  # `resolve_query_param_records`. When `key` is an alias (`key != attr`),
  # it wins over an already-present value under the target attr name
  # (see Query.resolve_param_aliases for why), so it resolves and
  # overwrites unconditionally.
  def resolve_one_query_param(klass, permitted, key, attr)
    raw_value = permitted[key]
    permitted.delete(key) if key != attr
    model_class = alias_record_class(klass, attr)
    unless model_class
      permitted[attr] = wrap_if_array_attr(klass, attr, raw_value)
      # Scalar: opposite polarity from the record-backed branch below --
      # forces only when explicitly declared (`nil` doesn't force). Most
      # scalar attrs (e.g. `by`) have no opinion on this.
      always_index = klass.attribute_types[attr].always_index
      return always_index ? :forces_index : :no_force
    end

    resolve_record_backed_value(klass, permitted, attr, model_class,
                                raw_value)
  end

  # Looks up `raw_value` as `model_class`, flashing and redirecting on a
  # bad id -- to the calling controller's index by default, or to
  # `model_class`'s index when the attr declares
  # `redirect_to: :model_index` (see `query_attr`). :not_found on
  # failure; otherwise :forces_index, unless the attr opts out via
  # `always_index: false`, in which case :no_force. The record-lookup/
  # flash/redirect-on-bad-id behavior above is unconditional either way --
  # only whether a *found* record forces always_index changes.
  def resolve_record_backed_value(klass, permitted, attr, model_class,
                                  raw_value)
    type = klass.attribute_types[attr]
    record = if type.redirect_to == :model_index
               find_or_goto_index(model_class, raw_value)
             else
               find_alias_record_or_goto_own_index(model_class, raw_value)
             end
    return :not_found unless record

    # Caches the record so a later ivar-derivation step can reuse it
    # instead of fetching it again.
    cache_resolved_alias_record(attr, record)
    permitted[attr] = type.accepts.is_a?(Array) ? [record.id] : record.id
    # Record-backed: forces unless explicitly opted out (`always_index`
    # undeclared/nil still forces -- matches every hand-written index
    # filter param's existing behavior before this attr had one).
    type.always_index == false ? :no_force : :forces_index
  end

  def cache_resolved_alias_record(attr, record)
    @resolved_alias_records ||= {}
    @resolved_alias_records[attr] = record
  end

  # Like `find_or_goto_index` (ApplicationController::Indexes), but
  # redirects back to the calling controller's own index action instead
  # of the looked-up model's -- a bad `?by_user=<id>` on `/species_lists`
  # redirects back to `/species_lists`, not to `/users`. Omitting
  # `controller:` keeps `redirect_with_query` within whichever
  # controller/namespace is handling this request.
  def find_alias_record_or_goto_own_index(model_class, id)
    finder = if model_class.respond_to?(:show_includes)
               model_class.show_includes
             else
               model_class
             end
    finder.find_by(id: id) || flash_alias_not_found_and_goto_own_index(
      model_class, id
    )
  end

  def flash_alias_not_found_and_goto_own_index(model_class, id)
    flash_error(:runtime_object_not_found.t(id: id || "0",
                                            type: model_class.type_tag))
    redirect_with_query(action: :index)
    nil
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
