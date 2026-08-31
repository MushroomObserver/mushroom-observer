# frozen_string_literal: true

#  ==== QueryParams
#  create_query_from_url_params:: Build a Query from raw request params.
#
module ApplicationController::QueryParams
  # Builds a Query for `model_symbol` from raw request params. Resolves
  # `param_alias:` params into their query_attr (`?project=123` ->
  # `projects: [123]`) and permits only params the Query subclass
  # recognizes.
  #
  # A bad record-backed id flashes and redirects (see
  # `resolve_record_backed_value`); returns nil in that case.
  #
  # `always_index` forces true for a resolved record-backed attr unless
  # it opts out with `always_index: false`; a scalar attr is the
  # opposite, forcing only when explicitly declared `true` (see
  # `QueryParamType#always_index`).
  #
  # Returns `[query, display_opts]`, or nil on a bad id.
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

  # Returns `[nil, false]` (redirect already performed) the moment a
  # record-backed value fails to resolve; otherwise `[resolved_params,
  # force_index?]`.
  def resolve_query_param_records(klass, permitted)
    force_index = false
    # Snapshot into an Array -- resolving a param can add a new key to
    # `permitted`, and iterating the live Hash (`each_key`) would raise.
    keys = permitted.keys
    keys.each do |key|
      attr = klass.param_aliases[key] || key
      outcome = resolve_one_query_param(klass, permitted, key, attr)
      return [nil, false] if outcome == :not_found

      force_index ||= outcome == :forces_index
    end
    [permitted, force_index]
  end

  # Resolves a single `key` on `permitted` (mutating it), returning
  # :forces_index, :no_force, or :not_found. An alias (`key != attr`)
  # overwrites any existing value under `attr` -- see
  # Query.resolve_param_aliases for why.
  def resolve_one_query_param(klass, permitted, key, attr)
    raw_value = permitted[key]
    permitted.delete(key) if key != attr
    model_class = alias_record_class(klass, attr)
    return resolve_scalar_query_param(klass, permitted, attr, raw_value) unless
      model_class

    if raw_value.is_a?(Array) && raw_value.size > 1
      return resolve_multi_id_query_param(permitted, attr, raw_value)
    end

    raw_value = raw_value.first if raw_value.is_a?(Array)
    resolve_record_backed_value(klass, permitted, attr, model_class,
                                raw_value)
  end

  # Scalar: opposite polarity from the record-backed branch -- forces
  # only when explicitly declared (`nil` doesn't force). Most scalar
  # attrs (e.g. `by`) have no opinion on this.
  def resolve_scalar_query_param(klass, permitted, attr, raw_value)
    permitted[attr] = wrap_if_array_attr(klass, attr, raw_value)
    always_index = klass.attribute_types[attr].always_index
    always_index ? :forces_index : :no_force
  end

  # Multiple ids skip single-record lookup -- `find_by(id: [...])`
  # would only return one match. The underlying scope (e.g.
  # Lookup::Projects) already resolves a list.
  def resolve_multi_id_query_param(permitted, attr, raw_value)
    permitted[attr] = raw_value
    :no_force
  end

  # Looks up `raw_value` as `model_class`, flashing and redirecting on a
  # bad id -- to `model_class`'s index if the attr declares
  # `redirect_to: :model_index`, else the calling controller's index.
  # :not_found on failure; otherwise :forces_index, unless the attr
  # opts out via `always_index: false`.
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
    # Record-backed: forces unless explicitly opted out.
    type.always_index == false ? :no_force : :forces_index
  end

  def cache_resolved_alias_record(attr, record)
    @resolved_alias_records ||= {}
    @resolved_alias_records[attr] = record
  end

  # Like `find_or_goto_index`, but redirects to the calling controller's
  # index instead of the looked-up model's (a bad `?by_user=<id>` on
  # `/species_lists` stays on `/species_lists`, not `/users`).
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

  # Wraps `value` in an Array when the attr itself is Array-typed
  # (e.g. `[:time]`).
  def wrap_if_array_attr(klass, attr, value)
    accepts = klass.attribute_types[attr].accepts
    accepts.is_a?(Array) && !value.is_a?(Array) ? [value] : value
  end
end
