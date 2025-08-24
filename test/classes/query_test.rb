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
      :either,
      Query.lookup(:Name, misspellings: :either).params[:misspellings]
    )
    assert_equal(
      :either,
      Query.lookup(:Name, misspellings: "either").params[:misspellings]
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
    assert_validation_errors(Query.lookup(:Observation, date: "fi"))
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
    assert_equal(roy.location_format, "scientific")
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
    @query = Query.lookup(:Name, misspellings: :either, order_by: :id)
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
    query = Query.lookup(:Name, misspellings: :either, order_by: :id)
    @names = Name.reorder(id: :asc)

    query.current = @names[2]
    assert_equal(query, query.prev)
    assert_equal(@names[1].id, query.current_id)
    assert_equal(query, query.prev)
    assert_equal(@names[0].id, query.current_id)
    assert_nil(query.prev)
    assert_equal(@names[0].id, query.current_id)
    assert_equal(query, query.next)
    assert_equal(@names[1].id, query.current_id)
    assert_equal(query, query.next)
    assert_equal(@names[2].id, query.current_id)
    assert_equal(query, query.last)
    assert_equal(@names[-1].id, query.current_id)
    assert_equal(query, query.last)
    assert_equal(@names[-1].id, query.current_id)
    assert_nil(query.next)
    assert_equal(@names[-1].id, query.current_id)
    assert_equal(query, query.first)
    assert_equal(@names[0].id, query.current_id)
    assert_equal(query, query.first)
    assert_equal(@names[0].id, query.current_id)
    query.reset
    assert_equal(@names[2].id, query.current_id)
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
end
