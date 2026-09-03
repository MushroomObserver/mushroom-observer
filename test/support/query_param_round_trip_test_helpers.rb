# frozen_string_literal: true

# Shared plumbing for the "every top-level param a Query subclass
# recognizes survives create_query_from_url_params" round-trip test --
# one test method per Query subclass, spread across the controller
# test files whose controllers use that Query. Proves the permit/
# alias/record-resolution layer, not each scope's filtering behavior,
# which test/classes/query/*_test.rb already covers via direct
# Query.lookup(:Model, attr: value) calls.
#
# Record-backed attrs (a bare Class or an Array of one) need a
# fixture id supplied via `overrides:`, since a synthetic id would
# hit resolve_record_backed_value's flash+redirect path instead of
# building a query. Deeply-nested structural Hash attrs (subqueries,
# a `names` lookup hash, `in_box`, a polymorphic `target`) are
# skipped automatically -- Query.enum_hash? tells a structural Hash
# apart from an enum one (`{ boolean: [true] }`, `{ string: [...] }`).
module QueryParamRoundTripTestHelpers
  def assert_all_top_level_params_survive(klass, model, overrides: {})
    klass.recognized_params.each do |key|
      attr = klass.param_aliases[key] || key
      next if structural_hash_attr?(klass.attribute_types[attr])

      assert_round_trip_param_survives(klass, model, key, overrides)
    end
  end

  private

  def structural_hash_attr?(type)
    type.accepts.is_a?(Hash) && !Query.enum_hash?(type.accepts)
  end

  # A param_alias always permits (and resolves) as a bare scalar,
  # regardless of the target attr's shape -- permit_filters puts every
  # alias in its `scalars` bucket. The attr's declared name permits
  # per its declared shape, so an Array-typed attr needs an Array
  # value there, or strong params silently drops it before it reaches
  # query.params.
  def assert_round_trip_param_survives(klass, model, key, overrides)
    attr = klass.param_aliases[key] || key
    aliased = klass.param_aliases.key?(key)
    type = klass.attribute_types[attr]
    value = round_trip_value_for(klass, type, attr, aliased, overrides)
    raw_params = ActionController::Parameters.new(key => value)

    query, = @controller.send(:create_query_from_url_params, model,
                              raw_params)

    assert_not_nil(query,
                   "?#{key}=#{value.inspect} failed to build a #{model} " \
                   "query")
    assert(query.params.key?(attr),
           "?#{key}=#{value.inspect} didn't survive into query.params " \
           "for #{model}: #{query.params.inspect}")
  end

  def round_trip_value_for(klass, type, attr, aliased, overrides)
    base = round_trip_base_value(klass, type, attr, overrides)
    return base if aliased || !type.accepts.is_a?(Array)

    Array(base)
  end

  # order_by defaults to the class's default_order -- guaranteed to
  # name a valid order_by_<key> scope, since validate_order_by! falls
  # back to it whenever a submitted key doesn't.
  def round_trip_base_value(klass, type, attr, overrides)
    return overrides[attr] if overrides.key?(attr)
    return klass.default_order.to_s if attr == :order_by

    accepts = type.accepts
    accepts = accepts.first if accepts.is_a?(Array)

    case accepts
    when :string then "test"
    when :boolean, :truthy then true
    when :float then 1.0
    when :date, :time then "2021-01-06"
    when Hash then round_trip_enum_value(accepts)
    else
      raise("No round-trip value or override defined for " \
            "#{klass}##{attr}: #{accepts.inspect}")
    end
  end

  def round_trip_enum_value(accepts)
    return true if accepts.keys.first == :boolean

    accepts.values.first.first
  end
end
