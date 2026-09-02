# frozen_string_literal: true

require("test_helper")
require("query_extensions")

class QueryTest < UnitTestCase
  include QueryExtensions

  ##############################################################################

  def test_basic
    assert_raises(NameError) { Query.lookup(:BogusModel) }
    # All queries assumed to be :all by default.
    # assert_raises(NameError) { Query.lookup(:Name, :bogus) }

    query = Query.lookup(:Observation)
    assert(query.record.new_record?)
    assert_equal("Observation", query.model.to_s)
    assert_equal(:observation, query.type_tag)
    # Test QueryRecord.model? method:
    query.record.save
    assert(QueryRecord.model?(:Observation, query.record.id))

    query2 = Query.lookup_and_save(:Observation)
    assert_not(query2.record.new_record?)
    assert_equal(query, query2)
    assert_equal(query2, Query.safe_find(query2.id))

    query3 = Query.lookup_and_save(:Observation, by_users: [users(:rolf).id])
    assert_not(query3.record.new_record?)
    assert_not_equal(query2, query3)
    assert_equal(query3, Query.safe_find(query3.id))
    # Test QueryRecord.check_param method:
    assert_equal(
      [users(:rolf).id],
      QueryRecord.check_param(:by_users, query3.record.id)
    )
    # Be sure the permalink has been set on all of these
    assert(QueryRecord.safe_find(query.id).permalink)
    assert(QueryRecord.safe_find(query2.id).permalink)
    assert(QueryRecord.safe_find(query3.id).permalink)

    assert_nil(Query.safe_find(0))

    updated_at = query2.record.updated_at
    assert_equal(0, query2.record.access_count)
    query3 = Query.lookup(:Observation)
    assert_equal(query2.serialize, query3.serialize)
    assert_equal(updated_at.to_s, query3.record.updated_at.to_s)
    assert_equal(0, query3.record.access_count)
  end

  # Regression test for #5188: an emoji in a query param crashed
  # Query.lookup because QueryRecord#description was utf8mb3.
  def test_lookup_and_save_with_emoji
    query = Query.lookup_and_save(:Image, pattern: "🍄")
    assert_not(query.record.new_record?,
               "Query with an emoji param should save its QueryRecord")

    found = Query.lookup(:Image, pattern: "🍄")
    assert_equal(query.record.id, found.record.id,
                 "Re-looking-up the same emoji pattern should find the " \
                 "same QueryRecord instead of erroring or duplicating it")
  end

  def assert_validation_errors(query)
    assert_false(query.valid)
    assert_not_empty(query.validation_errors)
  end

  def test_validate_params_one
    # Should ignore params it doesn't recognize
    assert_equal(Query.lookup(:Name, xxx: true), Query.lookup(:Name))
    assert_validation_errors(Query.lookup(:Name, order_by: [1, 2, 3]))
    assert_validation_errors(Query.lookup(:Name, order_by: true))
    assert_equal("id", Query.lookup(:Name, order_by: :id).params[:order_by])

    assert_equal(
      :include,
      Query.lookup(:Name, misspellings: :include).params[:misspellings]
    )
    assert_equal(
      :include,
      Query.lookup(:Name, misspellings: "include").params[:misspellings]
    )
    assert_validation_errors(Query.lookup(:Name, misspellings: "bogus"))
    assert_validation_errors(Query.lookup(:Name, misspellings: true))
    assert_validation_errors(Query.lookup(:Name, misspellings: 123))
  end

  def test_validate_params_boolean
    assert_equal(
      true,
      Query.lookup(:Name, has_synonyms: "true").params[:has_synonyms]
    )
    assert_validation_errors(Query.lookup(:Name, has_synonyms: "bogus"))
  end

  def test_validate_params_date
    assert_equal(
      ["2021-01-06"],
      Query.lookup(:Observation, date: "Jan 06, 2021").params[:date]
    )
    assert_equal(
      [nil],
      Query.lookup(:Observation, date: "0").params[:date]
    )
    assert_validation_errors(Query.lookup(:Observation, date: "fi"))
  end

  def test_validate_params_datetime
    assert_equal(
      ["2021-01-06-00-00-00"],
      Query.lookup(:Observation, created_at: "Jan 06, 2021").params[:created_at]
    )
    assert_equal(
      [nil],
      Query.lookup(:Observation, created_at: "0").params[:created_at]
    )
    assert_validation_errors(Query.lookup(:Observation, created_at: "fi"))
  end

  def test_validate_params_order_by_unsupported
    query = Query.lookup(:Name, order_by: "totally_bogus_sort_key")
    assert_validation_errors(query)
    # The bad value must not survive validation -- otherwise it reaches
    # AbstractModel::OrderingScopes#order_by's dispatcher, which silently
    # falls back to `all` (id: :desc) instead of the model's own
    # default_order.
    assert_nil(query.params[:order_by],
               "Invalid order_by should be cleared, not left in params")
    assert_equal(:name, query.default_order,
                 "Should fall back to Query::Names.default_order")
  end

  def test_validate_params_instances_users
    fungi = names(:fungi)
    license = License.first
    assert_validation_errors(Query.lookup(:Image, by_users: license))
    assert_validation_errors(Query.lookup(:Image, by_users: :bogus))
    assert_validation_errors(Query.lookup(:Image, by_users: fungi))
    assert_equal([rolf.id],
                 Query.lookup(:Image, by_users: rolf).params[:by_users])
    assert_equal([rolf.id],
                 Query.lookup(:Image, by_users: rolf.id).params[:by_users])
    assert_equal([rolf.id],
                 Query.lookup(:Image, by_users: rolf.id.to_s).params[:by_users])
    assert_equal([rolf.login],
                 Query.lookup(:Image, by_users: rolf.login).params[:by_users])

    brand_new = User.new(name: "Not in db", login: "evanescent")
    assert_validation_errors(Query.lookup(:Image, by_users: brand_new))
  end

  def test_validate_params_id_in_set
    # Oops, this query is generic,
    # doesn't know to require Name instances here.
    # assert_validation_errors(Query.lookup(:Name, id_in_set: rolf))
    assert_validation_errors(Query.lookup(:Image, id_in_set: "one"))
    assert_validation_errors(Query.lookup(:Image, id_in_set: "1,2,3"))
    assert_validation_errors(Query.lookup(:Image, id_in_set: "Fungi"))
    assert_equal(
      [names(:fungi).id],
      Query.lookup(:Name, id_in_set: names(:fungi).id.to_s).params[:id_in_set]
    )

    # assert_raises(RuntimeError) { Query.lookup(:User) }
    assert_equal([], Query.lookup(:User, id_in_set: []).params[:id_in_set])
    assert_equal(
      [rolf.id], Query.lookup(:User, id_in_set: rolf.id).params[:id_in_set]
    )
    ids = [rolf.id, mary.id]
    assert_equal(ids, Query.lookup(:User, id_in_set: ids).params[:id_in_set])
    assert_equal(
      [1, 2], Query.lookup(:User, id_in_set: %w[1 2]).params[:id_in_set]
    )
    assert_equal(
      ids, Query.lookup(:User, id_in_set: ids.map(&:to_s)).params[:id_in_set]
    )
    assert_equal(
      [rolf.id], Query.lookup(:User, id_in_set: rolf).params[:id_in_set]
    )
    assert_equal(
      ids, Query.lookup(:User, id_in_set: [rolf, mary]).params[:id_in_set]
    )
    rando_set = [rolf, mary.id, junk.id.to_s]
    assert_equal(
      [rolf.id, mary.id, junk.id],
      Query.lookup(:User, id_in_set: rando_set).params[:id_in_set]
    )
  end

  def test_validate_params_pattern
    assert_validation_errors(Query.lookup(:Name, pattern: true))
    assert_validation_errors(Query.lookup(:Name, pattern: [1, 2, 3]))
    assert_validation_errors(Query.lookup(:Name, pattern: rolf))
    assert_equal("123",
                 Query.lookup(:Name, pattern: 123).params[:pattern])
    assert_equal("rolf",
                 Query.lookup(:Name, pattern: "rolf").params[:pattern])
    assert_equal("rolf",
                 Query.lookup(:Name, pattern: :rolf).params[:pattern])
  end

  def test_validate_params_hashes
    box = { north: 48.5798, south: 48.558, east: -123.4307, west: -123.4763 }
    assert_equal(box, Query.lookup(:Location, in_box: box).params[:in_box])
    assert_raises(TypeError) { Query.lookup(:Location, in_box: "one") }
    box = { north: "with", south: 48.558, east: -123.4307, west: -123.4763 }
    assert_validation_errors(Query.lookup(:Location, in_box: box))
    box = { south: 48.558, east: -123.4307, west: -123.4763 }
    assert_validation_errors(Query.lookup(:Location, in_box: box))
  end

  # The following exercise defensive checks against malformed
  # attribute_type declarations on a Query subclass itself -- not
  # reachable through ordinary user-supplied params, since every real
  # Query class declares its attribute_types correctly. Call the
  # private validators directly to cover the "this should never
  # happen" branches.
  def test_scalar_validate_rejects_unrecognized_param_type
    query = Query.lookup(:Name)
    query.send(:scalar_validate, :some_param, "val", 42)
    assert_includes(query.validation_errors.map(&:first),
                    :query_validation_invalid_declaration)
  end

  def test_validate_class_param_rejects_non_active_record_class
    query = Query.lookup(:Name)
    query.send(:validate_class_param, :some_param, "val", String)
    assert_includes(query.validation_errors.map(&:first),
                    :query_validation_unknown_class_param)
  end

  def test_validate_subquery_rejects_wrong_key_count
    query = Query.lookup(:Name)
    query.send(:validate_subquery, :some_param, {}, { a: 1, b: 2 })
    assert_includes(query.validation_errors.map(&:first),
                    :query_validation_invalid_subquery)
  end

  def test_validate_enum_rejects_wrong_key_count
    query = Query.lookup(:Name)
    query.send(:validate_enum, :some_param, "val", { a: 1, b: 2 })
    assert_includes(query.validation_errors.map(&:first),
                    :query_validation_invalid_enum_keys)
  end

  def test_validate_enum_rejects_non_array_set
    query = Query.lookup(:Name)
    query.send(:validate_enum, :some_param, "val", { string: "nope" })
    assert_includes(query.validation_errors.map(&:first),
                    :query_validation_invalid_enum_not_array)
  end

  def test_google_parse
    assert_equal([["blah"]], SearchParams.new(phrase: "blah").goods)
    assert_equal([%w[foo bar]], SearchParams.new(phrase: "foo OR bar").goods)
    assert_equal([["one"], %w[foo bar], ["two"]],
                 SearchParams.new(phrase: "one foo OR bar two").goods)
    assert_equal([["one"], ["foo", "bar", "quoted phrase", "-gar"], ["two"]],
                 SearchParams.new(
                   phrase: 'one foo OR bar OR "quoted phrase" OR -gar two'
                 ).goods)
    assert_equal([], SearchParams.new(phrase: "-bad").goods)
    assert_equal(["bad"], SearchParams.new(phrase: "-bad").bads)
    assert_equal(["bad"], SearchParams.new(phrase: "foo -bad bar").bads)
    assert_equal(["bad wolf"],
                 SearchParams.new(phrase: 'foo -"bad wolf" bar').bads)
    assert_equal(["bad wolf", "foo", "bar"],
                 SearchParams.new(phrase: '-"bad wolf" -foo -bar').bads)
  end

  def test_order_by_has_by_param_alias
    assert_equal(:order_by, Query::Observations.param_aliases[:by])
  end

  def test_recognized_params_includes_attrs_and_aliases
    recognized = Query::Observations.recognized_params

    assert_includes(recognized, :order_by)
    assert_includes(recognized, :projects)
    assert_includes(recognized, :by)
  end

  def test_resolve_param_aliases_renames_scalar_alias
    assert_equal(
      { order_by: "date" },
      Query::Observations.resolve_param_aliases(by: "date")
    )
  end

  def test_resolve_param_aliases_ignores_unaliased_params
    assert_equal(
      { projects: [1] },
      Query::Observations.resolve_param_aliases(projects: [1])
    )
  end

  def test_resolve_param_aliases_wraps_scalar_value_for_array_attr
    subclass = Class.new(Query::Observations) do
      query_attr(:test_ids, [Observation], param_alias: :test_id)
    end

    assert_equal(
      { test_ids: [123] },
      subclass.resolve_param_aliases(test_id: 123)
    )
    assert_equal(
      { test_ids: [123, 456] },
      subclass.resolve_param_aliases(test_id: [123, 456])
    )
  end

  # A singular alias represents a more specific, more recently-expressed
  # choice than a broader value already present under the target attr
  # (e.g. a "sort by date" link clicked while a saved query already
  # carries its own order_by) -- it overwrites, not yields.
  def test_resolve_param_aliases_alias_wins_over_present_attr
    subclass = Class.new(Query::Observations) do
      query_attr(:test_ids, [Observation], param_alias: :test_id)
    end

    resolved = subclass.resolve_param_aliases(test_id: 999, test_ids: [1])

    assert_equal({ test_ids: [999] }, resolved)
  end

  def test_create_query_resolves_by_alias_end_to_end
    query = Query.create_query(:Observation, by: "date")

    assert_equal("date", query.params[:order_by])
  end

  def test_permit_filters_categorizes_by_accepts_shape
    filters = Query::Observations.permit_filters
    containers = filters.last

    # Scalar attrs (and the :by alias) are bare symbols.
    assert_includes(filters, :order_by)
    assert_includes(filters, :by)
    assert_includes(filters, :needs_naming) # scalar :truthy
    # An "enum" hash (`{ boolean: [true] }`/`{ string: [...] }`) is a
    # bare scalar from the URL's perspective, not a nested hash --
    # permitting it as `attr: {}` would strip a request's scalar
    # value entirely (confirmed: this broke Names#has_observations
    # until permit_filters learned to tell enum hashes apart from
    # structural ones).
    assert_includes(filters, :location_undefined)
    # Array-typed attrs permit both ways: bare symbol for the scalar
    # URL form (`?projects=123`), `attr: []` for the array form
    # (`?projects[]=123`). Array-only filters silently dropped the
    # scalar form (the Name-show `?this_name=<id>` links).
    assert_equal([], containers[:by_users])
    assert_equal([], containers[:projects])
    assert_includes(filters, :by_users)
    assert_includes(filters, :projects)
    assert_includes(filters, :this_name)
    # Structural hash-typed attrs, including subqueries, permit via
    # `attr: {}`.
    assert_equal({}, containers[:names])
    assert_equal({}, containers[:in_box])
    assert_equal({}, containers[:location_query])
  end

  def test_permit_filters_permits_array_typed_param_as_scalar
    raw = ActionController::Parameters.new(this_name: "31346",
                                           projects: "17")

    permitted = raw.permit(*Query::Observations.permit_filters)

    assert_equal("31346", permitted[:this_name])
    assert_equal("17", permitted[:projects])
  end

  def test_permit_filters_permits_enum_hash_typed_param_as_scalar
    raw = ActionController::Parameters.new(location_undefined: "true")

    permitted = raw.permit(*Query::Observations.permit_filters)

    assert_equal("true", permitted[:location_undefined])
  end

  def test_permit_filters_permits_array_typed_param
    raw = ActionController::Parameters.new(by_users: %w[1 2])

    permitted = raw.permit(*Query::Observations.permit_filters)

    assert_equal(%w[1 2], permitted[:by_users])
  end

  def test_permit_filters_permits_hash_typed_param
    raw = ActionController::Parameters.new(
      in_box: { north: "1.0", south: "2.0", east: "3.0", west: "4.0" }
    )

    permitted = raw.permit(*Query::Observations.permit_filters)

    assert_equal("1.0", permitted[:in_box][:north])
  end

  def test_permit_filters_permits_multilevel_nested_subquery
    raw = ActionController::Parameters.new(
      location_query: {
        pattern: "California",
        observation_query: {
          by_users: ["1"],
          has_public_lat_lng: "true"
        }
      },
      bogus_toplevel: "haxx"
    )

    permitted = raw.permit(*Query::Observations.permit_filters)

    assert_not(permitted.key?(:bogus_toplevel))
    nested = permitted[:location_query][:observation_query]
    assert_equal(["1"], nested[:by_users])
    assert_equal("true", nested[:has_public_lat_lng])
  end

  def test_permit_filters_still_strips_unrecognized_top_level_param
    raw = ActionController::Parameters.new(by_users: ["1"], evil: "haxx")

    permitted = raw.permit(*Query::Observations.permit_filters)

    assert_not(permitted.key?(:evil))
  end

  def test_create_query_builds_valid_query_from_multilevel_nested_subquery
    query = Query.create_query(
      :Observation,
      location_query: {
        pattern: "California",
        observation_query: { by_users: ["1"], has_public_lat_lng: "true" }
      }
    )

    assert(query.valid?)
    assert_empty(query.validation_errors)
    location_subquery = query.subqueries[:location_query]
    assert_equal("Query::Locations", location_subquery.class.name)
    observation_subquery = location_subquery.subqueries[:observation_query]
    assert_equal([1], observation_subquery.params[:by_users])
    assert_equal(true, observation_subquery.params[:has_public_lat_lng])
  end

  def test_default_order_falls_back_to_class_default_without_override
    assert_equal(:date, Query.create_query(:Observation).default_order)
  end

  def test_default_order_uses_attr_override_when_attr_present
    subclass = Class.new(Query::Observations) do
      query_attr(:test_flag, :boolean, default_order: :updated_at)
    end
    with_flag = subclass.new(test_flag: true)
    with_flag.params = with_flag.attributes.compact
    with_flag.valid = with_flag.valid?
    without_flag = subclass.new(test_flag: nil)
    without_flag.params = without_flag.attributes.compact
    without_flag.valid = without_flag.valid?

    assert_equal(:updated_at, with_flag.default_order)
    assert_equal(:date, without_flag.default_order)
  end

  # `false` is a meaningfully-set, active filter value for a boolean
  # attr -- not "absent". `false.blank?` is true in Rails, so a
  # `.blank?` presence check here would wrongly skip the override.
  def test_default_order_uses_attr_override_when_attr_explicitly_false
    subclass = Class.new(Query::Observations) do
      query_attr(:test_flag, :boolean, default_order: :updated_at)
    end
    with_false_flag = subclass.new(test_flag: false)
    with_false_flag.params = with_false_flag.attributes.compact
    with_false_flag.valid = with_false_flag.valid?

    assert_equal(:updated_at, with_false_flag.default_order)
  end

  def test_position_pagination_at
    query = Query.lookup(:Observation)
    ids = query.result_ids
    pagination_data = PaginationData.new(num_per_page: 1)

    query.position_pagination_at(ids[2], pagination_data)

    assert_equal(3, pagination_data.number)
  end

  def test_lookup
    assert_equal(0, QueryRecord.count)

    q1 = Query.lookup_and_save(:Observation)
    assert_equal(1, QueryRecord.count)

    Query.lookup_and_save(:Observation, pattern: "blah")
    assert_equal(2, QueryRecord.count)

    # New because params are different from q1.
    q3 = Query.lookup_and_save(:Observation, order_by: :id)
    assert_equal(3, QueryRecord.count)

    # Not new because it is explicitly defaulted before validate.
    q4 = Query.lookup_and_save(:Observation)
    assert_equal(3, QueryRecord.count)
    assert_equal(q1, q4, QueryRecord.count)

    # Ditto default.
    q5 = Query.lookup_and_save(:Observation, order_by: :id)
    assert_equal(3, QueryRecord.count)
    assert_equal(q3, q5, QueryRecord.count)

    # New pattern is new query.
    Query.lookup_and_save(:Observation, pattern: "new blah")
    assert_equal(4, QueryRecord.count)

    # Old pattern but new order.
    Query.lookup_and_save(:Observation, pattern: "blah", order_by: :date)
    assert_equal(5, QueryRecord.count)

    # Identical, even though :order_by is explicitly set in one.
    Query.lookup_and_save(:Observation, pattern: "blah")
    assert_equal(5, QueryRecord.count)

    # Identical query, but new query because order given explicitly.  Order is
    # not given default until query is initialized, thus default not stored in
    # params, so lookup doesn't know about it.
    Query.lookup_and_save(:Observation, order_by: :date)
    assert_equal(6, QueryRecord.count)

    # Just a sanity check.
    Query.lookup_and_save(:Name)
    assert_equal(7, QueryRecord.count)
  end

  ##############################################################################
  #
  #  :section: Query Mechanics
  #
  ##############################################################################

  def test_results
    query = Query.lookup(:User, order_by: :id)

    assert_equal(
      Set.new,
      Set.new([rolf.id, mary.id, junk.id, dick.id, katrina.id, roy.id]) -
        query.result_ids
    )
    assert_equal("scientific", roy.location_format)
    assert_equal(
      Set.new,
      Set.new([rolf, mary, junk, dick, katrina, roy]) - query.results
    )
    assert_equal(User.reorder(id: :asc).find_index(junk), query.index(junk))
    assert_equal(User.reorder(id: :asc).find_index(dick), query.index(dick))
    assert_equal(User.reorder(id: :asc).find_index(mary), query.index(mary))

    # Verify that it's getting all this crap from cache.
    query.result_ids = [rolf.id, junk.id, katrina.id, 100]
    assert_equal([rolf, junk, katrina], query.results)

    # Should be able to set it this way, too.
    query.results = [dick, mary, rolf]
    assert_equal(3, query.num_results)
    assert_equal([dick.id, mary.id, rolf.id], query.result_ids)
    assert_equal([dick, mary, rolf], query.results)
    assert_equal(1, query.index(mary))
    assert_equal(2, query.index(rolf))
  end

  def paginate_test_setup(number, num_per_page)
    @names = Name.reorder(id: :asc).order(:id)
    @pagination_data = PaginationData.new(number: number,
                                          num_per_page: num_per_page)
    @query = Query.lookup(:Name, misspellings: :include, order_by: :id)
  end

  def paginate_test(number, num_per_page, expected_nths)
    paginate_test_setup(number, num_per_page)
    paginate_assertions(number, num_per_page, expected_nths)
  end

  # parameters are the ordinals of objects which have been ordered by id
  # E.g., 1 corresponds to Name.order(:id).first
  def paginate_assertions(number, num_per_page, expected_nths)
    from_nth = (number - 1) * num_per_page
    to_nth = from_nth + num_per_page - 1
    name_ids = @names.pluck(:id)

    assert_equal(
      expected_nths,
      @query.paginate_ids(@pagination_data).map do |id|
        name_ids.index(id) + 1
      end
    )
    assert_equal(@names.size, @pagination_data.num_total)
    assert_name_arrays_equal(@names[from_nth..to_nth],
                             @query.paginate(@pagination_data))
  end

  def test_paginate_start
    paginate_test(1, 4, [1, 2, 3, 4])
  end

  def test_paginate_middle
    MO.debugger_flag = true
    paginate_test(2, 4, [5, 6, 7, 8])
  end

  def paginate_test_letter_setup(number, num_per_page)
    paginate_test_setup(number, num_per_page)
    @query.need_letters = true
    @letters = @names.map { |n| n.text_name[0, 1] }.uniq.sort
  end

  def test_paginate_need_letters
    paginate_test_letter_setup(1, 4)
    paginate_assertions(1, 4, [1, 2, 3, 4])
    assert_equal(@letters, @pagination_data.used_letters.sort)
  end

  def test_paginate_ells
    paginate_test_letter_setup(2, 3)
    @pagination_data = PaginationData.new(number: 2, num_per_page: 3,
                                          letter: "L")
    # Make sure we have a bunch of Lactarii, Leptiotas, etc.
    @ells = @names.select { |n| n.text_name[0, 1] == "L" }
    assert(@ells.length >= 9)
    assert_equal(@ells[3..5].map(&:id), @query.paginate_ids(@pagination_data))
    assert_equal(@letters, @pagination_data.used_letters.sort)
    assert_name_arrays_equal(@ells[3..5], @query.paginate(@pagination_data))
  end

  def test_eager_instantiator
    query = Query.lookup(:Observation)
    ids = query.result_ids

    first = query.instantiate_results([ids[0]]).first
    assert_not(first.images.loaded?)

    first = query.instantiate_results([ids[0]], include: :images).first
    assert_not(first.images.loaded?)

    # Have to test it on a different one, because first is now cached.
    second = query.instantiate_results([ids[1]], include: :images).first
    assert(second.images.loaded?)

    # Or we can clear out the cache and it will work...
    query.clear_cache
    first = query.instantiate_results([ids[0]], include: :images).first
    assert(first.images.loaded?)
  end

  ##############################################################################
  #
  #  :section: Sequence Operators
  #
  ##############################################################################

  def test_current
    query = Query.lookup(:Name)
    @fungi = names(:fungi)
    @agaricus = names(:agaricus)
    @peltigera = names(:peltigera)

    assert_nil(query.current_id)
    assert_nil(query.current)

    query.current_id = @fungi.id
    assert_equal(@fungi.id, query.current_id)
    assert_equal(@fungi, query.current)

    query.current = @agaricus
    assert_equal(@agaricus.id, query.current_id)
    assert_equal(@agaricus, query.current)

    query.current = @peltigera.id
    assert_equal(@peltigera.id, query.current_id)
    assert_equal(@peltigera, query.current)
  end

  def test_next_and_prev
    query = Query.lookup(:Name, misspellings: :include, order_by: :id)
    @names = Name.reorder(id: :asc)

    query.current = @names[2]
    assert_equal(@names[1].id, query.prev_id)
    assert_equal(query, query.prev)
    assert_equal(@names[1].id, query.current_id)
    assert_equal(@names[0].id, query.prev_id)
    assert_equal(query, query.prev)
    assert_equal(@names[0].id, query.current_id)
    assert_nil(query.prev_id)
    assert_nil(query.prev)
    assert_equal(@names[0].id, query.current_id)
    assert_equal(@names[1].id, query.next_id)
    assert_equal(query, query.next)
    assert_equal(@names[1].id, query.current_id)
    assert_equal(@names[2].id, query.next_id)
    assert_equal(query, query.next)
    assert_equal(@names[2].id, query.current_id)
    assert_equal(@names[-1].id, query.last_id)
    assert_equal(query, query.last)
    assert_equal(@names[-1].id, query.current_id)
    assert_equal(query, query.last)
    assert_equal(@names[-1].id, query.current_id)
    assert_nil(query.next_id)
    assert_nil(query.next)
    assert_equal(@names[-1].id, query.current_id)
    assert_equal(@names[0].id, query.first_id)
    assert_equal(query, query.first)
    assert_equal(@names[0].id, query.current_id)
    assert_equal(query, query.first)
    assert_equal(@names[0].id, query.current_id)
    query.reset
    assert_equal(@names[2].id, query.current_id)
  end

  # Test env's cache_store is :null_store -- every fetch/read/write is a
  # no-op there, so tests exercising real caching swap in a MemoryStore.
  # Established pattern -- see
  # test/controllers/observations/inat_resyncs_controller_test.rb.
  def with_real_cache(&block)
    Rails.stub(:cache, ActiveSupport::Cache::MemoryStore.new, &block)
  end

  def test_next_and_prev_window_cache_miss
    with_real_cache do
      query = Query.lookup_and_save(:Name, order_by: :id)
      ids = query.send(:result_ids)
      query.current_id = ids[10]

      assert_equal(ids[9], query.prev_id)
      query.current_id = ids[10]
      assert_equal(ids[11], query.next_id)
    end
  end

  def test_next_and_prev_window_cache_hit_skips_result_ids
    with_real_cache do
      query = Query.lookup_and_save(:Name, order_by: :id)
      query.viewer = rolf
      ids = query.send(:result_ids)
      query.current_id = ids[10]
      query.prev_id # populates the cache

      calls = 0
      query.define_singleton_method(:result_ids) do
        calls += 1
        super()
      end
      assert_equal(ids[11], query.next_id)
      assert_equal(0, calls,
                   "a nearby lookup already covered by the cached " \
                   "window should not recompute result_ids")
    end
  end

  # A cached window's edges aren't always the true edges of the full
  # result set -- walking past a cached-but-not-true edge must refetch
  # (recentering the window) rather than incorrectly reporting "no
  # more." Walking past the true edge must return nil without looping.
  # Counts compute_window calls rather than result_ids calls -- a
  # seekable order's window fill doesn't touch result_ids.
  def test_next_and_prev_window_edge_refetch_and_true_boundary
    with_real_cache do
      query = Query.lookup_and_save(:Name, order_by: :id)
      query.viewer = rolf
      query.define_singleton_method(:window_radius) { 2 }
      ids = Name.order_by(:id).pluck(:id)
      query.current_id = ids[10]

      fills = 0
      query.define_singleton_method(:compute_window) do |*args|
        fills += 1
        super(*args)
      end

      query.current_id = query.prev_id # -> ids[9], cache hit so far
      assert_equal(ids[9], query.current_id)
      query.current_id = query.prev_id # -> ids[8], still within window
      assert_equal(ids[8], query.current_id)
      assert_equal(1, fills, "still inside the first cached window")

      # ids[8] sits at the cached window's left edge (radius 2 from
      # ids[10]) but not the true start -- must refetch, not return nil.
      prev = query.prev_id
      assert_equal(ids[7], prev)
      assert_equal(2, fills, "walking past a non-true edge refetches")

      query.current_id = ids[0]
      assert_nil(query.prev_id, "the true start has no earlier row")
    end
  end

  # The per-viewer radius derivation: 2x the viewer's index page size,
  # clamped to [60, 480] before doubling; no viewer gets the default.
  def test_next_and_prev_window_radius_derived_from_viewer
    no_viewer = Query.lookup(:Name, order_by: :id)
    assert_equal(120, no_viewer.send(:window_radius))

    small = Query.lookup(:Name, order_by: :id)
    small.viewer = rolf
    rolf.layout_count = 15
    assert_equal(120, small.send(:window_radius),
                 "a page size below 60 clamps up")

    mid = Query.lookup(:Name, order_by: :id)
    mid.viewer = rolf
    rolf.layout_count = 100
    assert_equal(200, mid.send(:window_radius))

    large = Query.lookup(:Name, order_by: :id)
    large.viewer = rolf
    rolf.layout_count = 1000
    assert_equal(960, large.send(:window_radius),
                 "a page size above 480 clamps down")
  end

  def test_next_and_prev_first_and_last_never_use_the_window_cache
    with_real_cache do
      query = Query.lookup_and_save(:Image, order_by: :name)
      query.viewer = rolf
      ids = Image.order_by(:name).pluck(:id)

      calls = 0
      query.define_singleton_method(:result_ids) do
        calls += 1
        super()
      end

      assert_equal(ids.first, query.first_id)
      assert_equal(ids.last, query.last_id)
      assert_equal(0, calls,
                   "first_id/last_id use a direct LIMIT-1 query, " \
                   "not result_ids")
      assert_nil(Rails.cache.read(query.send(:window_cache_key)),
                 "first_id/last_id should never populate the window cache")
    end
  end

  # The cache can legitimately disagree with the live DB until the
  # next refetch -- that's the design's snapshot semantics working as
  # intended: prev/next walk the ordering as the viewer saw it, not
  # the live ordering. A stale entry whose ids still exist gets served
  # as-is; only a fresh `refresh_window` call reflects current data.
  # (An id that no longer exists is the exception -- see
  # test_next_and_prev_window_skips_destroyed_neighbor.)
  def test_next_and_prev_window_cache_can_serve_stale_data
    with_real_cache do
      query = Query.lookup_and_save(:Name, order_by: :id)
      query.viewer = rolf
      ids = query.send(:result_ids)
      query.current_id = ids[10]
      query.prev_id # populates the cache with ids[9] at slot 9

      key = query.send(:window_cache_key)
      cached = Rails.cache.read(key)
      tampered_ids = cached[:ids].dup
      # A live id planted out of order -- stale ordering, existing row.
      tampered_ids[9] = ids[3]
      Rails.cache.write(key, cached.merge(ids: tampered_ids))

      assert_equal(ids[3], query.prev_id,
                   "a stale cache entry is served as-is until refreshed")

      fresh = query.send(:refresh_window)
      assert_equal(ids[9], fresh[:ids][fresh[:offset] - 1],
                   "a fresh recompute reflects live data again")
    end
  end

  # need_letters reorders result_ids at paginate time in a way this
  # module doesn't account for -- prev/next/first/last must bypass the
  # window cache entirely for these queries, the same way
  # Query::Modules::Seek#seek_or bails on them. Regression test: the
  # window cache used to have no need_letters guard at all, so a
  # need_letters query's ids -- possibly reordered by letter -- could
  # get cached under a key shared with non-need_letters instances of
  # the same underlying query.
  def test_next_and_prev_window_cache_bypasses_need_letters
    with_real_cache do
      query = Query.lookup_and_save(:Name, order_by: :id)
      query.viewer = rolf
      query.need_letters = true
      ids = query.send(:result_ids)
      query.current_id = ids[10]

      assert_equal(ids[9], query.prev_id)
      query.current_id = ids[10]
      assert_equal(ids[11], query.next_id)
      assert_equal(ids.first, query.first_id)
      assert_equal(ids.last, query.last_id)

      assert_nil(Rails.cache.read(query.send(:window_cache_key)),
                 "need_letters queries should never populate the " \
                 "window cache")
    end
  end

  # A caller that already checked result_ids.length (e.g. to decide
  # whether a search matched exactly one thing) shouldn't pay for a
  # second query when it then asks for first_id/last_id.
  def test_next_and_prev_window_cache_first_and_last_reuse_memoized_result_ids
    with_real_cache do
      query = Query.lookup(:Name, order_by: :id)
      ids = query.result_ids # memoizes @result_ids, as single_result? does

      calls = 0
      query.define_singleton_method(:scope) do
        calls += 1
        super()
      end

      assert_equal(ids.first, query.first_id)
      assert_equal(ids.last, query.last_id)
      assert_equal(0, calls,
                   "first_id/last_id should reuse already-memoized " \
                   "result_ids instead of querying again")
    end
  end

  # A persistent cache (Solid Cache) can hand back an entry from a
  # pre-deploy version of this code whose shape no longer matches --
  # must be treated as a miss, not raise.
  def test_next_and_prev_window_cache_ignores_malformed_cache_entry
    with_real_cache do
      query = Query.lookup_and_save(:Name, order_by: :id)
      query.viewer = rolf
      ids = query.send(:result_ids)
      query.current_id = ids[10]

      Rails.cache.write(query.send(:window_cache_key), "not a window hash")

      assert_equal(ids[9], query.prev_id)
    end
  end

  # Two viewers browsing the same logical query (same QueryRecord) get
  # separate cache slots -- one shouldn't evict the other's window.
  # Regression test: window_cache_key used to be scoped only by
  # QueryRecord#id, so any two viewers of the same query shared one
  # slot and continually clobbered each other's cached window.
  def test_next_and_prev_window_cache_keyed_per_viewer
    with_real_cache do
      rolfs_query = Query.lookup_and_save(:Name, order_by: :id)
      rolfs_query.viewer = rolf
      ids = rolfs_query.send(:result_ids)
      rolfs_query.current_id = ids[10]
      rolfs_query.prev_id # populates rolf's own cache slot

      marys_query = Query.lookup_and_save(:Name, order_by: :id)
      marys_query.viewer = mary
      assert_not_equal(rolfs_query.send(:window_cache_key),
                       marys_query.send(:window_cache_key))

      marys_query.current_id = ids[500]
      marys_query.prev_id # a different position -- must not touch rolf's slot

      calls = 0
      rolfs_query.define_singleton_method(:result_ids) do
        calls += 1
        super()
      end
      assert_equal(ids[9], rolfs_query.prev_id)
      assert_equal(0, calls,
                   "mary's lookup elsewhere in the same query should " \
                   "not evict rolf's cached window")
    end
  end

  # A row destroyed after its id was cached must not be served as a
  # neighbor -- the arrow would point at a dead show page and bounce
  # the user to the index, losing their place. The lookup checks the
  # candidate still exists and refetches past it from live data,
  # healing the cached window in the same step.
  def test_next_and_prev_window_skips_destroyed_neighbor
    with_real_cache do
      query = Query.lookup_and_save(:Observation, order_by: :id)
      query.viewer = rolf
      ids = Observation.order_by(:id).pluck(:id)
      query.current_id = ids[10]
      assert_equal(ids[11], query.next_id, "sanity: cache filled")

      # Bypass callbacks -- the point is only that the row is gone.
      Observation.delete(ids[11])

      assert_equal(ids[12], query.next_id,
                   "next_id should skip the destroyed neighbor")
      key = query.send(:window_cache_key)
      assert_not_includes(Rails.cache.read(key)[:ids], ids[11],
                          "the refetch should heal the cached window")
    end
  end

  # The seek-backed window fill: a plain-column order fills the window
  # with bounded keyset queries and no result_ids load; an order shape
  # a keyset predicate can't express (FIND_IN_SET here) falls back to
  # the full-scan fill.
  def test_next_and_prev_window_fill_dispatch_by_order_shape
    simple_query = Query.lookup(:Name, order_by: :id)
    simple_query.current = names(:fungi)
    calls = count_result_ids_calls(simple_query) do
      simple_query.prev_id
      simple_query.next_id
    end
    assert_equal(0, calls,
                 "Simple column order should fill the window without " \
                 "loading result_ids")

    fallback_query = Query.lookup(
      :Name,
      id_in_set: [names(:fungi).id, names(:agaricus).id, names(:peltigera).id]
    )
    fallback_query.current = names(:agaricus)
    calls = count_result_ids_calls(fallback_query) do
      fallback_query.prev_id
      fallback_query.next_id
    end
    assert(calls.positive?,
           "id_in_set order should fall back to loading result_ids")
  end

  def test_next_and_prev_window_seek_compound_order
    query = Query.lookup(:Observation, order_by: :name)
    ids = Observation.order_by(:name).pluck(:id)
    index = ids.length / 2

    query.current_id = ids[index]
    assert_equal(ids[index - 1], query.prev_id)
    assert_equal(ids[index + 1], query.next_id)
  end

  def test_next_and_prev_window_seek_duplicate_tie
    obs1 = observations(:agaricus_campestras_obs)
    obs2 = observations(:agaricus_campestros_obs)
    assert_equal(obs1.when, obs2.when,
                 "fixtures must share a `when` to exercise the id tie-break")

    ids = Observation.order_by(:date).pluck(:id)
    index = ids.index(obs2.id)

    query = Query.lookup(:Observation, order_by: :date)
    query.current_id = obs2.id
    assert_equal(ids[index - 1], query.prev_id)
    assert_equal(ids[index + 1], query.next_id)
  end

  # An image on multiple observations with differing vote_cache has no
  # single sort key to seed the keyset predicate from -- the window
  # fill must fall back to the full-scan fill rather than seed from an
  # arbitrary join row.
  def test_next_and_prev_window_seek_ambiguous_join_falls_back
    image = images(:query_first_image)
    obs_a = observations(:two_img_obs)
    obs_b = observations(:vouchered_imged_obs)
    obs_a.update!(vote_cache: 1.5)
    obs_b.update!(vote_cache: -1.0)

    query = Query.lookup(:Image, order_by: :confidence)
    query.current = image
    cols = query.send(:scope).order_values

    assert_nil(query.send(:current_sort_values, cols),
               "an image on multiple observations with differing " \
               "vote_cache should be treated as unseekable")
    ids = query.send(:result_ids)
    index = ids.index(image.id)
    assert_equal(ids[index - 1], query.prev_id)
    assert_equal(ids[index + 1], query.next_id)
  end

  # `current_sort_values` (read the current row's own sort columns)
  # and the two directional window fetches are separate queries -- a
  # concurrent write to the current row between them could seed the
  # window from an already-stale value unless the reads share one
  # transaction/snapshot. Regression test for that guarantee: assert
  # the read runs inside a transaction opened by `seek_window` itself,
  # not just whatever the test framework already wraps everything in.
  def test_next_and_prev_window_seek_wraps_reads_in_a_transaction
    query = Query.lookup(:Name, order_by: :id)
    query.current = names(:fungi)

    baseline = ActiveRecord::Base.connection.open_transactions
    open_during_read = nil
    query.define_singleton_method(:current_sort_values) do |*args|
      open_during_read = ActiveRecord::Base.connection.open_transactions
      super(*args)
    end

    query.prev_id

    assert_equal(baseline + 1, open_during_read,
                 "current_sort_values should run inside its own " \
                 "transaction, not bare autocommit")
  end

  # MySQL sorts NULL as the smallest possible value regardless of
  # ASC/DESC -- a plain `col > NULL`/`col < NULL` comparison is always
  # unknown in SQL, so a naive seek predicate can't cross the boundary
  # between NULL and non-NULL rows in either direction.
  def test_next_and_prev_window_seek_null_sort_value_boundary
    null_image = images(:in_situ_image)
    others = Image.where.not(id: null_image.id)
    others.each_with_index { |img, i| img.update!(vote_cache: i + 1.0) }
    null_image.update!(vote_cache: nil)

    ids = Image.order_by(:image_quality).pluck(:id)
    prior_id = ids[ids.index(null_image.id) - 1]

    # prev: from NULL, transitioning into non-NULL territory.
    from_null = Query.lookup(:Image, order_by: :image_quality)
    from_null.current_id = null_image.id
    assert_equal(prior_id, from_null.prev_id)

    # next: from non-NULL, transitioning into NULL territory.
    from_non_null = Query.lookup(:Image, order_by: :image_quality)
    from_non_null.current_id = prior_id
    assert_equal(null_image.id, from_non_null.next_id)
  end

  # Without a viewer there's no cache slot, so prev_id and next_id
  # each trigger their own window fill -- but the current row's own
  # sort values shouldn't be fetched twice for the same current_id.
  def test_next_and_prev_window_seek_memoizes_current_sort_values
    query = Query.lookup(:Name, order_by: :id)
    query.current = names(:fungi)

    calls = 0
    query.define_singleton_method(:fetch_current_sort_values) do |*args|
      calls += 1
      super(*args)
    end

    query.prev_id
    query.next_id

    assert_equal(1, calls,
                 "current row's sort values should be fetched once, " \
                 "not once per direction")
  end

  # A seekable order with zero matching rows is a legitimate nil
  # boundary from edge_id's LIMIT-1 query itself -- first_id/last_id
  # shouldn't fall back to a full result_ids load just because that
  # nil looks the same as "order shape isn't seekable" (Copilot
  # review, PR #5115).
  def test_next_and_prev_window_first_and_last_no_fallback_on_empty_results
    query = Query.lookup(:Name, order_by: :id,
                                pattern: "no_name_matches_this_zzzzzz")

    calls = count_result_ids_calls(query) do
      assert_nil(query.first_id)
      assert_nil(query.last_id)
    end

    assert_equal(0, calls,
                 "empty seekable query should return nil without " \
                 "falling back to loading result_ids")
  end

  ##############################################################################
  #
  #  :section: Test Subqueries
  #
  ##############################################################################

  def test_basic_subquery_of
    assert_equal(0, QueryRecord.count)

    q1 = Query.lookup_and_save(:Observation, pattern: "search")
    assert_equal(1, QueryRecord.count)

    # Trvial coercion: from a model to the same model.
    q2 = q1.subquery_of(:Observation)
    assert_equal(q1, q2)
    assert_equal(1, QueryRecord.count)

    # No search is coercable to RssLog (yet).
    q3 = q1.subquery_of(:RssLog)
    assert_nil(q3)
    assert_equal(1, QueryRecord.count)
  end

  def three_amigos
    [
      observations(:detailed_unknown_obs).id,
      observations(:agaricus_campestris_obs).id,
      observations(:agaricus_campestras_obs).id
    ].freeze
  end

  def test_observation_subquery_of_image
    burbank = locations(:burbank)
    query_a = []

    # Several observation queries can be turned into image queries.
    query_a[0] = Query.lookup_and_save(:Observation, order_by: :id)
    query_a[1] = Query.lookup_and_save(:Observation, by_users: mary.id)
    query_a[2] = Query.lookup_and_save(
      :Observation, species_lists: species_lists(:first_species_list).id
    )
    query_a[3] = Query.lookup_and_save(:Observation, id_in_set: three_amigos)
    query_a[4] = Query.lookup_and_save(:Observation, search_where: "glendale")
    query_a[5] = Query.lookup_and_save(:Observation, locations: burbank)
    query_a[6] = Query.lookup_and_save(:Observation, search_where: "california")
    # removed query_a[7] which searched for "somewhere else" in the notes
    # query_a[7] = Query.lookup_and_save(:Observation,
    #                                    pattern: '"somewhere else"')
    assert_equal(7, QueryRecord.count)

    observation_subquery_assertions(query_a, :Image)
  end

  def test_observation_subquery_of_location
    burbank = locations(:burbank)
    query_a = []

    # Almost any query on observations should be mappable, i.e. coercable into
    # a query on those observations' locations.
    query_a[0] = Query.lookup_and_save(:Observation, order_by: :id)
    query_a[1] = Query.lookup_and_save(:Observation, by_users: mary.id)
    query_a[2] = Query.lookup_and_save(
      :Observation, species_lists: species_lists(:first_species_list).id
    )
    query_a[3] = Query.lookup_and_save(:Observation, id_in_set: three_amigos)
    query_a[4] = Query.lookup_and_save(:Observation, search_where: "glendale")
    query_a[5] = Query.lookup_and_save(:Observation, locations: burbank)
    query_a[6] = Query.lookup_and_save(:Observation, search_where: "california")
    assert_equal(7, QueryRecord.count)

    query_b = observation_subquery_assertions(query_a, :Location)

    # Now, check the parameters of those subqueries.
    obs_queries = query_b.map { |que| que.params[:observation_query] }

    assert_equal("id", obs_queries[0][:order_by])
    assert_equal([mary.id], obs_queries[1][:by_users])
    assert_equal([species_lists(:first_species_list).id],
                 obs_queries[2][:species_lists])
    assert_equal(three_amigos, obs_queries[3][:id_in_set])
    assert_equal(1, obs_queries[3].keys.length)
    assert_equal("glendale", obs_queries[4][:search_where])
    assert_equal(1, obs_queries[4].keys.length)
    assert_equal([burbank.id], obs_queries[5][:locations])
    assert_equal(1, obs_queries[5].keys.length)
    assert_equal("california", obs_queries[6][:search_where])
    assert_equal(1, obs_queries[6].keys.length)
  end

  # An Observation query filtered by project or species_list defaults
  # its converted Location subquery to is_collection_location: true --
  # checks the resolved attr names (`projects`/`species_lists`), not
  # their param_alias shortcuts (`project`/`species_list`), which don't
  # appear in a Query's stored params. See
  # Query::Modules::Subqueries#needs_is_collection_location.
  def test_observation_subquery_of_location_defaults_collection_location
    project = projects(:bolete_project)
    species_list = species_lists(:first_species_list)

    by_project = Query.lookup_and_save(:Observation, projects: [project.id])
    by_species_list = Query.lookup_and_save(
      :Observation, species_lists: [species_list.id]
    )
    unfiltered = Query.lookup_and_save(:Observation, order_by: :id)

    project_location = by_project.subquery_of(:Location)
    species_list_location = by_species_list.subquery_of(:Location)
    unfiltered_location = unfiltered.subquery_of(:Location)

    assert_equal(
      true,
      project_location.params[:observation_query][:is_collection_location]
    )
    assert_equal(
      true,
      species_list_location.
        params[:observation_query][:is_collection_location]
    )
    assert_not(
      unfiltered_location.params[:observation_query].
        key?(:is_collection_location)
    )

    # An empty array is a present key, not a filter -- .present?, not
    # truthiness, decides this.
    empty_projects = Query.lookup_and_save(:Observation, projects: [])
    empty_projects_location = empty_projects.subquery_of(:Location)

    assert_not(
      empty_projects_location.params[:observation_query].
        key?(:is_collection_location)
    )
  end

  def test_observation_subquery_of_name
    burbank = locations(:burbank)
    query_a = []

    # Several observation queries can be turned into name queries.
    query_a[0] = Query.lookup_and_save(:Observation, order_by: :id)
    query_a[1] = Query.lookup_and_save(:Observation, by_users: mary.id)
    query_a[2] = Query.lookup_and_save(
      :Observation, species_lists: species_lists(:first_species_list).id
    )
    query_a[3] = Query.lookup_and_save(:Observation, id_in_set: three_amigos)
    # qa[4] = Query.lookup_and_save(:Observation,
    #                             pattern: '"somewhere else"')
    query_a[4] = Query.lookup_and_save(:Observation, search_where: "glendale")
    query_a[5] = Query.lookup_and_save(:Observation, locations: burbank)
    query_a[6] = Query.lookup_and_save(:Observation, search_where: "california")
    assert_equal(7, QueryRecord.count)

    observation_subquery_assertions(query_a, :Name)
  end

  # General purpose repetitive assertions for relating observation queries.
  # query_a is original, query_b is related, and query_c is related back.
  # Returns the related query (query_check) for further testing
  def observation_subquery_assertions(query_a, model)
    query_b = query_c = []
    len = query_a.size - 1

    [*0..len].each do |i|
      # Try relating them all.
      assert(query_b[i] = query_a[i].subquery_of(model))

      # They should all be new records
      # assert(query_b[i].record.new_record?)
      assert_save(query_b[i])

      # Check the query descriptions.
      assert_equal(model.to_s, query_b[i].model.to_s)
      assert(query_b[i].params[:observation_query])
      # When relating to locations, default param :is_collection_location added
      assert_equal(
        query_a[i].params,
        query_b[i].params[:observation_query].except(:is_collection_location)
      )
    end

    # The `subquery_of` changes query_b, so save it for later comparison.
    query_check = query_b.dup

    [*0..len].each do |i|
      # Now try to relate them back to Observation.
      assert(query_c[i] = query_b[i].subquery_of(:Observation))
      # They should not be new records
      # assert_not(query_c[i].record.new_record?)
      assert_equal(query_a[i].params,
                   query_c[i].params.except(:is_collection_location))
    end

    query_check
  end

  def test_location_description_subquery_of_location
    ds1 = location_descriptions(:albion_desc)
    ds2 = location_descriptions(:no_mushrooms_location_desc)
    description_subquery_assertions(ds1, ds2, :Location)
  end

  def test_name_description_subquery_of_name
    ds1 = name_descriptions(:coprinus_comatus_desc)
    ds2 = name_descriptions(:peltigera_desc)
    description_subquery_assertions(ds1, ds2, :Name)
  end

  def description_subquery_assertions(ds1, ds2, model)
    qa = qb = qc = []

    desc_model = :"#{model}Description"
    # These description queries can be turned into parent_type queries and back.
    qa[0] = Query.lookup_and_save(desc_model)
    qa[1] = Query.lookup_and_save(desc_model, by_author: rolf.id)
    qa[2] = Query.lookup_and_save(desc_model, by_editor: rolf.id)
    qa[3] = Query.lookup_and_save(desc_model, by_users: rolf.id)
    qa[4] = Query.lookup_and_save(desc_model, id_in_set: [ds1.id, ds2.id])
    assert_equal(5, QueryRecord.count)

    # Try coercing them into parent_type queries.
    [*0..4].each do |i|
      assert(qb[i] = qa[i].subquery_of(model))
      # They should all be new records
      # assert(qb[i].record.new_record?)
      assert_save(qb[i])
      assert_equal(model.to_s, qb[i].model.to_s)
      assert(qb[i].params[:description_query])
    end
    # Make sure they're right.
    desc_queries = qb.map { |que| que.params[:description_query] }

    assert_equal(rolf.id, desc_queries[1][:by_author])
    assert_equal(rolf.id, desc_queries[2][:by_editor])
    assert_equal([rolf.id], desc_queries[3][:by_users])
    assert_equal([ds1.id, ds2.id], desc_queries[4][:id_in_set])

    # Try coercing them back.
    # None should be new records
    [*0..4].each do |i|
      assert(qc[i] = qb[i].subquery_of(desc_model))
      assert_equal(qa[i], qc[i])
    end
  end

  def test_relatable
    assert(Query.lookup(:Observation, order_by: :id).relatable?(:Image))
    assert_not(Query.lookup(:Herbarium, order_by: :id).relatable?(:Project))
  end

  def test_q_param
    params = { by_users: [rolf.id], names: { lookup: ["Coprinus comatus"] } }
    query = Query.lookup(:Observation, **params)
    assert_equal(query.q_param, { model: :Observation, **params })
  end

  def test_index_filter
    params = { by_users: [rolf.id], names: { lookup: ["Coprinus comatus"] } }
    query = Query.lookup(:Observation, **params)
    # Same params as q_param minus :model, but with each one-element
    # array shrunk to a bare scalar -- by_users -> its param_alias
    # by_user, and the one-name/no-modifiers names: hash collapsed to
    # this_name (Query::Observations-only; see collapse_names_to_this_name).
    assert_equal({ by_user: rolf.id, this_name: "Coprinus comatus" },
                 query.index_filter)
  end

  def test_index_filter_multiple_values_keeps_bracket_array_form
    list1 = species_lists(:first_species_list)
    list2 = species_lists(:another_species_list)
    query = Query.lookup(:Observation, species_lists: [list1.id, list2.id])

    # More than one value: no alias substitution, stays an array.
    assert_equal({ species_lists: [list1.id, list2.id] }, query.index_filter)
  end

  def test_index_filter_names_not_collapsed_with_multiple_lookup_values
    query = Query.lookup(:Observation,
                         names: { lookup: %w[Agaricus Boletus] })

    # More than one lookup value: not collapsible to this_name.
    assert_equal({ names: { lookup: %w[Agaricus Boletus] } },
                 query.index_filter)
  end

  def test_index_filter_names_not_collapsed_with_modifier_set
    query = Query.lookup(:Observation,
                         names: { lookup: ["Agaricus"],
                                  include_synonyms: true })

    # A modifier flag is set: not semantically equivalent to
    # this_name, which carries no synonym/subtaxa expansion.
    assert_equal(
      { names: { lookup: ["Agaricus"], include_synonyms: true } },
      query.index_filter
    )
  end

  def test_index_filter_names_not_collapsed_without_this_name_attr
    # Query::Names has no :this_name attr -- collapse_names_to_this_name
    # must no-op rather than emitting a param the class won't recognize.
    assert_not(Query::Names.has_attribute?(:this_name))
    query = Query.lookup(:Name, names: { lookup: ["Agaricus"] })

    assert_equal({ names: { lookup: ["Agaricus"] } }, query.index_filter)
  end

  def test_index_filter_excludes_routing_keys
    query = Query.lookup(:Observation, by_users: [rolf.id])
    # No query_attr is currently named these, but a future one could
    # be -- defensively strip them so they can't clobber the route-
    # helper args index_filter gets merged into.
    query.params = query.params.merge(controller: "x", action: "y",
                                      id: 1, format: "json")

    assert_equal({ by_user: rolf.id }, query.index_filter)
  end

  def test_merge_q_param_into_url
    assert_equal(
      "/observations", Query.merge_q_param_into_url("/observations", nil)
    )
    assert_equal(
      "/observations", Query.merge_q_param_into_url("/observations", "")
    )
    assert_equal(
      "/observations?q=ABCDE",
      Query.merge_q_param_into_url("/observations", "ABCDE")
    )
    # Preserves an existing (non-q) query param already on the path.
    assert_equal(
      "/observations?flow=next&q=ABCDE",
      Query.merge_q_param_into_url("/observations?flow=next", "ABCDE")
    )
    # A Hash q_param (Query#q_param's own return shape) round-trips via
    # Hash#to_query, not Rack::Utils.build_query -- a nested value
    # (:locations here) would otherwise serialize as an unparseable
    # literal Ruby Hash#inspect string.
    merged = Query.merge_q_param_into_url(
      "/observations", { model: :Observation, locations: [1] }
    )
    assert_equal(
      "q%5Blocations%5D%5B%5D=1&q%5Bmodel%5D=Observation",
      URI.parse(merged).query
    )
  end

  def test_merge_index_filters_into_url
    assert_equal(
      "/observations",
      Query.merge_index_filters_into_url("/observations", nil)
    )
    assert_equal(
      "/observations",
      Query.merge_index_filters_into_url("/observations", {})
    )
    assert_equal(
      "/observations?by_user=1",
      Query.merge_index_filters_into_url("/observations", by_user: 1)
    )
    # Preserves an existing query param already on the path.
    assert_equal(
      "/observations?by_user=1&flow=next",
      Query.merge_index_filters_into_url(
        "/observations?flow=next", by_user: 1
      )
    )
    # Flat, not nested under q[...] -- an array-valued filter still
    # round-trips correctly via Hash#to_query.
    merged = Query.merge_index_filters_into_url(
      "/observations", locations: [1]
    )
    assert_equal("locations%5B%5D=1", URI.parse(merged).query)
  end

  ##############################################################################
  #
  #  :section: Other stuff
  #
  ##############################################################################

  def test_whiny_nil_in_map_locations
    query = Query.lookup(:User, id_in_set: [rolf.id, 1000, mary.id])
    query.sql
    assert_equal(2, query.results.length)
  end

  private

  def count_result_ids_calls(query)
    count = 0
    query.define_singleton_method(:result_ids) do
      count += 1
      super()
    end
    yield
    count
  end
end
