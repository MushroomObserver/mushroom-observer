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

    query2 = Query.lookup_and_save(:Observation)
    assert_not(query2.record.new_record?)
    assert_equal(query, query2)

    assert_equal(query2, Query.safe_find(query2.id))
    assert_nil(Query.safe_find(0))

    updated_at = query2.record.updated_at
    assert_equal(0, query2.record.access_count)
    query3 = Query.lookup(:Observation)
    assert_equal(query2.serialize, query3.serialize)
    assert_equal(updated_at.to_s, query3.record.updated_at.to_s)
    assert_equal(0, query3.record.access_count)
  end

  def test_validate_params
    # Should ignore params it doesn't recognize
    # assert_raises(RuntimeError) { Query.lookup(:Name, xxx: true) }
    assert_raises(RuntimeError) { Query.lookup(:Name, by: [1, 2, 3]) }
    assert_raises(RuntimeError) { Query.lookup(:Name, by: true) }
    assert_equal("id", Query.lookup(:Name, by: :id).params[:by])

    assert_equal(
      :either,
      Query.lookup(:Name, misspellings: :either).params[:misspellings]
    )
    assert_equal(
      :either,
      Query.lookup(:Name, misspellings: "either").params[:misspellings]
    )
    assert_raises(RuntimeError) do
      Query.lookup(:Name, misspellings: "bogus")
    end
    assert_raises(RuntimeError) do
      Query.lookup(:Name, misspellings: true)
    end
    assert_raises(RuntimeError) { Query.lookup(:Name, misspellings: 123) }
  end

  def test_validate_params_instances_users
    @fungi = names(:fungi)

    assert_raises(RuntimeError) { Query.lookup(:Image, by_users: :bogus) }
    assert_raises(RuntimeError) { Query.lookup(:Image, by_users: @fungi) }
    assert_equal([rolf.id],
                 Query.lookup(:Image, by_users: rolf).params[:by_users])
    assert_equal([rolf.id],
                 Query.lookup(:Image, by_users: rolf.id).params[:by_users])
    assert_equal([rolf.id],
                 Query.lookup(:Image, by_users: rolf.id.to_s).params[:by_users])
    assert_equal([rolf.login],
                 Query.lookup(:Image, by_users: rolf.login).params[:by_users])
  end

  def test_validate_params_id_in_set
    # Oops, this query is generic,
    # doesn't know to require Name instances here.
    # assert_raises(RuntimeError) { Query.lookup(:Name, id_in_set: rolf) }
    assert_raises(RuntimeError) { Query.lookup(:Name, id_in_set: "one") }
    assert_raises(RuntimeError) { Query.lookup(:Name, id_in_set: "1,2,3") }
    assert_raises(RuntimeError) { Query.lookup(:Name, id_in_set: "Fungi") }
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
    # assert_raises(RuntimeError) { Query.lookup(:Name) }
    assert_raises(RuntimeError) do
      Query.lookup(:Name, pattern: true)
    end
    assert_raises(RuntimeError) do
      Query.lookup(:Name, pattern: [1, 2, 3])
    end
    assert_raises(RuntimeError) do
      Query.lookup(:Name, pattern: rolf)
    end
    assert_equal("123",
                 Query.lookup(:Name, pattern: 123).params[:pattern])
    assert_equal("rolf",
                 Query.lookup(:Name, pattern: "rolf").params[:pattern])
    assert_equal("rolf",
                 Query.lookup(:Name, pattern: :rolf).params[:pattern])
  end

  def test_validate_params_join
    assert_equal(["table"],
                 Query.lookup(:Name, join: :table).params[:join])
    assert_equal(%w[table1 table2],
                 Query.lookup(:Name, join: [:table1, :table2]).
                 params[:join])
  end

  def test_validate_params_tables
    assert_equal(["table"],
                 Query.lookup(:Name, tables: :table).params[:tables])
    assert_equal(%w[table1 table2],
                 Query.lookup(:Name, tables: [:table1, :table2]).
                 params[:tables])
  end

  def test_validate_params_where
    assert_equal(["foo = bar"],
                 Query.lookup(:Name, where: "foo = bar").params[:where])
    assert_equal(["foo = bar", "id in (1,2,3)"],
                 Query.lookup(:Name, where: ["foo = bar", "id in (1,2,3)"]).
                 params[:where])
  end

  def test_validate_params_group
    assert_equal("names.id",
                 Query.lookup(:Name, group: "names.id").params[:group])
    assert_raises(RuntimeError) { Query.lookup(:Name, group: %w[1 2]) }
  end

  def test_validate_params_order
    assert_equal("id DESC",
                 Query.lookup(:Name, order: "id DESC").params[:order])
    assert_raises(RuntimeError) { Query.lookup(:Name, order: %w[1 2]) }
  end

  def test_validate_params_hashes
    box = { north: 48.5798, south: 48.558, east: -123.4307, west: -123.4763 }
    assert_equal(box, Query.lookup(:Location, in_box: box).params[:in_box])
    assert_raises(TypeError) { Query.lookup(:Location, in_box: "one") }
    box = { north: "with", south: 48.558, east: -123.4307, west: -123.4763 }
    assert_raises(RuntimeError) { Query.lookup(:Location, in_box: box) }
    box = { south: 48.558, east: -123.4307, west: -123.4763 }
    assert_raises(RuntimeError) { Query.lookup(:Location, in_box: box) }
  end

  def test_initialize_helpers
    query = Query.lookup(:Name)

    assert_equal("4,1,2", query.clean_id_set(["4", 1, 4, 2, 4, 1, 2]))
    assert_equal("-1", query.clean_id_set([]))

    assert_equal("blah", query.clean_pattern("blah"))
    assert_equal("foo bar", query.clean_pattern("foo bar"))
    assert_equal('\\"foo\\%bar\\"', query.clean_pattern('"foo%bar"'))
    assert_equal('one\\\\two', query.clean_pattern('one\\two'))
    assert_equal("foo%bar", query.clean_pattern("foo*bar"))

    assert_nil(query.and_clause)
    assert_equal("one", query.and_clause("one"))
    assert_equal("(one AND two)", query.and_clause("one", "two"))
    assert_equal("(one AND two AND three)",
                 query.and_clause("one", "two", "three"))

    assert_nil(query.or_clause)
    assert_equal("one", query.or_clause("one"))
    assert_equal("(one OR two)", query.or_clause("one", "two"))
    assert_equal("(one OR two OR three)",
                 query.or_clause("one", "two", "three"))
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

  def test_google_conditions
    query = Query.lookup(:Name)
    assert_equal(
      ["x LIKE '%blah%'"],
      query.google_conditions(SearchParams.new(phrase: "blah"), "x")
    )
    assert_equal(
      ["x NOT LIKE '%bad%'"],
      query.google_conditions(SearchParams.new(phrase: "-bad"), "x")
    )
    assert_equal(
      ["x LIKE '%foo%' AND x NOT LIKE '%bad%'"],
      query.google_conditions(SearchParams.new(phrase: "foo -bad"), "x")
    )
    assert_equal(
      ["x LIKE '%foo%' AND x LIKE '%bar%' AND x NOT LIKE '%bad%'"],
      query.google_conditions(SearchParams.new(phrase: "foo bar -bad"), "x")
    )
    assert_equal(
      ["(x LIKE '%foo%' OR x LIKE '%bar%') AND x NOT LIKE '%bad%'"],
      query.google_conditions(SearchParams.new(phrase: "foo OR bar -bad"), "x")
    )
    assert_equal(
      ["(x LIKE '%foo%' OR x LIKE '%bar%' OR x LIKE '%any%thing%') " \
        "AND x LIKE '%surprise!%' AND x NOT LIKE '%bad%' " \
        "AND x NOT LIKE '%lost boys%'"],
      query.google_conditions(
        SearchParams.new(
          phrase: 'foo OR bar OR "any*thing" -bad surprise! -"lost boys"'
        ), "x"
      )
    )
  end

  def test_lookup
    assert_equal(0, QueryRecord.count)

    q1 = Query.lookup_and_save(:Observation)
    assert_equal(1, QueryRecord.count)

    Query.lookup_and_save(:Observation, pattern: "blah")
    assert_equal(2, QueryRecord.count)

    # New because params are different from q1.
    q3 = Query.lookup_and_save(:Observation, by: :id)
    assert_equal(3, QueryRecord.count)

    # Not new because it is explicitly defaulted before validate.
    q4 = Query.lookup_and_save(:Observation)
    assert_equal(3, QueryRecord.count)
    assert_equal(q1, q4, QueryRecord.count)

    # Ditto default.
    q5 = Query.lookup_and_save(:Observation, by: :id)
    assert_equal(3, QueryRecord.count)
    assert_equal(q3, q5, QueryRecord.count)

    # New pattern is new query.
    Query.lookup_and_save(:Observation, pattern: "new blah")
    assert_equal(4, QueryRecord.count)

    # Old pattern but new order.
    Query.lookup_and_save(:Observation, pattern: "blah", by: :date)
    assert_equal(5, QueryRecord.count)

    # Identical, even though :by is explicitly set in one.
    Query.lookup_and_save(:Observation, pattern: "blah")
    assert_equal(5, QueryRecord.count)

    # Identical query, but new query because order given explicitly.  Order is
    # not given default until query is initialized, thus default not stored in
    # params, so lookup doesn't know about it.
    Query.lookup_and_save(:Observation, by: :date)
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

  def test_query
    query = Query.lookup(:Name)
    query.initialize_query
    assert_equal([], query.join)
    assert_equal([], query.tables)
    assert_equal(1, query.where.length) # misspellings
    assert_equal("", query.group)
    assert_not_equal("", query.order) # whatever the default order is

    # Clean it out completely.
    query.where = []
    query.order = ""

    assert_equal(
      "SELECT DISTINCT names.id FROM `names`",
      clean(query.sql)
    )
    assert_equal(
      "SELECT foo bar FROM `names`",
      clean(query.sql(select: "foo bar"))
    )
    assert_equal(
      "SELECT DISTINCT names.id FROM `names` " \
      "JOIN `rss_logs` ON names.rss_log_id = rss_logs.id",
      clean(query.sql(join: :rss_logs))
    )
    assert_equal(
      "SELECT DISTINCT names.id FROM `names` " \
      "JOIN `observations` ON observations.name_id = names.id " \
      "JOIN `rss_logs` ON observations.rss_log_id = rss_logs.id",
      clean(query.sql(join: { observations: :rss_logs }))
    )
    assert_equal(
      "SELECT DISTINCT names.id FROM `names`, `rss_logs`",
      clean(query.sql(tables: :rss_logs))
    )
    assert_equal(
      "SELECT DISTINCT names.id FROM `names`, `images`, `comments`",
      clean(query.sql(tables: [:images, :comments]))
    )
    assert_equal(
      "SELECT DISTINCT names.id FROM `names` WHERE shazam!",
      clean(query.sql(where: "shazam!"))
    )
    assert_equal(
      "SELECT DISTINCT names.id FROM `names` WHERE foo AND bar",
      clean(query.sql(where: %w[foo bar]))
    )
    assert_equal(
      "SELECT DISTINCT names.id FROM `names` WHERE foo AND bar",
      clean(query.sql(where: %w[foo bar]))
    )
    assert_equal(
      "SELECT DISTINCT names.id FROM `names` GROUP BY blah blah blah",
      clean(query.sql(group: "blah blah blah"))
    )
    assert_equal(
      "SELECT DISTINCT names.id FROM `names` ORDER BY foo, bar, names.id DESC",
      # (tacks on 'id DESC' for disambiguation)
      clean(query.sql(order: "foo, bar"))
    )
    assert_equal(
      "SELECT DISTINCT names.id FROM `names` ORDER BY comments.id ASC",
      clean(query.sql(order: "comments.id ASC")) # (sees id in there already)
    )
    assert_equal(
      "SELECT DISTINCT names.id FROM `names` LIMIT 10",
      clean(query.sql(limit: 10))
    )

    # Now, all together...
    assert_equal(
      "SELECT names.* FROM `names`, `images` " \
      "JOIN `observations` ON observations.name_id = names.id " \
      "JOIN `users` ON names.reviewer_id = users.id " \
      "WHERE one = two AND foo LIKE bar " \
      "GROUP BY blah.id ORDER BY names.id ASC LIMIT 10, 10",
      clean(query.sql(select: "names.*",
                      join: [:observations, :"users.reviewer"],
                      tables: :images,
                      where: ["one = two", "foo LIKE bar"],
                      group: "blah.id",
                      order: "names.id ASC",
                      limit: "10, 10"))
    )
  end

  def test_query_params_selects
    # defaults
    query = Query.new(:Name)
    assert(query.sql)
    assert_equal(clean(query.selects), "DISTINCT names.id")

    query = Query.new(:Name, selects: "DISTINCT names.text_name")
    assert(query.sql)
    assert_equal(clean(query.selects), "DISTINCT names.text_name")
  end

  def test_query_params_order
    # defaults
    query = Query.new(:Name)
    assert(query.sql)
    assert_equal(query.default_order, "name")
    assert_equal(clean(query.order), "names.sort_name ASC")

    query = Query.new(:Name, order: "names.id ASC")
    assert(query.sql)
    assert_equal(clean(query.order), "names.id ASC")
  end

  def test_query_params_group
    # defaults
    query = Query.new(:Observation)
    assert(query.sql)
    assert_equal(clean(query.group), "")

    query = Query.new(:Observation, group: "observations.name_id")
    assert(query.sql)
    assert_equal(clean(query.group), "observations.name_id")
  end

  def test_join_conditions
    query = Query.lookup(:Name)
    query.initialize_query
    query.where = []
    query.order = ""

    # Joins should include these:
    #   names => observations => locations
    #   names => observations => comments
    #   names => observations => observation_images => images
    #   names => users (as reviewer)
    sql = query.sql(
      join: [
        {
          observations: [
            :locations,
            :comments,
            { observation_images: :images }
          ]
        },
        :"users.reviewer"
      ]
    )
    assert_match(/names.reviewer_id = users.id/, sql)
    assert_match(/observations.name_id = names.id/, sql)
    assert_match(/observations.location_id = locations.id/, sql)
    assert_match(/comments.target_id = observations.id/, sql)
    assert_match(/comments.target_type = (['"])Observation\1/, sql)
    assert_match(/observation_images.observation_id = observations.id/, sql)
    assert_match(/observation_images.image_id = images.id/, sql)
  end

  def test_reverse_order
    query = Query.lookup(:Name)
    assert_equal("", query.reverse_order(""))
    assert_equal("id ASC", query.reverse_order("id DESC"))
    assert_equal("one ASC, two DESC, three ASC",
                 query.reverse_order("one DESC, two ASC, three DESC"))
    assert_equal(
      'IF(users.name = "", users.login, users.name) DESC, users.id ASC',
      query.reverse_order(
        'IF(users.name = "", users.login, users.name) ASC, users.id DESC'
      )
    )
  end

  def test_join_direction
    # RssLog can join to Observation two ways.  When joining from observations
    # to rss_logs, use observations.rss_log_id = rss_logs.id.
    query = Query.lookup(:Observation)
    query.initialize_query
    query.join << :rss_logs
    assert_match(/observations.rss_log_id = rss_logs.id/, query.sql)

    # And use rss_logs.observation_id = observations.id the other way.
    query = Query.lookup(:RssLog)
    query.initialize_query
    query.join << :observations
    assert_match(/rss_logs.observation_id = observations.id/, query.sql)
  end

  def test_low_levels
    query = Query.lookup(:Name, misspellings: :either, by: :id)

    @fungi = names(:fungi)
    @agaricus = names(:agaricus)
    num = Name.count
    num_agaricus = Name.where(Name[:text_name].matches("Agaricus%")).count

    assert_equal(num, query.select_count)
    assert_equal(num, query.select_count(limit: 10)) # limits no. of counts!!
    assert_equal(num_agaricus,
                 query.select_count(where: 'text_name LIKE "Agaricus%"'))

    names_now = Name.reorder(id: :asc)
    assert_equal(names_now.first.id, query.select_value)
    assert_equal(names_now.offset(10).first.id,
                 query.select_value(limit: "10, 10")) # 11th id
    assert_equal(names_now.last.id,
                 query.select_value(order: :reverse)) # last id
    assert_equal(names_now.first.text_name,
                 query.select_value(select: "text_name").to_s)

    assert_equal(names_now.map { |name| name.id.to_s },
                 query.select_values.map(&:to_s))
    assert_equal([names(:agaricus_campestris).id.to_s,
                  names(:agaricus).id.to_s,
                  names(:agaricus_campestrus).id.to_s,
                  names(:agaricus_campestras).id.to_s,
                  names(:agaricus_campestros).id.to_s,
                  names(:sect_agaricus).id.to_s].sort,
                 query.select_values(where: 'text_name LIKE "Agaricus%"').
                       map(&:to_s).sort)

    agaricus = query.select_values(select: "text_name",
                                   where: 'text_name LIKE "Agaricus%"').
               map(&:to_s)
    assert_equal(num_agaricus, agaricus.uniq.length)
    assert_equal(num_agaricus,
                 agaricus.count { |x| x[0, 8] == "Agaricus" })

    assert_equal(names_now.map { |x| [x.id] }, query.select_rows)
    assert_equal(names_now.map { |x| { "id" => x.id } }, query.select_all)
    assert_equal({ "id" => names_now.first.id }, query.select_one)

    assert_equal([names_now.first], query.find_by_sql(limit: 1))
    assert_name_arrays_equal(
      @agaricus.children(all: true).sort_by(&:id),
      query.find_by_sql(where: 'text_name LIKE "Agaricus %"')
    )
  end

  def test_tables_used
    query = Query.lookup(:Observation, by: :id)
    assert_equal([:observations], query.tables_used)

    query = Query.lookup(:Observation, by: :name)
    assert_equal([:names, :observations], query.tables_used)

    query = Query.lookup(:Image, by: :name)

    assert_equal([:images, :names, :observation_images, :observations],
                 query.tables_used)
    assert_equal(true, query.uses_table?(:images))
    assert_equal(true, query.uses_table?(:observation_images))
    assert_equal(true, query.uses_table?(:names))
    assert_equal(true, query.uses_table?(:observations))
    assert_equal(false, query.uses_table?(:comments))
  end

  def test_results
    query = Query.lookup(:User, by: :id)

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
    @pages = MOPaginator.new(number: number,
                             num_per_page: num_per_page)
    @query = Query.lookup(:Name, misspellings: :either, by: :id)
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
      @query.paginate_ids(@pages).map { |id| name_ids.index(id) + 1 }
    )
    assert_equal(@names.size, @pages.num_total)
    assert_name_arrays_equal(@names[from_nth..to_nth], @query.paginate(@pages))
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
    assert_equal(@letters, @pages.used_letters.sort)
  end

  def test_paginate_ells
    paginate_test_letter_setup(2, 3)
    @pages = MOPaginator.new(number: 2,
                             num_per_page: 3,
                             letter: "L")
    # Make sure we have a bunch of Lactarii, Leptiotas, etc.
    @ells = @names.select { |n| n.text_name[0, 1] == "L" }
    assert(@ells.length >= 9)
    assert_equal(@ells[3..5].map(&:id), @query.paginate_ids(@pages))
    assert_equal(@letters, @pages.used_letters.sort)
    assert_name_arrays_equal(@ells[3..5], @query.paginate(@pages))
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
    query = Query.lookup(:Name, misspellings: :either, by: :id)
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
  #  :section: Test Coerce
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
    query_a[0] = Query.lookup_and_save(:Observation, by: :id)
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
    query_a[0] = Query.lookup_and_save(:Observation, by: :id)
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

    assert_equal("id", obs_queries[0][:by])
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
    query_a[0] = Query.lookup_and_save(:Observation, by: :id)
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

  # def test_rss_log_coercion
  #   # The site index's default RssLog query should be relatable to queries on
  #   # the member classes, so that when a user clicks on an RssLog entry in the
  #   # main index and goes to a show_object page, they can continue to browse
  #   # results via prev/next.  (Actually, it handles this better now,
  #   # recognizing in next/prev_object that the query is on RssLog and can skip
  #   # between controllers while browsing the results, but still worth testing
  #   # this old mechanism, just in case.)

  #   # This is the default query for index.
  #   q1 = Query.lookup_and_save(:RssLog)

  #   # Click through to an item (User is expected to fail).
  #   q2 = q1.subquery_of(:Location)
  #   q3 = q1.subquery_of(:Name)
  #   q4 = q1.subquery_of(:Observation)
  #   q5 = q1.subquery_of(:SpeciesList)
  #   q6 = q1.subquery_of(:User)

  #   # Make sure they succeeded and created new queries.
  #   assert(q2)
  #   assert(q2.record.new_record?)
  #   assert_save(q2)
  #   assert(q3)
  #   assert(q3.record.new_record?)
  #   assert_save(q3)
  #   assert(q4)
  #   assert(q4.record.new_record?)
  #   assert_save(q4)
  #   assert(q5)
  #   assert(q5.record.new_record?)
  #   assert_save(q5)
  #   assert_nil(q6)

  #   # Make sure they are correct.
  #   assert_equal("Location",    q2.model.to_s)
  #   assert_equal("Name",        q3.model.to_s)
  #   assert_equal("Observation", q4.model.to_s)
  #   assert_equal("SpeciesList", q5.model.to_s)

  #   assert_equal(:rss_log, q2.params[:by].to_sym)
  #   assert_equal(:rss_log, q3.params[:by].to_sym)
  #   assert_equal(:rss_log, q4.params[:by].to_sym)
  #   assert_equal(:rss_log, q5.params[:by].to_sym)
  # end

  def test_relatable
    assert(Query.lookup(:Observation, by: :id).relatable?(:Image))
    assert_not(Query.lookup(:Herbarium, by: :id).relatable?(:Project))
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

  def test_location_ordering
    albion = locations(:albion)
    elgin_co = locations(:elgin_co)

    User.current = rolf
    assert_equal("postal", User.current_location_format)
    assert_query([albion, elgin_co],
                 :Location, id_in_set: [albion.id, elgin_co.id], by: :name)

    User.current = roy
    assert_equal("scientific", User.current_location_format)
    assert_query([elgin_co, albion],
                 :Location, id_in_set: [albion.id, elgin_co.id], by: :name)

    obs1 = observations(:minimal_unknown_obs)
    obs2 = observations(:detailed_unknown_obs)
    obs1.update(location: albion)
    obs2.update(location: elgin_co)

    User.current = rolf
    assert_equal("postal", User.current_location_format)
    assert_query([obs1, obs2],
                 :Observation, id_in_set: [obs1.id, obs2.id], by: :location)

    User.current = roy
    assert_equal("scientific", User.current_location_format)
    assert_query([obs2, obs1],
                 :Observation, id_in_set: [obs1.id, obs2.id], by: :location)
  end
end
