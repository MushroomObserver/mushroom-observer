# frozen_string_literal: true

require("test_helper")

class QueryTest < UnitTestCase
  def assert_query(expect, *args)
    test_ids = expect.first.is_a?(Integer)
    expect = expect.to_a unless expect.respond_to?(:map!)
    query = Query.lookup(*args)
    actual = test_ids ? query.result_ids : query.results
    msg = "Query results are wrong. SQL is:\n#{query.last_query}"
    if test_ids
      assert_equal(expect, actual, msg)
    else
      assert_obj_arrays_equal(expect, actual, msg)
    end
    type = args[0].to_s.underscore.to_sym.t.titleize.sub(/um$/, "(um|a)")
    assert_match(/#{type}|Advanced Search|(Lower|Higher) Taxa/, query.title)
    assert_not(query.title.include?("[:"),
               "Title contains undefined localizations: <#{query.title}>")
  end

  def clean(str)
    str.gsub(/\s+/, " ").strip
  end

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
    @fungi = names(:fungi)

    assert_raises(RuntimeError) { Query.lookup(:Name, xxx: true) }
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

    # assert_raises(RuntimeError) { Query.lookup(:Image) }
    assert_raises(RuntimeError) { Query.lookup(:Image, by_user: :bogus) }
    assert_raises(RuntimeError) { Query.lookup(:Image, by_user: "rolf") }
    assert_raises(RuntimeError) { Query.lookup(:Image, by_user: @fungi) }
    assert_equal(rolf.id,
                 Query.lookup(:Image, by_user: rolf).params[:by_user])
    assert_equal(rolf.id,
                 Query.lookup(:Image, by_user: rolf.id).params[:by_user])
    assert_equal(rolf.id,
                 Query.lookup(:Image, by_user: rolf.id.to_s).
                 params[:by_user])

    # Oops, this query is generic,
    # doesn't know to require Name instances here.
    # assert_raises(RuntimeError) { Query.lookup(:Name, ids: rolf) }
    assert_raises(RuntimeError) { Query.lookup(:Name, ids: "one") }
    assert_raises(RuntimeError) { Query.lookup(:Name, ids: "1,2,3") }
    assert_equal([names(:fungi).id],
                 Query.lookup(:Name,
                              ids: names(:fungi).id.to_s).params[:ids])

    # assert_raises(RuntimeError) { Query.lookup(:User) }
    assert_equal([], Query.lookup(:User, ids: []).params[:ids])
    assert_equal([rolf.id], Query.lookup(:User,
                                         ids: rolf.id).params[:ids])
    assert_equal([rolf.id, mary.id],
                 Query.lookup(:User,
                              ids: [rolf.id, mary.id]).params[:ids])
    assert_equal([1, 2],
                 Query.lookup(:User, ids: %w[1 2]).params[:ids])
    assert_equal([rolf.id, mary.id],
                 Query.lookup(:User,
                              ids: [rolf.id.to_s, mary.id.to_s]).params[:ids])
    assert_equal([rolf.id], Query.lookup(:User, ids: rolf).params[:ids])
    assert_equal([rolf.id, mary.id],
                 Query.lookup(:User, ids: [rolf, mary]).params[:ids])
    assert_equal([rolf.id, mary.id, junk.id],
                 Query.lookup(:User,
                              ids: [rolf, mary.id, junk.id.to_s]).params[:ids])

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

    assert_equal(["table"],
                 Query.lookup(:Name, join: :table).params[:join])
    assert_equal(%w[table1 table2],
                 Query.lookup(:Name, join: [:table1, :table2]).
                 params[:join])
    assert_equal(["table"],
                 Query.lookup(:Name, tables: :table).params[:tables])
    assert_equal(%w[table1 table2],
                 Query.lookup(:Name, tables: [:table1, :table2]).
                 params[:tables])
    assert_equal(["foo = bar"],
                 Query.lookup(:Name, where: "foo = bar").params[:where])
    assert_equal(["foo = bar", "id in (1,2,3)"],
                 Query.lookup(:Name,
                              where: ["foo = bar", "id in (1,2,3)"]).
                 params[:where])
    assert_equal("names.id",
                 Query.lookup(:Name, group: "names.id").params[:group])
    assert_equal("id DESC",
                 Query.lookup(:Name, order: "id DESC").params[:order])
    assert_raises(RuntimeError) { Query.lookup(:Name, group: %w[1 2]) }
    assert_raises(RuntimeError) { Query.lookup(:Name, order: %w[1 2]) }
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
    query = Query.lookup(:Name)
    assert_equal([["blah"]], query.google_parse("blah").goods)
    assert_equal([%w[foo bar]], query.google_parse("foo OR bar").goods)
    assert_equal([["one"], %w[foo bar], ["two"]],
                 query.google_parse("one foo OR bar two").goods)
    assert_equal([["one"], ["foo", "bar", "quoted phrase", "-gar"], ["two"]],
                 query.google_parse(
                   'one foo OR bar OR "quoted phrase" OR -gar two'
                 ).goods)
    assert_equal([], query.google_parse("-bad").goods)
    assert_equal(["bad"], query.google_parse("-bad").bads)
    assert_equal(["bad"], query.google_parse("foo -bad bar").bads)
    assert_equal(["bad wolf"], query.google_parse('foo -"bad wolf" bar').bads)
    assert_equal(["bad wolf", "foo", "bar"],
                 query.google_parse('-"bad wolf" -foo -bar').bads)
  end

  def test_google_conditions
    query = Query.lookup(:Name)
    assert_equal(
      ["x LIKE '%blah%'"],
      query.google_conditions(query.google_parse("blah"), "x")
    )
    assert_equal(
      ["x NOT LIKE '%bad%'"],
      query.google_conditions(query.google_parse("-bad"), "x")
    )
    assert_equal(
      ["x LIKE '%foo%' AND x NOT LIKE '%bad%'"],
      query.google_conditions(query.google_parse("foo -bad"), "x")
    )
    assert_equal(
      ["x LIKE '%foo%' AND x LIKE '%bar%' AND x NOT LIKE '%bad%'"],
      query.google_conditions(query.google_parse("foo bar -bad"), "x")
    )
    assert_equal(
      ["(x LIKE '%foo%' OR x LIKE '%bar%') AND x NOT LIKE '%bad%'"],
      query.google_conditions(query.google_parse("foo OR bar -bad"), "x")
    )
    assert_equal(
      ["(x LIKE '%foo%' OR x LIKE '%bar%' OR x LIKE '%any%thing%') " \
        "AND x LIKE '%surprise!%' AND x NOT LIKE '%bad%' " \
        "AND x NOT LIKE '%lost boys%'"],
      query.google_conditions(
        query.google_parse(
          'foo OR bar OR "any*thing" -bad surprise! -"lost boys"'
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
      clean(query.query)
    )
    assert_equal(
      "SELECT foo bar FROM `names`",
      clean(query.query(select: "foo bar"))
    )
    assert_equal(
      "SELECT DISTINCT names.id FROM `names` " \
      "JOIN `rss_logs` ON names.rss_log_id = rss_logs.id",
      clean(query.query(join: :rss_logs))
    )
    assert_equal(
      "SELECT DISTINCT names.id FROM `names` " \
      "JOIN `observations` ON observations.name_id = names.id " \
      "JOIN `rss_logs` ON observations.rss_log_id = rss_logs.id",
      clean(query.query(join: { observations: :rss_logs }))
    )
    assert_equal(
      "SELECT DISTINCT names.id FROM `names`, `rss_logs`",
      clean(query.query(tables: :rss_logs))
    )
    assert_equal(
      "SELECT DISTINCT names.id FROM `names`, `images`, `comments`",
      clean(query.query(tables: [:images, :comments]))
    )
    assert_equal(
      "SELECT DISTINCT names.id FROM `names` WHERE shazam!",
      clean(query.query(where: "shazam!"))
    )
    assert_equal(
      "SELECT DISTINCT names.id FROM `names` WHERE foo AND bar",
      clean(query.query(where: %w[foo bar]))
    )
    assert_equal(
      "SELECT DISTINCT names.id FROM `names` WHERE foo AND bar",
      clean(query.query(where: %w[foo bar]))
    )
    assert_equal(
      "SELECT DISTINCT names.id FROM `names` GROUP BY blah blah blah",
      clean(query.query(group: "blah blah blah"))
    )
    assert_equal(
      "SELECT DISTINCT names.id FROM `names` ORDER BY foo, bar, names.id DESC",
      # (tacks on 'id DESC' for disambiguation)
      clean(query.query(order: "foo, bar"))
    )
    assert_equal(
      "SELECT DISTINCT names.id FROM `names` ORDER BY comments.id ASC",
      clean(query.query(order: "comments.id ASC")) # (sees id in there already)
    )
    assert_equal(
      "SELECT DISTINCT names.id FROM `names` LIMIT 10",
      clean(query.query(limit: 10))
    )

    # Now, all together...
    assert_equal(
      "SELECT names.* FROM `names`, `images` " \
      "JOIN `observations` ON observations.name_id = names.id " \
      "JOIN `users` ON names.reviewer_id = users.id " \
      "WHERE one = two AND foo LIKE bar " \
      "GROUP BY blah.id ORDER BY names.id ASC LIMIT 10, 10",
      clean(query.query(select: "names.*",
                        join: [:observations, :"users.reviewer"],
                        tables: :images,
                        where: ["one = two", "foo LIKE bar"],
                        group: "blah.id",
                        order: "names.id ASC",
                        limit: "10, 10"))
    )
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
    sql = query.query(
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
    assert_match(/observations.rss_log_id = rss_logs.id/, query.query)

    # And use rss_logs.observation_id = observations.id the other way.
    query = Query.lookup(:RssLog)
    query.initialize_query
    query.join << :observations
    assert_match(/rss_logs.observation_id = observations.id/, query.query)
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

    assert_equal(Name.first.id, query.select_value)
    assert_equal(Name.offset(10).first.id,
                 query.select_value(limit: "10, 10")) # 11th id
    assert_equal(Name.last.id, query.select_value(order: :reverse)) # last id
    assert_equal(Name.first.text_name,
                 query.select_value(select: "text_name").to_s)

    assert_equal(Name.all.map { |name| name.id.to_s },
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

    assert_equal(Name.all.map { |x| [x.id] }, query.select_rows)
    assert_equal(Name.all.map { |x| { "id" => x.id } }, query.select_all)
    assert_equal({ "id" => Name.first.id }, query.select_one)

    assert_equal([Name.first], query.find_by_sql(limit: 1))
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
    assert_equal(User.all.find_index(junk), query.index(junk))
    assert_equal(User.all.find_index(dick), query.index(dick))
    assert_equal(User.all.find_index(mary), query.index(mary))

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
    @names = Name.order(:id)
    @pages = MOPaginator.new(number: number,
                             num_per_page: num_per_page)
    @query = Query.lookup(:Name, misspellings: :either, by: :id)
  end

  def paginate_test(number, num_per_page, expected_nths)
    paginate_test_setup(number, num_per_page)
    paginate_assertions(number, num_per_page, expected_nths)
  end

  # parameters are the ordinals of objects which have been ordered by id
  # E.g., 1 corresponds to Name.all.order(:id).first
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
    @query.need_letters = "names.text_name"
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

    first = query.instantiate([ids[0]]).first
    assert_not(first.images.loaded?)

    first = query.instantiate([ids[0]], include: :images).first
    assert_not(first.images.loaded?)

    # Have to test it on a different one, because first is now cached.
    second = query.instantiate([ids[1]], include: :images).first
    assert(second.images.loaded?)

    # Or we can clear out the cache and it will work...
    query.clear_cache
    first = query.instantiate([ids[0]], include: :images).first
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
    @names = Name.all

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

  def test_inner_outer
    outer = Query.lookup_and_save(:Observation, by: :id)

    q = Query.lookup(
      :Image,
      outer: outer,
      observation: observations(:minimal_unknown_obs).id, by: :id
    )
    assert_equal([], q.result_ids)

    # Because autogenerated fixture ids order is unpredictable, track which
    # observations and images go with each inner query.
    inners_details = [
      { obs: observations(:wolf_fart).id,
        # wolf_fart issue.  Switch comments for next 2 lines
        imgs: [images(:lone_wolf_image).id] },
      # imgs: [images(:lone_wolf_image2).id, images(:lone_wolf_image).id] },
      { obs: observations(:detailed_unknown_obs).id,
        imgs: [images(:in_situ_image).id, images(:turned_over_image).id] },
      { obs: observations(:coprinus_comatus_obs).id,
        imgs: [images(:connected_coprinus_comatus_image).id] },
      { obs: observations(:agaricus_campestris_obs).id,
        imgs: [images(:agaricus_campestris_image).id] },
      { obs: observations(:peltigera_obs).id,
        imgs: [images(:peltigera_image).id] }
    ]

    inner1 = Query.lookup_and_save(
      :Image,
      outer: outer,
      observation: inners_details.first[:obs], by: :id
    )
    assert_equal(inners_details.first[:imgs], inner1.result_ids)

    inner2 = Query.lookup_and_save(
      :Image,
      outer: outer,
      observation: inners_details.second[:obs], by: :id
    )
    assert_equal(inners_details.second[:imgs], inner2.result_ids)

    inner3 = Query.lookup_and_save(
      :Image,
      outer: outer,
      observation: inners_details.third[:obs], by: :id
    )
    assert_equal(inners_details.third[:imgs], inner3.result_ids)

    inner4 = Query.lookup_and_save(
      :Image,
      outer: outer,
      observation: inners_details.fourth[:obs], by: :id
    )
    assert_equal(inners_details.fourth[:imgs], inner4.result_ids)

    inner5 = Query.lookup_and_save(
      :Image,
      outer: outer,
      observation: inners_details.fifth[:obs], by: :id
    )
    assert_equal(inners_details.fifth[:imgs], inner5.result_ids)

    # Now that inner queries are defined, add them to inners_details
    inners_details.first[:inner]  = inner1
    inners_details.second[:inner] = inner2
    inners_details.third[:inner]  = inner3
    inners_details.fourth[:inner] = inner4
    inners_details.fifth[:inner]  = inner5

    # calculate some other details
    inners_query_ids = inners_details.map { |n| n[:inner].record.id }.sort
    inners_obs_ids = inners_details.pluck(:obs).sort

    assert(inner1.outer?)
    # it's been tweaked but still same id
    assert_equal(outer.record.id, inner1.outer.record.id)
    assert_equal(inners_details.first[:obs],  inner1.get_outer_current_id)
    assert_equal(inners_details.second[:obs], inner2.get_outer_current_id)
    assert_equal(inners_details.third[:obs],  inner3.get_outer_current_id)
    assert_equal(inners_details.fourth[:obs], inner4.get_outer_current_id)
    assert_equal(inners_details.fifth[:obs],  inner5.get_outer_current_id)

    # inner1: Images in Observations
    # inner1's outer:  all Observations by id
    # inner1.outer should be all Observations with images, sorted by id
    q = inner1.outer
    results = q.result_ids
    assert_equal(
      obs_with_imgs_ids, results,
      "inner1.outer missing images #{obs_with_imgs_ids - results}\n" \
      "query was #{q.last_query}\n"
    )

    # Following tests if results contain all inners_outer_obs_ids -- in order.
    # (Works because each is: (a) sorted, and (b) has no duplicate entries.
    missing_obs_ids = inners_obs_ids - results
    assert_empty(missing_obs_ids,
                 "inner1.outer results missing observations #{missing_obs_ids}")

    q.current_id = results[1]
    assert_equal(q, q.first)
    assert_equal(results[0], q.current_id)
    assert_equal(q, q.last)
    assert_equal(results[-1], q.current_id)

    ##### Test next and previous on the query results. #####
    # (Results are images of all obs with images, not just inner1 - inner5.)
    non_uniq_imgs_with_obs_count = Image.joins(:observations).size

    # Get 1st result, which is 1st image of 1st imaged observation
    obs = obs_with_imgs_ids.first
    imgs = Observation.find(obs).images.reorder(id: :asc).map(&:id)
    img = imgs.first
    qr = QueryRecord.where(
      QueryRecord[:description].matches_regexp("observation=##{obs}")
    ).first
    q = Query.deserialize(qr.description)
    q_first_query = q.first
    q_last_query = q.last
    q.current_id = img

    assert_nil(q.prev,
               "Result for obs #{obs}, image #{q.current_id} is not the first")

    ### Use next to step forward through the other results, ###
    # checking for the right query, observation, and image
    (non_uniq_imgs_with_obs_count - 1).times do
      obs, imgs, img = next_result(obs, imgs, img)
      q = q.next
      # Are we looking at the right obs and query?
      if inners_obs_ids.include?(obs)
        # The next list throws an error buried in active_record.rb if the
        # :wolf_fart observation has a second image.  Apparently the @record
        # doesn't get set.  It appears to be trying to store some info about
        # the next image.
        assert(
          inners_query_ids.include?(q.id),
          "A Query for Observation #{obs} should be in inner1 - inner5"
        )
        assert_equal(
          inners_details.find { |n| n[:obs] == obs }[:inner].id, q.id,
          "Query #{q.id} is not the inner for Observation #{obs}"
        )
      else
        assert_not(inners_query_ids.include?(q.id),
                   "Observation #{obs} should not be in inner1 - inner5")
      end
      # And at the right image?
      assert_equal(img, q.current_id)
    end

    # Are we at the last result?
    assert_equal(q_last_query, q, "Current query is not the last")
    assert_nil(q.last.next, "Failed to get to last result")
    assert_equal(obs_with_imgs_ids.last, obs,
                 "Last result not for the last Observation with an Image")
    assert_equal(Observation.find(obs).images.last.id, img,
                 "Last result not for last Image in last Observation result")

    ### Use prev to step back through the results, ###
    # again checking for the right query, observation, and image
    (non_uniq_imgs_with_obs_count - 1).times do
      obs, imgs, img = prev_result(obs, imgs, img)
      q = q.prev
      # Are we looking at the right obs and query?
      if inners_obs_ids.include?(obs)
        assert(inners_query_ids.include?(q.id),
               "A Query for Observation #{obs} should be in inner1 - inner5")
        assert_equal(
          inners_details.find { |n| n[:obs] == obs }[:inner].id, q.id,
          "Query #{q.id} is not the inner for Observation #{obs}"
        )
      else
        assert_not(inners_query_ids.include?(q.id),
                   "Observation #{obs} should not be in inner1 - inner5")
      end
      # And at the right image?
      assert_equal(img, q.current_id)
    end

    # Are we back at the first result?
    assert_equal(q_first_query, q, "Current query is not the first")
    assert_nil(q.prev, "Failed to step back to first result")
    assert_equal(obs_with_imgs_ids.first, obs,
                 "First result not for the first Observation with an Image")
    assert_equal(Observation.find(obs).images.reorder(id: :asc).first.id, img,
                 "First result not for first Image in an Observation")

    # Can we get to first query directly from an intermediate query?
    q = q.next
    assert_equal(q_first_query, q.first)
  end

  def obs_with_imgs_ids
    Observation.distinct.joins(:images).reorder(id: :asc).map(&:id)
  end

  # Return next result's: observation.id, image.id list, image.id
  # If no more results, then returned obs will be nil
  # For previoua result, call with inc = -1
  # usage: obs, imgs, img = next_result(obs, imgs, img)
  #        obs, imgs, img = next_result(obs, imgs, img, -1)
  def next_result(obs, imgs, img, inc = 1)
    next_idx = imgs.index(img) + inc
    # if there's another img for this obs, just get it
    if next_idx.between?(0, imgs.count - 1)
      img = imgs[next_idx]
    # else get the next obs, if there is one
    elsif (obs = obs_with_imgs_ids[obs_with_imgs_ids.index(obs) + inc])
      # get its list of image ids
      imgs = Observation.find(obs).images.reorder(id: :asc).map(&:id)
      # get first or last image in the list
      # depending on whether were going forward or back through results
      img = inc.positive? ? imgs.first : imgs.last
    end
    [obs, imgs, img]
  end

  def prev_result(obs, imgs, img)
    next_result(obs, imgs, img, -1)
  end

  ##############################################################################
  #
  #  :section: Test Coerce
  #
  ##############################################################################

  def test_basic_coerce
    assert_equal(0, QueryRecord.count)

    q1 = Query.lookup_and_save(:Observation, pattern: "search")
    assert_equal(1, QueryRecord.count)

    # Trvial coercion: from a model to the same model.
    q2 = q1.coerce(:Observation)
    assert_equal(q1, q2)
    assert_equal(1, QueryRecord.count)

    # No search is coercable to RssLog (yet).
    q3 = q1.coerce(:RssLog)
    assert_nil(q3)
    assert_equal(1, QueryRecord.count)
  end

  def three_amigos
    [observations(:detailed_unknown_obs).id,
     observations(:agaricus_campestris_obs).id,
     observations(:agaricus_campestras_obs).id]
  end

  def test_observation_image_coercion
    burbank = locations(:burbank)
    query_a = []

    # Several observation queries can be turned into image queries.
    query_a[0] = Query.lookup_and_save(:Observation, by: :id)
    query_a[1] = Query.lookup_and_save(:Observation, by_user: mary.id)
    query_a[2] = Query.lookup_and_save(
      :Observation, species_list: species_lists(:first_species_list).id
    )
    query_a[3] = Query.lookup_and_save(:Observation, ids: three_amigos)
    query_a[4] = Query.lookup_and_save(:Observation, user_where: "glendale")
    query_a[5] = Query.lookup_and_save(:Observation, location: burbank)
    query_a[6] = Query.lookup_and_save(:Observation, user_where: "california")
    # removed query_a[7] which searched for "somewhere else" in the notes
    # query_a[7] = Query.lookup_and_save(:Observation,
    #                                    pattern: '"somewhere else"')
    assert_equal(7, QueryRecord.count)

    observation_coercion_assertions(query_a, :Image)
  end

  def test_observation_location_coercion
    burbank = locations(:burbank)
    query_a = []

    # Almost any query on observations should be mappable, i.e. coercable into
    # a query on those observations' locations.
    query_a[0] = Query.lookup_and_save(:Observation, by: :id)
    query_a[1] = Query.lookup_and_save(:Observation, by_user: mary.id)
    query_a[2] = Query.lookup_and_save(
      :Observation, species_list: species_lists(:first_species_list).id
    )
    query_a[3] = Query.lookup_and_save(:Observation, ids: three_amigos)
    query_a[4] = Query.lookup_and_save(:Observation, user_where: "glendale")
    query_a[5] = Query.lookup_and_save(:Observation, location: burbank)
    query_a[6] = Query.lookup_and_save(:Observation, user_where: "california")
    # query_a[7] = Query.lookup_and_save(:Observation,
    #                                    pattern: '"somewhere else"')
    assert_equal(7, QueryRecord.count)

    query_b = observation_coercion_assertions(query_a, :Location)

    # Now, check the parameters of those coerced queries.
    assert_equal("id", query_b[0].params[:old_by])
    assert_equal(mary.id, query_b[1].params[:by_user])
    assert_equal(species_lists(:first_species_list).id,
                 query_b[2].params[:species_list])
    assert_equal(three_amigos, query_b[3].params[:obs_ids])
    assert_equal(2, query_b[3].params.keys.length)
    assert_equal("glendale", query_b[4].params[:user_where])
    assert_equal(3, query_b[4].params.keys.length)
    assert_equal(burbank.id, query_b[5].params[:location])
    assert_equal(2, query_b[5].params.keys.length)
    assert_equal("california", query_b[6].params[:user_where])
    assert_equal(3, query_b[6].params.keys.length)
    # assert_equal(2, query_b[7].params.keys.length)
    # assert_equal([observations(:strobilurus_diminutivus_obs).id,
    #               observations(:agaricus_campestros_obs).id,
    #               observations(:agaricus_campestras_obs).id,
    #               observations(:agaricus_campestrus_obs).id],
    #              query_b[7].params[:obs_ids])
    # assert_match(/Observations.*Matching.*somewhere.*else/,
    #              query_b[7].params[:old_title])
  end

  def test_observation_name_coercion
    burbank = locations(:burbank)
    query_a = []

    # Several observation queries can be turned into name queries.
    query_a[0] = Query.lookup_and_save(:Observation, by: :id)
    query_a[1] = Query.lookup_and_save(:Observation, by_user: mary.id)
    query_a[2] = Query.lookup_and_save(
      :Observation, species_list: species_lists(:first_species_list).id
    )
    query_a[3] = Query.lookup_and_save(:Observation, ids: three_amigos)
    # qa[4] = Query.lookup_and_save(:Observation,
    #                             pattern: '"somewhere else"')
    query_a[4] = Query.lookup_and_save(:Observation, user_where: "glendale")
    query_a[5] = Query.lookup_and_save(:Observation, location: burbank)
    query_a[6] = Query.lookup_and_save(:Observation, user_where: "california")
    assert_equal(7, QueryRecord.count)

    observation_coercion_assertions(query_a, :Name)
  end

  # General purpose repetitive assertions for coercing observation queries.
  # query_a is original, query_b is coerced, and query_c is coerced back.
  # Returns the coerced query (query_check) for further testing
  def observation_coercion_assertions(query_a, model)
    query_b = query_c = []
    len = query_a.size - 1

    [*0..len].each do |i|
      # Try coercing them all.
      assert(query_b[i] = query_a[i].coerce(model))

      # They should all be new records
      assert(query_b[i].record.new_record?)
      assert_save(query_b[i])

      # Check the query descriptions.
      assert_equal(model.to_s, query_b[i].model.to_s)
      assert(query_b[i].params[:with_observations])
    end

    # The `coerce` changes query_b, so save it for later comparison.
    query_check = query_b.dup

    [*0..len].each do |i|
      # Now try to coerce them back to Observation.
      assert(query_c[i] = query_b[i].coerce(:Observation))

      # They should not be new records
      assert_not(query_c[i].record.new_record?)
      assert_equal(query_a[i], query_c[i])
    end

    query_check
  end

  def test_name_description_coercion
    ds1 = name_descriptions(:coprinus_comatus_desc)
    ds2 = name_descriptions(:peltigera_desc)
    description_coercion_assertions(ds1, ds2, :Name)
  end

  def description_coercion_assertions(ds1, ds2, model)
    qa = qb = qc = []

    desc_model = :"#{model}Description"
    # Several description queries can be turned into name queries and back.
    qa[0] = Query.lookup_and_save(desc_model)
    qa[1] = Query.lookup_and_save(desc_model, by_author: rolf.id)
    qa[2] = Query.lookup_and_save(desc_model, by_editor: rolf.id)
    qa[3] = Query.lookup_and_save(desc_model, by_user: rolf.id)
    qa[4] = Query.lookup_and_save(desc_model, ids: [ds1.id, ds2.id])
    assert_equal(5, QueryRecord.count)

    # Try coercing them into name queries.
    [*0..4].each do |i|
      assert(qb[i] = qa[i].coerce(model))
      # They should all be new records
      assert(qb[i].record.new_record?)
      assert_save(qb[i])
      assert_equal(model.to_s, qb[i].model.to_s)
      assert(qb[i].params[:with_descriptions])
    end
    # Make sure they're right.
    assert_equal(rolf.id, qb[1].params[:by_author])
    assert_equal(rolf.id, qb[2].params[:by_editor])
    assert_equal(rolf.id, qb[3].params[:by_user])
    assert_equal([ds1.id, ds2.id], qb[4].params[:desc_ids])

    # Try coercing them back.
    # None should be new records
    [*0..4].each do |i|
      assert(qc[i] = qb[i].coerce(desc_model))
      assert_equal(qa[i], qc[i])
    end
  end

  def test_rss_log_coercion
    # The site index's default RssLog query should be coercable into queries on
    # the member classes, so that when a user clicks on an RssLog entry in the
    # main index and goes to a show_object page, they can continue to browse
    # results via prev/next.  (Actually, it handles this better now,
    # recognizing in next/prev_object that the query is on RssLog and can skip
    # between controllers while browsing the results, but still worth testing
    # this old mechanism, just in case.)

    # This is the default query for index.
    q1 = Query.lookup_and_save(:RssLog)

    # Click through to an item (User is expected to fail).
    q2 = q1.coerce(:Location)
    q3 = q1.coerce(:Name)
    q4 = q1.coerce(:Observation)
    q5 = q1.coerce(:SpeciesList)
    q6 = q1.coerce(:User)

    # Make sure they succeeded and created new queries.
    assert(q2)
    assert(q2.record.new_record?)
    assert_save(q2)
    assert(q3)
    assert(q3.record.new_record?)
    assert_save(q3)
    assert(q4)
    assert(q4.record.new_record?)
    assert_save(q4)
    assert(q5)
    assert(q5.record.new_record?)
    assert_save(q5)
    assert_nil(q6)

    # Make sure they are correct.
    assert_equal("Location",    q2.model.to_s)
    assert_equal("Name",        q3.model.to_s)
    assert_equal("Observation", q4.model.to_s)
    assert_equal("SpeciesList", q5.model.to_s)

    assert_equal(:rss_log, q2.params[:by].to_sym)
    assert_equal(:rss_log, q3.params[:by].to_sym)
    assert_equal(:rss_log, q4.params[:by].to_sym)
    assert_equal(:rss_log, q5.params[:by].to_sym)
  end

  def test_coercable
    assert(Query.lookup(:Observation, by: :id).coercable?(:Image))
    assert_not(Query.lookup(:Herbarium, by: :id).coercable?(:Project))
  end

  ##############################################################################
  #
  #  :section: Test Query Results
  #
  ##############################################################################

  def test_article_all
    expects = Article.all
    assert_query(expects, :Article)
  end

  def test_article_by_rss_log
    assert_query(Article.joins(:rss_log).distinct, :Article, by: :rss_log)
  end

  def test_article_in_set
    assert_query([articles(:premier_article).id], :Article,
                 ids: [articles(:premier_article).id])
    assert_query([], :Article, ids: [])
  end

  def test_collection_number_all
    expect = CollectionNumber.all
    assert_query(expect, :CollectionNumber)
  end

  def test_collection_number_for_observation
    obs = observations(:detailed_unknown_obs)
    expects = CollectionNumber.for_observation(obs)
    assert_query(expects, :CollectionNumber, observation: obs.id)
  end

  def test_collection_number_pattern_search
    expects = CollectionNumber.
              where(CollectionNumber[:name].matches("%Singer%").
                    or(CollectionNumber[:number].matches("%Singer%"))).
              sort_by(&:format_name)
    assert_query(expects, :CollectionNumber, pattern: "Singer")

    expects = CollectionNumber.
              where(CollectionNumber[:name].matches("%123a%").
                    or(CollectionNumber[:number].matches("%123a%"))).
              sort_by(&:format_name)
    assert_query(expects, :CollectionNumber, pattern: "123a")
  end

  def test_comment_all
    expects = Comment.all
    assert_query(expects, :Comment)
  end

  def test_comment_by_user
    expects = Comment.where(user_id: mary.id).distinct
    assert_query(expects, :Comment, by_user: mary)
  end

  def test_comment_for_target
    obs = observations(:minimal_unknown_obs)
    expects = Comment.where(target_id: obs.id).distinct
    assert_query(expects, :Comment, target: obs, type: "Observation")
  end

  def test_comment_for_user
    expects = Comment.all.select { |c| c.target.user == mary }
    # expects = Comment.joins(:target).where(targets: { user_id: mary.id }).uniq
    assert_query(expects, :Comment, for_user: mary)
    assert_query([], :Comment, for_user: rolf)
  end

  def test_comment_in_set
    assert_query([comments(:detailed_unknown_obs_comment).id,
                  comments(:minimal_unknown_obs_comment_1).id],
                 :Comment,
                 ids: [comments(:detailed_unknown_obs_comment).id,
                       comments(:minimal_unknown_obs_comment_1).id])
  end

  def test_comment_pattern_search
    expects = Comment.where(Comment[:summary].matches("%unknown%").
                            or(Comment[:comment].matches("%unknown%"))).uniq
    assert_query(expects, :Comment, pattern: "unknown")
  end

  def test_external_link_all
    assert_query(ExternalLink.all.sort_by(&:url), :ExternalLink)
    assert_query(ExternalLink.where(user: users(:mary)).sort_by(&:url),
                 :ExternalLink, users: users(:mary))
    assert_query([], :ExternalLink, users: users(:dick))
    obs = observations(:coprinus_comatus_obs)
    assert_query(obs.external_links.sort_by(&:url),
                 :ExternalLink, observations: obs)
    obs = observations(:detailed_unknown_obs)
    assert_query([], :ExternalLink, observations: obs)
    site = external_sites(:mycoportal)
    assert_query(site.external_links.sort_by(&:url),
                 :ExternalLink, external_sites: site)
    site = external_sites(:inaturalist)
    assert_query(site.external_links.sort_by(&:url),
                 :ExternalLink, external_sites: site)
    assert_query(site.external_links.sort_by(&:url),
                 :ExternalLink, url: "iNaturalist")
  end

  # In the model these are all getting a default_scope order: :code thrown on.
  def test_field_slip_all
    expects = FieldSlip.all
    assert_query(expects, :FieldSlip)
  end

  def test_field_slip_by_user
    expects = FieldSlip.by_user(mary)
    assert_query(expects, :FieldSlip, by_user: mary)
  end

  def test_field_slip_for_project
    expects = FieldSlip.where(project: projects(:eol_project))
    assert_query(expects, :FieldSlip, project: projects(:eol_project))
  end

  def test_glossary_term_all
    expects = GlossaryTerm.all
    assert_query(expects, :GlossaryTerm)
  end

  def test_glossary_term_pattern_search
    assert_query([], :GlossaryTerm, pattern: "no glossary term has this")
    # name
    expects = GlossaryTerm.
              where(GlossaryTerm[:name].matches("%conic_glossary_term%").
              or(GlossaryTerm[:description].matches("%conic_glossary_term%"))).
              distinct
    assert_query(expects, :GlossaryTerm, pattern: "conic_glossary_term")
    # description
    expects =
      GlossaryTerm.where(GlossaryTerm[:name].matches("%Description%")).
      where(GlossaryTerm[:name].matches("%of%")).
      where(GlossaryTerm[:name].matches("%Term%")).
      or(
        GlossaryTerm.where(GlossaryTerm[:description].matches("%Description%")).
        where(GlossaryTerm[:description].matches("%of%")).
        where(GlossaryTerm[:description].matches("%Term%"))
      ).distinct
    assert_query(expects, :GlossaryTerm, pattern: "Description of Term")
    # blank
    expects = GlossaryTerm.all
    assert_query(expects, :GlossaryTerm, pattern: "")
  end

  def test_herbarium_all
    expect = Herbarium.all
    assert_query(expect.select(:id).distinct, :Herbarium)
  end

  def test_herbarium_by_records
    expect = Herbarium.left_outer_joins(:herbarium_records).group(:id).
             # Wrap known safe argument in Arel
             # to prevent "Dangerous query method" Deprecation Warning
             reorder(HerbariumRecord[:id].count.desc, Herbarium[:id].desc)
    assert_query(expect, :Herbarium, by: :records)
  end

  def test_herbarium_in_set
    expect = [
      herbaria(:dick_herbarium),
      herbaria(:nybg_herbarium)
    ]
    assert_query(expect, :Herbarium, ids: expect)
  end

  def test_herbarium_pattern_search
    # [herbaria(:nybg_herbarium)]
    expects = Herbarium.where(
      Herbarium[:code].concat(Herbarium[:name]).
      concat(Herbarium[:description].coalesce("")).
      concat(Herbarium[:mailing_address].coalesce("")).matches("%awesome%")
    ).distinct

    assert_query(expects, :Herbarium, pattern: "awesome")
  end

  def test_herbarium_record_all
    expect = HerbariumRecord.all
    assert_query(expect, :HerbariumRecord)
  end

  def test_herbarium_record_for_observation
    obs = observations(:coprinus_comatus_obs)
    expect = HerbariumRecord.for_observation(obs)
    assert_query(expect, :HerbariumRecord, observation: obs.id)
  end

  def test_herbarium_record_in_herbarium
    nybg = herbaria(:nybg_herbarium)
    expect = HerbariumRecord.where(herbarium: nybg)
    assert_query(expect, :HerbariumRecord, herbarium: nybg.id)
  end

  def test_herbarium_record_pattern_search_notes
    expects = herbarium_record_pattern_search("dried")
    assert_query(expects, :HerbariumRecord, pattern: "dried")
  end

  def test_herbarium_record_pattern_search_not_findable
    assert_query([], :HerbariumRecord,
                 pattern: "no herbarium record has this")
  end

  def test_herbarium_record_pattern_search_initial_det
    expects = herbarium_record_pattern_search("Agaricus")
    assert_query(expects, :HerbariumRecord, pattern: "Agaricus")
  end

  def test_herbarium_record_pattern_search_accession_number
    expects = herbarium_record_pattern_search("123a")
    assert_query(expects, :HerbariumRecord, pattern: "123a")
  end

  def test_herbarium_record_pattern_search_blank
    expects = HerbariumRecord.all
    assert_query(expects, :HerbariumRecord, pattern: "")
  end

  def herbarium_record_pattern_search(pattern)
    HerbariumRecord.where(
      HerbariumRecord[:initial_det].concat(HerbariumRecord[:accession_number]).
      concat(HerbariumRecord[:notes].coalesce("")).matches("%#{pattern}%")
    ).distinct
  end

  def test_image_all
    expects = Image.all
    assert_query(expects, :Image)
  end

  def test_image_for_observations
    obs = observations(:two_img_obs)
    expects = Image.joins(:observations).where(observations: { id: obs.id }).
              distinct
    assert_query(expects, :Image, observations: obs)
  end

  def test_image_for_projects
    project = projects(:bolete_project)
    expects = Image.joins(:projects).where(projects: { id: project.id }).
              distinct
    assert_query(expects, :Image, projects: [project.title])
  end

  def test_image_by_user
    expect = Image.where(user_id: rolf.id).distinct
    assert_query(expect, :Image, by_user: rolf)
    expect = Image.where(user_id: mary.id).distinct
    assert_query(expect, :Image, by_user: mary)
    expect = Image.where(user_id: dick.id).distinct
    assert_query(expect, :Image, by_user: dick)
  end

  def test_image_in_set
    ids = [images(:turned_over_image).id,
           images(:agaricus_campestris_image).id,
           images(:disconnected_coprinus_comatus_image).id]
    assert_query(ids, :Image, ids: ids)
  end

  def test_image_inside_observation
    obs = observations(:detailed_unknown_obs)
    assert_equal(2, obs.images.length)
    expect = obs.images.sort_by(&:id)
    assert_query(expect, :Image,
                 observation: obs, outer: 1) # (outer is only used by prev/next)
    obs = observations(:minimal_unknown_obs)
    assert_equal(0, obs.images.length)
    assert_query(obs.images, :Image,
                 observation: obs, outer: 1) # (outer is only used by prev/next)
  end

  def test_image_for_project
    project = projects(:bolete_project)
    expects = Image.joins(:project_images).
              where(project_images: { project: project }).reorder(id: :asc)
    assert_query(expects, :Image, project: project, by: :id)
    assert_query([], :Image, project: projects(:empty_project))
  end

  def test_image_advanced_search_name
    # expects = [] # [images(:agaricus_campestris_image).id]
    expects = Image.joins(observations: :name).
              where(Name[:search_name].matches("%Agaricus%")).distinct
    assert_query(expects, :Image, name: "Agaricus")
  end

  def test_image_advanced_search_user_where
    expects = Image.joins(:observations).
              where(Observation[:where].matches("%burbank%")).
              where(observations: { is_collection_location: true }).distinct
    assert_query(expects, :Image, user_where: "burbank")

    assert_query([images(:connected_coprinus_comatus_image).id],
                 :Image, user_where: "glendale")
  end

  def test_image_advanced_search_user
    expects = Image.joins(observations: :user).
              where(observations: { user: mary }).
              order(Image[:created_at].desc, Image[:id].desc).uniq
    assert_query(expects, :Image, user: "mary")
  end

  def test_image_advanced_search_content
    assert_query([images(:turned_over_image).id, images(:in_situ_image).id],
                 :Image, content: "little")
    assert_query([images(:connected_coprinus_comatus_image).id],
                 :Image, content: "fruiting")
  end

  def test_image_advanced_search_combos
    assert_query([],
                 :Image, name: "agaricus", user_where: "glendale")
    assert_query([images(:agaricus_campestris_image).id],
                 :Image, name: "agaricus", user_where: "burbank")
    assert_query([images(:turned_over_image).id, images(:in_situ_image).id],
                 :Image, content: "little", user_where: "burbank")
  end

  def test_image_pattern_search
    assert_query([images(:agaricus_campestris_image).id],
                 :Image, pattern: "agaricus") # name
    assert_query([images(:agaricus_campestris_image).id,
                  images(:connected_coprinus_comatus_image).id,
                  images(:turned_over_image).id,
                  images(:in_situ_image).id],
                 :Image, pattern: "bob dob") # copyright holder
    assert_query(
      [images(:in_situ_image).id],
      :Image, pattern: "looked gorilla OR original" # notes
    )
    assert_query([images(:agaricus_campestris_image).id,
                  images(:connected_coprinus_comatus_image).id],
                 :Image, pattern: "notes some") # notes
    assert_query(
      [images(:turned_over_image).id, images(:in_situ_image).id],
      :Image, pattern: "dobbs -notes" # (c), not notes
    )
    assert_query([images(:in_situ_image).id], :Image,
                 pattern: "DSCN8835") # original filename
  end

  def test_image_with_observations
    expect = Image.includes(:observations).
             where.not(observations: { thumb_image: nil }).
             order(Image[:created_at].desc, Image[:id].desc).uniq
    assert_query(expect, :Image, with_observations: true)
  end

  # Prove that :with_observations param of Image Query works with each
  # parameter P for which (a) there's no other test of P for
  # Image, OR (b) P behaves differently in :with_observations than in
  # all other params of Image Query's.

  ##### date/time parameters #####

  def test_image_with_observations_created_at
    created_at = observations(:detailed_unknown_obs).created_at
    expect = Image.joins(:observations).
             where(Observation[:created_at] >= created_at).
             order(Image[:created_at].desc, Image[:id].desc).uniq
    assert_not_empty(expect, "'expect` is broken; it should not be empty")
    assert_query(expect, :Image,
                 with_observations: 1, created_at: created_at)
  end

  def test_image_with_observations_updated_at
    updated_at = observations(:detailed_unknown_obs).updated_at
    expect = Image.joins(:observations).
             where(Observation[:updated_at] >= updated_at).
             order(Image[:created_at].desc, Image[:id].desc).uniq
    assert_not_empty(expect, "'expect` is broken; it should not be empty")
    assert_query(expect, :Image,
                 with_observations: 1, updated_at: updated_at)
  end

  def test_image_with_observations_date
    date = observations(:detailed_unknown_obs).when
    expect = Image.joins(:observations).where(Observation[:when] >= date).
             order(Image[:created_at].desc, Image[:id].desc).uniq
    assert_not_empty(expect, "'expect` is broken; it should not be empty")
    assert_query(expect, :Image, with_observations: 1, date: date)
  end

  ##### list/string parameters #####

  def test_image_with_observations_comments_has
    expect = Image.joins(observations: :comments).
             where(Comment[:summary].matches("%give%")).
             or(Image.joins(observations: :comments).
                where(Comment[:comment].matches("%give%"))).
             order(Image[:created_at].desc, Image[:id].desc).uniq
    assert_not_empty(expect, "'expect` is broken; it should not be empty")
    assert_query(expect, :Image,
                 with_observations: 1, comments_has: "give")
  end

  def test_image_with_observations_with_notes_fields
    obs = observations(:substrate_notes_obs) # obs has notes substrate: field
    # give it some images
    obs.images = [images(:conic_image), images(:convex_image)]
    obs.save
    expect =
      Image.joins(:observations).
      where(Observation[:notes].matches("%:substrate:%")).uniq
    assert_not_empty(expect, "'expect` is broken; it should not be empty")
    assert_query(expect, :Image,
                 with_observations: 1, with_notes_fields: "substrate")
  end

  def test_image_with_observations_herbaria
    name = "The New York Botanical Garden"
    expect = Image.joins(observations: { herbarium_records: :herbarium }).
             where(herbaria: { name: name }).
             order(Image[:created_at].desc, Image[:id].desc).uniq
    assert_not_empty(expect, "'expect` is broken; it should not be empty")
    assert_query(expect, :Image, with_observations: 1, herbaria: name)
  end

  def test_image_with_observations_projects
    project = projects(:bolete_project)
    expect = Image.joins(observations: :projects).
             where(projects: { title: project.title }).
             order(Image[:created_at].desc, Image[:id].desc).uniq
    assert_not_empty(expect, "'expect` is broken; it should not be empty")
    assert_query(expect,
                 :Image, with_observations: 1, projects: [project.title])
  end

  def test_image_with_observations_users
    expect = Image.joins(:observations).where(observations: { user: dick }).
             order(Image[:created_at].desc, Image[:id].desc).uniq
    assert_not_empty(expect, "'expect` is broken; it should not be empty")
    assert_query(expect, :Image, with_observations: 1, users: dick)
  end

  ##### numeric parameters #####

  def test_image_with_observations_bounding_box
    obs = give_geolocated_observation_some_images

    lat = obs.lat
    lng = obs.lng
    expect = Image.joins(:observations).
             where(observations: { lat: lat }).
             where(observations: { lng: lng }).uniq
    assert_query(
      expect,
      :Image,
      with_observations: 1,
      north: lat.to_f, south: lat.to_f, west: lat.to_f, east: lat.to_f
    )
  end

  def give_geolocated_observation_some_images
    obs = observations(:unknown_with_lat_lng) # obs has lat/lon
    # give it some images
    obs.images = [images(:conic_image), images(:convex_image)]
    obs.save
    obs
  end

  ##### boolean parameters #####

  def test_image_with_observations_with_comments
    expect = Image.joins(observations: :comments).
             order(Image[:created_at].desc, Image[:id].desc).uniq
    assert_not_empty(expect, "'expect` is broken; it should not be empty")
    assert_query(expect,
                 :Image, with_observations: 1, with_comments: true)
  end

  def test_image_with_observations_with_public_lat_lng
    give_geolocated_observation_some_images

    expect = Image.joins(:observations).
             where.not(observations: { lat: false }).
             order(Image[:created_at].desc, Image[:id].desc).uniq
    assert_not_empty(expect, "'expect` is broken; it should not be empty")
    assert_query(expect,
                 :Image, with_observations: 1, with_public_lat_lng: true)
  end

  def test_image_with_observations_with_name
    expect = Image.joins(:observations).
             where(observations: { name_id: Name.unknown }).
             order(Image[:created_at].desc, Image[:id].desc).uniq
    assert_not_empty(expect, "'expect` is broken; it should not be empty")
    assert_query(expect, :Image, with_observations: 1, with_name: false)
  end

  def test_image_with_observations_with_notes
    expect = Image.joins(:observations).
             where.not(observations: { notes: Observation.no_notes }).
             order(Image[:created_at].desc, Image[:id].desc).uniq
    assert_not_empty(expect, "'expect` is broken; it should not be empty")
    assert_query(expect, :Image, with_observations: 1, with_notes: true)
  end

  def test_image_with_observations_with_sequences
    expect = Image.joins(observations: :sequences).
             order(Image[:created_at].desc, Image[:id].desc).uniq
    assert_not_empty(expect, "'expect` is broken; it should not be empty")
    assert_query(expect, :Image,
                 with_observations: 1, with_sequences: true)
  end

  def test_image_with_observations_is_collection_location
    expect = Image.joins(:observations).
             where(observations: { is_collection_location: true }).
             order(Image[:created_at].desc, Image[:id].desc).uniq
    assert_not_empty(expect, "'expect` is broken; it should not be empty")
    assert_query(expect,
                 :Image,
                 with_observations: 1, is_collection_location: true)
  end

  def test_image_with_observations_at_location
    expect = Image.joins(observations: :location).
             where(observations: { location: locations(:burbank) }).
             where(observations: { is_collection_location: true }).
             order(Image[:created_at].desc, Image[:id].desc).uniq
    assert_query(expect,
                 :Image, with_observations: 1, location: locations(:burbank).id)
    assert_query([], :Image,
                 with_observations: 1, location: locations(:mitrula_marsh).id)
  end

  def test_image_with_observations_at_where
    assert_query([images(:connected_coprinus_comatus_image).id],
                 :Image, with_observations: 1, user_where: "glendale")
    assert_query([],
                 :Image, with_observations: 1, user_where: "snazzle")
  end

  def test_image_with_observations_by_user
    expect = image_with_observations_by_user(rolf)
    assert_query(expect.to_a, :Image, with_observations: 1, by_user: rolf)

    expect = image_with_observations_by_user(mary)
    assert_query(expect.to_a, :Image, with_observations: 1, by_user: mary)

    assert_query([], :Image,
                 with_observations: 1, by_user: users(:zero_user))
  end

  def image_with_observations_by_user(user)
    Image.joins(:observations).where(observations: { user: user }).
      order(Image[:created_at].desc, Image[:id].desc)
  end

  def test_image_with_observations_for_project
    assert_query([],
                 :Image,
                 with_observations: 1, project: projects(:empty_project))
    assert_query(observations(:two_img_obs).images.
                 order(Image[:created_at].desc, Image[:id].desc).uniq,
                 :Image,
                 with_observations: 1, project: projects(:two_img_obs_project))
  end

  def test_image_with_observations_in_set
    obs_ids = [observations(:detailed_unknown_obs).id,
               observations(:agaricus_campestris_obs).id]
    # There's an order_by find_in_set thing here we can't do in Arel.
    # But luckily there is an equivalent, just sort by the obs id.
    oids = obs_ids.join(",")
    expects = Image.joins(:observations).where(observations: { id: obs_ids }).
              reorder(Arel.sql("FIND_IN_SET(observations.id,'#{oids}')").asc,
                      Image[:id].desc).distinct
    assert_query(expects, :Image, with_observations: 1, obs_ids: obs_ids)
    assert_query([], :Image,
                 with_observations: 1,
                 obs_ids: [observations(:minimal_unknown_obs).id])
  end

  def test_image_with_observations_in_species_list
    assert_query([images(:turned_over_image).id,
                  images(:in_situ_image).id],
                 :Image,
                 with_observations: 1,
                 species_list: species_lists(:unknown_species_list).id)
    assert_query([], :Image,
                 with_observations: 1,
                 species_list: species_lists(:first_species_list).id)
  end

  def test_image_with_observations_of_children
    assert_query([images(:agaricus_campestris_image).id],
                 :Image,
                 with_observations: 1,
                 names: [names(:agaricus).id], include_subtaxa: true)
  end

  def test_image_sorted_by_original_name
    assert_query([images(:turned_over_image).id,
                  images(:connected_coprinus_comatus_image).id,
                  images(:disconnected_coprinus_comatus_image).id,
                  images(:in_situ_image).id,
                  images(:commercial_inquiry_image).id,
                  images(:agaricus_campestris_image).id],
                 :Image,
                 ids: [images(:in_situ_image).id,
                       images(:turned_over_image).id,
                       images(:commercial_inquiry_image).id,
                       images(:disconnected_coprinus_comatus_image).id,
                       images(:connected_coprinus_comatus_image).id,
                       images(:agaricus_campestris_image).id],
                 by: :original_name)
  end

  def test_image_with_observations_of_name
    expect = Image.joins(:observation_images, :observations).
             where(observations: { name: names(:fungi) }).
             order(Image[:created_at].desc, Image[:id].desc).uniq
    assert_query(expect,
                 :Image, with_observations: 1, names: [names(:fungi).id])
    assert_query([images(:connected_coprinus_comatus_image).id],
                 :Image,
                 with_observations: 1, names: [names(:coprinus_comatus).id])
    assert_query([images(:agaricus_campestris_image).id],
                 :Image,
                 with_observations: 1, names: [names(:agaricus_campestris).id])
    assert_query([], :Image,
                 with_observations: 1, names: [names(:conocybe_filaris).id])
  end

  def test_location_all
    expect = Location.all
    assert_query(expect, :Location)
    expect = Location.reorder(id: :asc)
    assert_query(expect, :Location, by: :id)
  end

  def test_location_by_user
    assert_query(Location.where(user: rolf).reorder(id: :asc).distinct,
                 :Location, by_user: rolf, by: :id)
    assert_query([], :Location, by_user: users(:zero_user))
  end

  def test_location_by_editor
    assert_query([], :Location, by_editor: rolf)
    User.current = mary
    loc = Location.where.not(user: mary).first
    loc.display_name = "new name"
    loc.save
    assert_query([loc], :Location, by_editor: mary)
    assert_query([], :Location, by_editor: dick)
  end

  def test_location_by_rss_log
    expect = Location.joins(:rss_log).
             reorder(RssLog[:updated_at].desc, Location[:id].desc).distinct
    assert_query(expect.to_a, :Location, by: :rss_log)
  end

  def test_location_in_set
    assert_query([locations(:gualala).id,
                  locations(:albion).id,
                  locations(:burbank).id,
                  locations(:elgin_co).id],
                 :Location,
                 ids: [locations(:gualala).id,
                       locations(:albion).id,
                       locations(:burbank).id,
                       locations(:elgin_co).id])
  end

  def test_location_pattern_search
    expects = Location.where(Location[:name].matches("%California%")).
              reorder(id: :asc).distinct
    assert_query(expects, :Location, pattern: "California", by: :id)
    assert_query([locations(:elgin_co).id],
                 :Location, pattern: "Canada")
    assert_query([], :Location, pattern: "Canada -Elgin")
  end

  def test_location_advanced_search_name
    assert_query([locations(:burbank).id],
                 :Location, name: "agaricus")
    assert_query([], :Location, name: "coprinus")
  end

  def test_location_advanced_search_user_where
    assert_query([locations(:burbank).id],
                 :Location, user_where: "burbank")
    assert_query([locations(:howarth_park).id,
                  locations(:salt_point).id],
                 :Location, user_where: "park")
  end

  def test_location_advanced_search_user
    expects = Location.joins(observations: :user).
              where(observations: { user: rolf }).distinct
    assert_query(expects, :Location, user: "rolf")

    expects = Location.joins(observations: :user).
              where(observations: { user: dick }).distinct
    assert_query(expects, :Location, user: "dick")
  end

  def test_location_advanced_search_content
    # content in obs.notes
    assert_query([locations(:burbank).id],
                 :Location, content: '"strange place"')
    # content in Comment
    assert_query(
      [locations(:burbank).id],
      :Location, content: '"a little of everything"'
    )
    # no search loc.notes
    assert_query([],
                 :Location, content: '"play with"')
  end

  def test_location_advanced_search_content_combos
    assert_query([locations(:burbank).id],
                 :Location, name: "agaricus", content: '"lawn"')
    assert_query([],
                 :Location, name: "agaricus", content: '"play with"')
    # from observation and comment for same observation
    assert_query([locations(:burbank).id],
                 :Location,
                 content: '"a little of everything" "strange place"')
    # from different comments, should fail
    assert_query([],
                 :Location,
                 content: '"minimal unknown" "complicated"')
  end

  def test_location_regexp_search
    expects = Location.where(Location[:name].matches_regexp("California")).
              distinct
    assert_query(expects, :Location, regexp: ".alifornia")
  end

  def test_location_with_descriptions
    expects = Location.joins(:descriptions).distinct
    assert_query(expects, :Location, with_descriptions: 1)
  end

  def test_location_with_descriptions_by_user
    expects = Location.joins(:descriptions).
              where(descriptions: { user: rolf }).distinct
    assert_query(expects, :Location, with_descriptions: 1, by_user: rolf)

    assert_query([], :Location, with_descriptions: 1, by_user: mary)
  end

  def test_location_with_descriptions_by_author
    expects = Location.joins(descriptions: :location_description_authors).
              where(location_description_authors: { user: rolf }).distinct
    assert_query(expects, :Location, with_descriptions: 1, by_author: rolf)
    assert_query([], :Location, with_descriptions: 1, by_author: mary)
  end

  def test_location_with_descriptions_by_editor
    User.current = mary
    desc = location_descriptions(:albion_desc)
    desc.notes = "blah blah blah"
    desc.save
    assert_query([], :Location, with_descriptions: 1, by_editor: rolf)

    expects = Location.joins(descriptions: :location_description_editors).
              where(location_description_editors: { user: mary }).distinct
    assert_query(expects, :Location, with_descriptions: 1, by_editor: mary)
  end

  def test_location_with_descriptions_in_set
    assert_query(
      [locations(:albion), locations(:no_mushrooms_location)],
      :Location,
      with_descriptions: 1,
      desc_ids: [location_descriptions(:albion_desc).id,
                 location_descriptions(:no_mushrooms_location_desc).id]
    )
    assert_query([locations(:albion)], :Location,
                 with_descriptions: 1,
                 desc_ids: [location_descriptions(:albion_desc).id, rolf.id])
    assert_query([],
                 :Location, with_descriptions: 1, desc_ids: [rolf.id])
  end

  def test_location_with_observations
    expects = Location.joins(:observations).distinct
    assert_query(expects, :Location, with_observations: 1)
  end

  # Prove that :with_observations param of Location Query works with each
  # parameter P for which (a) there's no other test of P for
  # Location, OR (b) P behaves differently in :with_observations than in
  # all other params of Location Query's.

  ##### date/time parameters #####

  def test_location_with_observations_created_at
    created_at = observations(:california_obs).created_at
    expect = Location.joins(:observations).
             where(Observation[:created_at] >= created_at).distinct
    assert_query(
      expect, :Location, with_observations: 1, created_at: created_at
    )
  end

  def test_location_with_observations_updated_at
    updated_at = observations(:california_obs).updated_at
    expect = Location.joins(:observations).
             where(Observation[:updated_at] >= updated_at).distinct
    assert_query(
      expect, :Location, with_observations: 1, updated_at: updated_at
    )
  end

  def test_location_with_observations_date
    date = observations(:california_obs).when
    expect = Location.joins(:observations).
             where(Observation[:when] >= date).distinct
    assert_query(
      expect, :Location, with_observations: 1, date: date
    )
  end

  ##### list/string parameters #####

  def test_location_with_observations_include_subtaxa
    parent = names(:agaricus)
    children = Name.where(Name[:text_name].matches_regexp(parent.text_name))
    assert_query(
      Location.joins(:observations).
               where(observations: { name: [parent] + children }).distinct,
      :Location,
      with_observations: 1, names: parent.text_name, include_subtaxa: true
    )
  end

  def test_location_with_observations_comments_has
    # Create a Comment, unfortunately hitting the db because
    # (a) the query should find multiple Locations;
    # (b) all Observation fixtures with Comments have the same Location; and
    # (c) adding a Comment fixture breaks the tests.
    Comment.create(
      user: katrina,
      summary: "Another cool obs",
      comment: "with different location than minimal_unknown_obs",
      target_type: Observation,
      target: observations(:vouchered_obs)
    )
    assert_query(
      Location.joins(observations: :comments).
               where(Comment[:summary].matches("%cool%")).
               or(
                 Location.joins(observations: :comments).
                          where(Comment[:comment].matches("%cool%"))
               ).distinct,
      :Location, with_observations: 1, comments_has: "cool"
    )
  end

  def test_location_with_observations_with_notes_fields
    assert_query(
      Location.joins(:observations).
               where(Observation[:notes].matches("%:substrate:%")).distinct,
      :Location, with_observations: 1, with_notes_fields: "substrate"
    )
  end

  def test_location_with_observations_herbaria
    name = "The New York Botanical Garden"
    expect = Location.joins(observations: { herbarium_records: :herbarium }).
             where(herbaria: { name: name }).distinct
    assert_query(expect, :Location, with_observations: 1, herbaria: name)
  end

  def test_location_with_observations_names
    names = [names(:boletus_edulis), names(:agaricus_campestris)].
            map(&:text_name)
    expects = Location.joins(observations: :name).
              where(observations: { text_name: names }).distinct
    assert_query(expects, :Location, with_observations: 1, names: names)
  end

  def test_location_with_observations_notes_has
    expects = Location.joins(:observations).
              where(Observation[:notes].matches("%somewhere%")).distinct
    assert_query(
      expects, :Location, with_observations: 1, notes_has: "somewhere"
    )
  end

  def test_location_with_observations_locations
    loc_with_observations = locations(:burbank)
    loc_without_observations = locations(:no_mushrooms_location)
    locations = [loc_with_observations, loc_without_observations]
    assert_query(
      [loc_with_observations],
      :Location, with_observations: 1, locations: locations.map(&:name)
    )
  end

  def test_location_with_observations_projects
    project = projects(:bolete_project)
    assert_query(
      Location.joins(observations: :projects).
               where(projects: { title: project.title }).distinct,
      :Location, with_observations: 1, projects: project.title
    )
  end

  def test_location_with_observations_include_synonyms
    # Create Observations of synonyms, unfortunately hitting the db, because:
    # (a) there are no Observation fixtures for a Name with a synonym_names; and
    # (b) tests are brittle, so adding an Observation fixture will break them.
    Observation.create(
      location: locations(:albion),
      name: names(:macrolepiota_rachodes),
      user: rolf
    )
    Observation.create(
      location: locations(:howarth_park),
      name: names(:macrolepiota_rhacodes),
      user: rolf
    )
    assert_query(
      [locations(:albion), locations(:howarth_park)],
      :Location,
      with_observations: 1, names: "Macrolepiota rachodes",
      include_synonyms: true
    )
  end

  def test_location_with_observations_users
    assert_query(
      Location.joins(:observations).
      where(observations: { user: dick }).distinct,
      :Location, with_observations: 1, users: dick
    )
  end

  ##### numeric parameters #####

  def test_location_with_observations_confidence
    # Create Observations with both vote_cache and location, because:
    # (a) there aren't Observation fixtures like that, and
    # (b) tests are brittle, so adding or modifying a fixture will break them.
    obses = Observation.where(vote_cache: 1..3)
    obses.each { |obs| obs.update!(location: locations(:albion)) }
    expect =
      Location.joins(:observations).
      where(observations: { vote_cache: 1..3 }).distinct
    assert_not_empty(expect, "'expect` is broken; it should not be empty")
    assert_query(expect, :Location,
                 with_observations: 1, confidence: [1.0, 3.0])
  end

  ##### boolean parameters #####
  def test_location_with_observations_with_comments
    assert_query(
      Location.joins(observations: :comments).distinct,
      :Location, with_observations: 1, with_comments: true
    )
  end

  def test_location_with_observations_with_public_lat_lng
    assert_query(
      Location.joins(:observations).where(observations: { gps_hidden: false }).
               where.not(observations: { lat: false }).distinct,
      :Location, with_observations: 1, with_public_lat_lng: true
    )
  end

  def test_location_with_observations_with_name
    expects = Location.joins(:observations).
              where(observations: { name: Name.unknown }).distinct
    assert_query(expects, :Location, with_observations: 1, with_name: false)
  end

  def test_location_with_observations_with_notes
    expects = Location.joins(:observations).
              where.not(observations: { notes: Observation.no_notes }).distinct
    assert_query(expects, :Location, with_observations: 1, with_notes: true)
  end

  def test_location_with_observations_with_sequences
    expects = Location.joins(observations: :sequences).distinct
    assert_query(expects, :Location, with_observations: 1, with_sequences: true)
  end

  def test_location_with_observations_is_collection_location
    expects = Location.joins(:observations).
              where(observations: { is_collection_location: true }).distinct
    assert_query(
      expects, :Location, with_observations: 1, is_collection_location: true
    )
  end

  def test_location_with_observations_by_user
    expects = location_with_observations_by_user(rolf)
    assert_query(expects, :Location, with_observations: 1, by_user: rolf.id)

    zero_user = users(:zero_user)
    expects = location_with_observations_by_user(zero_user)
    assert_equal(0, expects.length)
    assert_query(expects, :Location, with_observations: 1, by_user: zero_user)
  end

  def location_with_observations_by_user(user)
    Location.joins(:observations).where(observations: { user: user }).distinct
  end

  def test_location_with_observations_for_project
    assert_query([],
                 :Location,
                 with_observations: 1, project: projects(:empty_project))
    assert_query([observations(:collected_at_obs).location],
                 :Location,
                 with_observations: 1,
                 project: projects(:obs_collected_and_displayed_project))
  end

  def test_location_with_observations_in_set
    assert_query([locations(:burbank).id],
                 :Location,
                 with_observations: 1,
                 obs_ids: [observations(:minimal_unknown_obs).id])
    assert_query([], :Location,
                 with_observations: 1,
                 obs_ids: [observations(:coprinus_comatus_obs).id])
  end

  def test_location_with_observations_in_species_list
    assert_query([locations(:burbank).id],
                 :Location,
                 with_observations: 1,
                 species_list: species_lists(:unknown_species_list).id)
    assert_query([], :Location,
                 with_observations: 1,
                 species_list: species_lists(:first_species_list).id)
  end

  def test_location_with_observations_of_children
    assert_query([locations(:burbank).id],
                 :Location,
                 with_observations: 1,
                 names: [names(:agaricus).id], include_subtaxa: true)
  end

  def test_location_with_observations_of_name
    assert_query([locations(:burbank).id], :Location,
                 with_observations: 1,
                 names: [names(:agaricus_campestris).id])
    assert_query([], :Location,
                 with_observations: 1,
                 names: [names(:peltigera).id])
  end

  def test_location_description_all
    gualala = locations(:gualala)
    all_descs = LocationDescription.all.to_a
    all_gualala_descs = LocationDescription.where(location: gualala).to_a
    public_gualala_descs = LocationDescription.where(location: gualala,
                                                     public: true).to_a
    assert(all_gualala_descs.length < all_descs.length)
    assert(public_gualala_descs.length < all_gualala_descs.length)

    assert_query(all_descs, :LocationDescription, by: :id)
    assert_query(all_gualala_descs, :LocationDescription,
                 by: :id, locations: gualala)
    assert_query(public_gualala_descs, :LocationDescription,
                 by: :id, locations: gualala, public: "yes")
  end

  def test_location_description_by_user
    expects = LocationDescription.where(user: rolf).to_a
    assert_query(expects, :LocationDescription, by_user: rolf)

    expects = LocationDescription.where(user: mary).to_a
    assert_equal(0, expects.length)
    assert_query(expects, :LocationDescription, by_user: mary)
  end

  def test_location_description_by_author
    loc1, loc2, loc3 = Location.all
    desc1 =
      loc1.description ||= LocationDescription.create!(location_id: loc1.id)
    desc2 =
      loc2.description ||= LocationDescription.create!(location_id: loc2.id)
    desc3 =
      loc3.description ||= LocationDescription.create!(location_id: loc3.id)
    desc1.add_author(rolf)
    desc2.add_author(mary)
    desc3.add_author(rolf)

    # Using Rails instead of db; don't know how to do it with .joins & .where
    descs = LocationDescription.all
    assert_query(descs.find_all { |d| d.authors.include?(rolf) },
                 :LocationDescription, by_author: rolf, by: :id)
    assert_query(descs.find_all { |d| d.authors.include?(mary) },
                 :LocationDescription, by_author: mary)
    assert_query([], :LocationDescription, by_author: users(:zero_user))
  end

  def test_location_description_by_editor
    loc1, loc2, loc3 = Location.all
    desc1 =
      loc1.description ||= LocationDescription.create!(location_id: loc1.id)
    desc2 =
      loc2.description ||= LocationDescription.create!(location_id: loc2.id)
    desc3 =
      loc3.description ||= LocationDescription.create!(location_id: loc3.id)
    desc1.add_editor(rolf) # Fails since he's already an author!
    desc2.add_editor(mary)
    desc3.add_editor(rolf)

    # Using Rails instead of db; don't know how to do it with .joins & .where
    descs = LocationDescription.all
    assert_query(descs.find_all { |d| d.editors.include?(rolf) },
                 :LocationDescription, by_editor: rolf, by: :id)
    assert_query(descs.find_all { |d| d.editors.include?(mary) },
                 :LocationDescription, by_editor: mary)
    assert_query([], :LocationDescription, by_editor: users(:zero_user))
  end

  def test_location_description_in_set
    assert_query([],
                 :LocationDescription,
                 ids: rolf.id)
    assert_query(LocationDescription.all,
                 :LocationDescription,
                 ids: LocationDescription.select(:id).to_a)
    assert_query([location_descriptions(:albion_desc).id],
                 :LocationDescription,
                 ids: [rolf.id, location_descriptions(:albion_desc).id])
  end

  def test_location_description_coercion
    ds1 = location_descriptions(:albion_desc)
    ds2 = location_descriptions(:no_mushrooms_location_desc)
    description_coercion_assertions(ds1, ds2, :Location)
  end

  def test_name_advanced_search
    assert_query([names(:macrocybe_titans).id], :Name,
                 name: "macrocybe*titans")
    assert_query([names(:coprinus_comatus).id], :Name,
                 user_where: "glendale") # where
    expect = Name.where("observations.location_id" =>
                  locations(:burbank).id).
             includes(:observations).order(:text_name, :author).to_a
    assert_query(expect, :Name, user_where: "burbank") # location
    expect = Name.where("observations.user_id" => rolf.id).
             includes(:observations).order(:text_name, :author).to_a
    assert_query(expect, :Name, user: "rolf")
    assert_query([names(:coprinus_comatus).id], :Name,
                 content: "second fruiting") # notes
    assert_query([names(:fungi).id], :Name,
                 content: '"a little of everything"') # comment
  end

  def test_name_all
    # NOTE: misspellings are modified by `do_test_name_all`
    expect = Name.order(sort_name: :asc, id: :desc).distinct
    expects = expect.to_a
    # SQL does not sort 'Kuhner' and 'Kühner'
    do_test_name_all(expect) if sql_collates_accents?

    pair = expects.select { |x| x.text_name == "Lentinellus ursinus" }
    a = expects.index(pair.first)
    b = expects.index(pair.last)
    expects[a], expects[b] = expects[b], expects[a]
    do_test_name_all(expect)
  end

  def do_test_name_all(expect)
    expect_good = expect.with_correct_spelling
    expect_bad  = expect.with_incorrect_spelling
    assert_query(expect_good.to_a, :Name)
    assert_query(expect.to_a, :Name, misspellings: :either)
    assert_query(expect_good.to_a, :Name, misspellings: :no)
    assert_query(expect_bad.to_a, :Name, misspellings: :only)
  end

  def test_name_by_user
    assert_query(Name.where(user: mary).where(correct_spelling: nil),
                 :Name, by_user: mary, by: :id)
    assert_query(Name.where(user: dick).where(correct_spelling: nil),
                 :Name, by_user: dick, by: :id)
    assert_query(Name.where(user: rolf).where(correct_spelling: nil),
                 :Name, by_user: rolf, by: :id)
    assert_query([], :Name, by_user: users(:zero_user))
  end

  def test_name_by_editor
    assert_query([], :Name, by_editor: rolf, by: :id)
    assert_query([], :Name, by_editor: mary, by: :id)
    assert_query([names(:peltigera).id], :Name, by_editor: dick, by: :id)
  end

  def test_name_by_rss_log
    expects = Name.joins(:rss_log).
              order(RssLog[:updated_at].desc, Name[:id].desc).uniq
    assert_query(expects, :Name, by: :rss_log)
  end

  def test_name_in_set
    assert_query([names(:fungi).id,
                  names(:coprinus_comatus).id,
                  names(:conocybe_filaris).id,
                  names(:lepiota_rhacodes).id,
                  names(:lactarius_subalpinus).id],
                 :Name,
                 ids: [names(:fungi).id,
                       names(:coprinus_comatus).id,
                       names(:conocybe_filaris).id,
                       names(:lepiota_rhacodes).id,
                       names(:lactarius_subalpinus).id])
  end

  def test_name
    expect = Name.where(Name[:text_name].matches("agaricus %")).
             order(sort_name: :asc, id: :desc).to_a
    expect.reject!(&:is_misspelling?)
    assert_query(expect, :Name,
                 names: [names(:agaricus).id], include_subtaxa: true,
                 exclude_original_names: true)
  end

  def test_name_need_description
    expects = Name.description_needed.order(sort_name: :asc, id: :desc).uniq
    assert_query(expects, :Name, need_description: 1)
  end

  def test_name_pattern_search
    assert_query(
      [],
      :Name, pattern: "petigera" # search_name
    )
    assert_query(
      [names(:petigera).id],
      :Name, pattern: "petigera", misspellings: :either
    )
    assert_query(
      [names(:peltigera).id],
      :Name, pattern: "ye auld manual of lichenes" # citation
    )
    assert_query(
      [names(:agaricus_campestras).id],
      :Name, pattern: "prevent me" # description notes
    )
    assert_query(
      [names(:suillus)],
      :Name, pattern: "smell as sweet" # gen_desc
    )
    # Prove pattern search gets hits for description look_alikes
    assert_query(
      [names(:peltigera).id],
      :Name, pattern: "superficially similar"
    )
  end

  def test_name_with_descriptions
    expect = NameDescription.distinct(:name_id).order(:name_id).pluck(:name_id)
    assert_query(expect, :Name, with_descriptions: 1, by: :id)
  end

  def test_name_with_descriptions_by_user
    expects = Name.with_correct_spelling.joins(:descriptions).
              where(name_descriptions: { user: mary }).order(Name[:id]).uniq
    assert_query(expects, :Name, with_descriptions: 1, by_user: mary, by: :id)

    expects = Name.with_correct_spelling.joins(:descriptions).
              where(name_descriptions: { user: dick }).order(Name[:id]).uniq
    assert_query(expects, :Name, with_descriptions: 1, by_user: dick, by: :id)
  end

  def test_name_with_descriptions_by_author
    expects = name_with_descriptions_by_author(rolf)
    assert_query(expects, :Name, with_descriptions: 1, by_author: rolf, by: :id)

    expects = name_with_descriptions_by_author(mary)
    assert_query(expects, :Name, with_descriptions: 1, by_author: mary, by: :id)

    expects = name_with_descriptions_by_author(dick)
    assert_query(expects, :Name, with_descriptions: 1, by_author: dick, by: :id)
  end

  def name_with_descriptions_by_author(user)
    Name.with_correct_spelling.
      joins(descriptions: :name_description_authors).
      where(name_description_authors: { user: user }).order(Name[:id].asc).uniq
  end

  def test_name_with_descriptions_by_editor
    expects = name_with_descriptions_by_editor(rolf)
    assert_query(expects, :Name, with_descriptions: 1, by_editor: rolf)

    expects = name_with_descriptions_by_editor(rolf)
    assert_query(expects, :Name, with_descriptions: 1, by_editor: mary)

    expects = name_with_descriptions_by_editor(dick)
    assert_equal(0, expects.length)
    assert_query(expects, :Name, with_descriptions: 1, by_editor: dick)
  end

  def name_with_descriptions_by_editor(user)
    Name.with_correct_spelling.
      joins(descriptions: :name_description_editors).
      where(name_description_editors: { user: user }).order(Name[:id].asc).uniq
  end

  def test_name_with_descriptions_in_set
    desc1 = name_descriptions(:peltigera_desc)
    desc2 = name_descriptions(:peltigera_alt_desc)
    desc3 = name_descriptions(:draft_boletus_edulis)
    name1 = names(:peltigera)
    name2 = names(:boletus_edulis)
    assert_query([name1, name2],
                 :Name,
                 with_descriptions: 1, desc_ids: [desc1, desc2, desc3])
  end

  def test_name_with_observations
    expect = Name.with_correct_spelling.joins(:observations).
             select(:name).distinct.pluck(:name_id).sort
    assert_query(expect, :Name, with_observations: 1, by: :id)
  end

  # Prove that :with_observations param of Name Query works with each
  # parameter P for which (a) there's no other test of P for
  # Name, OR (b) P behaves differently in :with_observations than in
  # all other params of Name Query's.

  ##### date/time parameters #####

  def test_name_with_observations_created_at
    created_at = observations(:california_obs).created_at
    expects = Name.with_correct_spelling.joins(:observations).
              where(Observation[:created_at] >= created_at).
              order(Name[:sort_name].asc, Name[:id].desc).uniq
    assert_query(expects, :Name, with_observations: 1, created_at: created_at)
  end

  def test_name_with_observations_updated_at
    updated_at = observations(:california_obs).updated_at
    expects = Name.with_correct_spelling.joins(:observations).
              where(Observation[:updated_at] >= updated_at).
              order(Name[:sort_name].asc, Name[:id].desc).uniq
    assert_query(expects, :Name, with_observations: 1, updated_at: updated_at)
  end

  def test_name_with_observations_date
    date = observations(:california_obs).when
    expects = Name.with_correct_spelling.joins(:observations).
              where(Observation[:when] >= date).
              order(Name[:sort_name].asc, Name[:id].desc).uniq
    assert_query(expects, :Name, with_observations: 1, date: date)
  end

  ##### list/string parameters #####

  def test_name_with_observations_with_notes_fields
    expects = Name.with_correct_spelling.joins(:observations).
              where(Observation[:notes].matches("%:substrate:%")).
              order(Name[:sort_name].asc, Name[:id].desc).uniq
    assert_query(
      expects, :Name, with_observations: 1, with_notes_fields: "substrate"
    )
  end

  def test_name_with_observations_herbaria
    name = "The New York Botanical Garden"
    expects = Name.with_correct_spelling.
              joins(observations: { herbarium_records: :herbarium }).
              where(herbaria: { name: name }).
              order(Name[:sort_name].asc, Name[:id].desc).uniq
    assert_query(expects, :Name, with_observations: 1, herbaria: name)
  end

  def test_name_with_observations_projects
    project = projects(:bolete_project)
    expects = Name.with_correct_spelling.
              joins({ observations: :project_observations }).
              where(project_observations: { project: project }).
              order(Name[:sort_name].asc, Name[:id].desc).uniq
    # project.observations.map(&:name).uniq
    assert_query(expects, :Name, with_observations: 1, projects: project.title)
  end

  def test_name_with_observations_users
    expects = Name.with_correct_spelling.joins(:observations).
              where(observations: { user: dick }).
              order(Name[:sort_name].asc, Name[:id].desc).uniq
    assert_query(expects, :Name, with_observations: 1, users: dick)
  end

  ##### numeric parameters #####

  def test_name_with_observations_confidence
    expects = Name.with_correct_spelling.joins(:observations).
              where(observations: { vote_cache: 1..3 }).
              order(Name[:sort_name].asc, Name[:id].desc).uniq
    assert_not_empty(expects, "'expect` is broken; it should not be empty")
    assert_query(expects, :Name, with_observations: 1, confidence: [1, 3])

    # north/south/east/west
    obs = observations(:unknown_with_lat_lng)
    lat = obs.lat
    lng = obs.lng
    expects = Name.with_correct_spelling.joins(:observations).
              where(observations: { lat: lat, lng: lng }).
              order(Name[:sort_name].asc, Name[:id].desc).uniq
    assert_query(
      expects,
      :Name,
      with_observations: 1,
      north: lat.to_f, south: lat.to_f, west: lat.to_f, east: lat.to_f
    )
  end

  ##### boolean parameters #####

  def test_name_with_observations_with_comments
    expects = Name.with_correct_spelling.joins(observations: :comments).
              order(Name[:sort_name].asc, Name[:id].desc).uniq
    assert_query(expects, :Name, with_observations: 1, with_comments: true)
  end

  def test_name_with_observations_with_public_lat_lng
    expects = Name.joins(:observations).
              where.not(observations: { lat: false }).
              order(Name[:sort_name].asc, Name[:id].desc).uniq
    assert_query(
      expects, :Name, with_observations: 1, with_public_lat_lng: true
    )
  end

  def test_name_with_observations_with_name
    expects = Name.with_correct_spelling.joins(:observations).
              where(observations: { name_id: Name.unknown }).
              order(Name[:sort_name].asc, Name[:id].desc).uniq
    assert_query(expects, :Name, with_observations: 1, with_name: false)
  end

  def test_name_with_observations_with_notes
    expects = Name.with_correct_spelling.joins(:observations).
              where.not(observations: { notes: Observation.no_notes }).
              order(Name[:sort_name].asc, Name[:id].desc).uniq
    assert_query(expects, :Name, with_observations: 1, with_notes: true)
  end

  def test_name_with_observations_with_sequences
    expects = Name.with_correct_spelling.joins(observations: :sequences).
              order(Name[:sort_name].asc, Name[:id].desc).uniq
    assert_query(expects, :Name, with_observations: 1, with_sequences: true)
  end

  def test_name_with_observations_is_collection_location
    expects = Name.with_correct_spelling.joins(:observations).
              where(observations: { is_collection_location: true }).
              order(Name[:sort_name].asc, Name[:id].desc).uniq
    assert_query(
      expects, :Name, with_observations: 1, is_collection_location: true
    )
  end

  def test_name_with_observations_at_location
    loc = locations(:burbank)
    expects = Name.with_correct_spelling.joins(:observations).
              where(observations: { location: loc }).
              order(Name[:sort_name].asc, Name[:id].desc).uniq
    assert_query(expects, :Name, with_observations: 1, location: loc)
  end

  def test_name_with_observations_at_where
    assert_query([names(:coprinus_comatus).id],
                 :Name, with_observations: 1, user_where: "glendale")
  end

  def test_name_with_observations_by_user
    assert_query(name_with_observations_by_user(rolf),
                 :Name, with_observations: 1, by_user: rolf)
    assert_query(name_with_observations_by_user(mary),
                 :Name, with_observations: 1, by_user: mary)
    assert_query([], :Name, with_observations: 1, by_user: users(:zero_user))
  end

  def name_with_observations_by_user(user)
    Name.with_correct_spelling.joins(:observations).
      where(observations: { user: user }).
      order(Name[:sort_name].asc, Name[:id].desc).uniq
  end

  def test_name_with_observations_for_project
    project = projects(:empty_project)
    assert_query([], :Name, with_observations: 1, project: project)

    project2 = projects(:two_img_obs_project)
    expects = Name.with_correct_spelling.
              joins({ observations: :project_observations }).
              where(project_observations: { project: project2 }).
              order(Name[:sort_name].asc, Name[:id].desc).uniq
    assert_query(expects, :Name, with_observations: 1, project: project2)
  end

  def test_name_with_observations_in_set
    expects = Name.with_correct_spelling.joins(:observations).
              where(observations: { id: three_amigos }).
              order(Observation[:id].desc, Name[:id].desc).uniq
    assert_query(expects, :Name, with_observations: 1, obs_ids: three_amigos)
  end

  def test_name_with_observations_in_species_list
    spl = species_lists(:unknown_species_list)
    expects = Name.with_correct_spelling.
              joins({ observations: :species_list_observations }).
              where(species_list_observations: { species_list: spl }).
              order(Name[:sort_name].asc, Name[:id].desc).uniq
    assert_query(expects, :Name, with_observations: 1, species_list: spl)

    spl2 = species_lists(:first_species_list)
    assert_query([], :Name, with_observations: 1, species_list: spl2)
  end

  def test_name_description_all
    pelt = names(:peltigera)
    all_descs = NameDescription.all.to_a
    all_pelt_descs = NameDescription.where(name: pelt).to_a
    public_pelt_descs = NameDescription.where(name: pelt, public: true).to_a
    assert(all_pelt_descs.length < all_descs.length)
    assert(public_pelt_descs.length < all_pelt_descs.length)

    assert_query(all_descs, :NameDescription, by: :id)
    assert_query(all_pelt_descs, :NameDescription, by: :id, names: pelt)
    assert_query(public_pelt_descs, :NameDescription,
                 by: :id, names: pelt, public: "yes")
  end

  def test_name_description_by_user
    expects = NameDescription.where(user: mary).order(:id)
    assert_query(expects, :NameDescription, by_user: mary, by: :id)

    expects = NameDescription.where(user: katrina).order(:id)
    assert_query(expects, :NameDescription, by_user: katrina, by: :id)

    assert_query([], :NameDescription, by_user: junk, by: :id)
  end

  def test_name_description_by_author
    expects = NameDescription.joins(:name_description_authors).
              where(name_description_authors: { user_id: rolf }).order(:id)
    assert_query(expects, :NameDescription, by_author: rolf, by: :id)

    expects = NameDescription.joins(:name_description_authors).
              where(name_description_authors: { user_id: mary }).order(:id)
    assert_query(expects, :NameDescription, by_author: mary, by: :id)

    assert_query([], :NameDescription, by_author: junk)
  end

  def test_name_description_by_editor
    expects = NameDescription.joins(:name_description_editors).
              where(name_description_editors: { user_id: rolf }).order(:id)
    assert_query(expects, :NameDescription, by_editor: rolf)

    expects = NameDescription.joins(:name_description_editors).
              where(name_description_editors: { user_id: mary }).order(:id)
    assert_query(expects, :NameDescription, by_editor: mary)

    assert_query([], :NameDescription, by_editor: dick)
  end

  def test_name_description_in_set
    assert_query([],
                 :NameDescription, ids: rolf.id)
    assert_query(NameDescription.all,
                 :NameDescription, ids: NameDescription.select(:id).to_a)
    assert_query([NameDescription.first.id],
                 :NameDescription, ids: [rolf.id, NameDescription.first.id])
  end

  def test_observation_advanced_search
    assert_query([observations(:strobilurus_diminutivus_obs).id],
                 :Observation, name: "diminutivus")
    assert_query([observations(:coprinus_comatus_obs).id],
                 :Observation, user_where: "glendale") # where
    expect = Observation.where(location_id: locations(:burbank)).to_a
    assert_query(expect, :Observation,
                 user_where: "burbank", by: :id) # location
    expect = Observation.where(user_id: rolf.id).to_a
    assert_query(expect, :Observation, user: "rolf", by: :id)
    assert_query([observations(:coprinus_comatus_obs).id], # notes
                 :Observation, content: "second fruiting")
    assert_query([observations(:minimal_unknown_obs).id],
                 :Observation, content: "agaricus") # comment
  end

  def test_observation_all
    expect = Observation.order(when: :desc, id: :desc).uniq
    assert_query(expect, :Observation)
  end

  def test_observation_in_project_list
    project = projects(:bolete_project)
    # expects = project.species_lists.map(&:observations).flatten.to_a
    expects = Observation.joins(species_lists: :project_species_lists).
              where(project_species_lists: { project: project }).
              order(Observation[:when].desc, Observation[:id].desc).uniq
    assert_query(expects, :Observation, project_lists: project.title)
  end

  def test_observation_at_location
    expects = Observation.where(location: locations(:burbank)).
              order(when: :desc, id: :desc).uniq
    assert_query(expects, :Observation, location: locations(:burbank))
  end

  def test_observation_by_rss_log
    expects = Observation.where.not(rss_log: nil).
              order(log_updated_at: :desc, id: :desc).uniq
    assert_query(expects, :Observation, by: :rss_log)
  end

  def test_observation_by_user
    expect = Observation.where(user_id: rolf.id).to_a
    assert_query(expect, :Observation, by_user: rolf, by: :id)
    expect = Observation.where(user_id: mary.id).to_a
    assert_query(expect, :Observation, by_user: mary, by: :id)
    expect = Observation.where(user_id: dick.id).to_a
    assert_query(expect, :Observation, by_user: dick, by: :id)
    assert_query([], :Observation, by_user: junk, by: :id)
  end

  def test_observation_for_project
    assert_query([],
                 :Observation, project: projects(:empty_project))
    assert_query(projects(:bolete_project).observations,
                 :Observation, project: projects(:bolete_project))
  end

  def test_observation_for_project_projects_equivalence
    qu1 = Query.lookup_and_save(:Observation,
                                project: projects(:bolete_project))
    qu2 = Query.lookup_and_save(:Observation,
                                projects: projects(:bolete_project).id.to_s)
    assert_equal(qu1.results, qu2.results)
  end

  def test_observation_in_set
    obs_set_ids = [observations(:unknown_with_no_naming).id,
                   observations(:minimal_unknown_obs).id,
                   observations(:strobilurus_diminutivus_obs).id,
                   observations(:detailed_unknown_obs).id,
                   observations(:agaricus_campestros_obs).id,
                   observations(:coprinus_comatus_obs).id,
                   observations(:agaricus_campestras_obs).id,
                   observations(:agaricus_campestris_obs).id,
                   observations(:agaricus_campestrus_obs).id]
    assert_query(obs_set_ids, :Observation, ids: obs_set_ids)
  end

  def test_observation_in_species_list
    # These two are identical, so should be disambiguated by reverse_id.
    assert_query([observations(:detailed_unknown_obs).id,
                  observations(:minimal_unknown_obs).id],
                 :Observation,
                 species_list: species_lists(:unknown_species_list).id)
  end

  def test_observation_of_children
    name = names(:agaricus)
    expects = Observation.of_name(name, include_subtaxa: true).
              order(when: :desc, id: :desc).uniq
    assert_query(expects, :Observation, names: [name.id], include_subtaxa: true)
  end

  def test_observation_of_name
    User.current = rolf
    expects = Observation.where(name: names(:fungi)).
              order(when: :desc, id: :desc).uniq
    assert_query(expects, :Observation, names: [names(:fungi).id])
    assert_query([],
                 :Observation, names: [names(:macrolepiota_rachodes).id])

    # test all truthy/falsy combinations of these boolean parameters:
    #  include_synonyms, include_all_name_proposals, exclude_consensus
    names = Name.where(Name[:text_name].matches("Agaricus camp%")).to_a
    agaricus_ssp = names.clone
    name = names.pop
    names.each { |n| name.merge_synonyms(n) }
    observations(:agaricus_campestras_obs).update(user: mary)
    observations(:agaricus_campestros_obs).update(user: mary)

    # observations where name(s) is consensus
    assert_query([observations(:agaricus_campestris_obs).id],
                 :Observation,
                 names: [names(:agaricus_campestris).id],
                 include_synonyms: false,
                 include_all_name_proposals: false,
                 exclude_consensus: false)

    # name(s) is consensus, but is not the consensus (an oxymoron)
    assert_query([],
                 :Observation,
                 names: [names(:agaricus_campestris).id],
                 include_synonyms: false,
                 include_all_name_proposals: false,
                 exclude_consensus: true)

    # name(s) is proposed
    assert_query([observations(:agaricus_campestris_obs).id,
                  observations(:coprinus_comatus_obs).id],
                 :Observation,
                 names: [names(:agaricus_campestris).id],
                 include_synonyms: false,
                 include_all_name_proposals: true,
                 exclude_consensus: false)

    # name(s) is proposed, but is not the consensus
    assert_query([observations(:coprinus_comatus_obs).id],
                 :Observation,
                 names: [names(:agaricus_campestris).id],
                 include_synonyms: false,
                 include_all_name_proposals: true,
                 exclude_consensus: true)

    # consensus is a synonym of name(s)
    assert_query([observations(:agaricus_campestros_obs).id,
                  observations(:agaricus_campestras_obs).id,
                  observations(:agaricus_campestrus_obs).id,
                  observations(:agaricus_campestris_obs).id],
                 :Observation,
                 names: [names(:agaricus_campestris).id],
                 include_synonyms: true,
                 include_all_name_proposals: false,
                 exclude_consensus: false)

    # same as above but exclude_original_names
    # conensus is a synonym of name(s) other than name(s)
    assert_query([observations(:agaricus_campestros_obs).id,
                  observations(:agaricus_campestras_obs).id,
                  observations(:agaricus_campestrus_obs).id],
                 :Observation,
                 names: [names(:agaricus_campestris).id],
                 include_synonyms: true,
                 exclude_original_names: true)

    # consensus is a synonym of name(s) but not a synonym of name(s) (oxymoron)
    assert_query([],
                 :Observation,
                 names: [names(:agaricus_campestras).id],
                 include_synonyms: true,
                 include_all_name_proposals: false,
                 exclude_consensus: true)

    # where synonyms of names are proposed
    assert_query([observations(:agaricus_campestros_obs).id,
                  observations(:agaricus_campestras_obs).id,
                  observations(:agaricus_campestrus_obs).id,
                  observations(:agaricus_campestris_obs).id,
                  observations(:coprinus_comatus_obs).id],
                 :Observation,
                 names: [names(:agaricus_campestris).id],
                 include_synonyms: true,
                 include_all_name_proposals: true,
                 exclude_consensus: false)

    # where synonyms of name are proposed, but are not the consensus
    assert_query([observations(:coprinus_comatus_obs).id],
                 :Observation,
                 names: [names(:agaricus_campestras).id],
                 include_synonyms: true,
                 include_all_name_proposals: true,
                 exclude_consensus: true)

    spl = species_lists(:first_species_list)
    spl.observations << observations(:agaricus_campestrus_obs)
    spl.observations << observations(:agaricus_campestros_obs)
    proj = projects(:eol_project)
    proj.observations << observations(:agaricus_campestris_obs)
    proj.observations << observations(:agaricus_campestras_obs)

    assert_query([observations(:agaricus_campestros_obs).id,
                  observations(:agaricus_campestrus_obs).id],
                 :Observation,
                 names: agaricus_ssp.map(&:text_name),
                 species_lists: [spl.title])

    assert_query([observations(:agaricus_campestras_obs).id,
                  observations(:agaricus_campestris_obs).id],
                 :Observation,
                 names: agaricus_ssp.map(&:text_name),
                 projects: [proj.title])
  end

  def test_observation_pattern_search
    # notes
    # assert_query([observations(:agaricus_campestras_obs).id,
    #               observations(:agaricus_campestros_obs).id,
    #               observations(:agaricus_campestrus_obs).id,
    #               observations(:strobilurus_diminutivus_obs).id],
    #              :Observation, pattern: '"somewhere else"')
    # where
    assert_query([observations(:strobilurus_diminutivus_obs).id],
                 :Observation, pattern: "pipi valley")
    # location
    expects = observation_pattern_search("burbank")
    assert_query(expects.uniq, :Observation, pattern: "burbank", by: :name)

    # name
    expects = observation_pattern_search("agaricus")
    assert_query(expects.uniq, :Observation, pattern: "agaricus", by: :name)
  end

  def observation_pattern_search(pattern)
    Observation.joins(:name).
      where(Name[:search_name].concat(Observation[:where]).
            matches("%#{pattern}%")).
      order(Name[:sort_name].asc,
            Observation[:when].desc, Observation[:id].desc)
  end

  def test_project_all
    expects = Project.order(updated_at: :desc, id: :desc).uniq
    assert_query(expects, :Project)
  end

  def test_project_by_rss_log
    expect = Project.joins(:rss_log).
             order(RssLog[:updated_at].desc, Project[:id].desc)
    assert_query(expect.select(Project[:id]).distinct, :Project, by: :rss_log)
  end

  def test_project_in_set
    assert_query([projects(:eol_project).id], :Project,
                 ids: [projects(:eol_project).id])
    assert_query([], :Project, ids: [])
  end

  def test_project_pattern_search
    assert_query([],
                 :Project, pattern: "no project has this")
    # title
    expects = project_pattern_search("bolete")
    assert_query(expects, :Project, pattern: "bolete")
    # summary
    expects = project_pattern_search("two lists")
    assert_query(expects, :Project, pattern: "two lists")

    expects = Project.order(updated_at: :desc, id: :desc).uniq
    assert_query(expects, :Project, pattern: "")
  end

  def project_pattern_search(pattern)
    Project.where(Project[:title].matches("%#{pattern}%").
                  or(Project[:summary].matches("%#{pattern}%"))).
      order(updated_at: :desc, id: :desc).uniq
  end

  def test_rss_log_all
    ids = RssLog.order(updated_at: :desc, id: :desc).uniq
    assert_query(ids, :RssLog)
  end

  def test_rss_log_type
    ids = [rss_logs(:species_list_rss_log).id]
    assert_query(ids, :RssLog, type: :species_list)
  end

  def test_rss_log_in_set
    rsslog_set_ids = [rss_logs(:species_list_rss_log).id,
                      rss_logs(:name_rss_log).id]
    assert_query(rsslog_set_ids, :RssLog, ids: rsslog_set_ids)
  end

  def test_sequence_all
    expect = Sequence.order(created_at: :desc, id: :desc).uniq
    assert_query(expect, :Sequence)
  end

  def test_sequence_locus_has
    assert_query(Sequence.where(Sequence[:locus].matches("ITS%")).
                 order(created_at: :desc, id: :desc).uniq,
                 :Sequence, locus_has: "ITS")
  end

  def test_sequence_archive
    assert_query([sequences(:alternate_archive)],
                 :Sequence, archive: "UNITE")
  end

  def test_sequence_accession_has
    assert_query([sequences(:deposited_sequence)],
                 :Sequence, accession_has: "968605")
  end

  def test_sequence_notes_has
    assert_query([sequences(:deposited_sequence)],
                 :Sequence, notes_has: "deposited_sequence")
  end

  def test_sequence_for_observations
    obs = observations(:locally_sequenced_obs)
    assert_query([sequences(:local_sequence)],
                 :Sequence, observations: [obs.id])
  end

  def test_sequence_filters
    sequences = Sequence.all
    seq1 = sequences[0]
    seq2 = sequences[1]
    seq3 = sequences[3]
    seq4 = sequences[4]
    seq1.update(observation: observations(:minimal_unknown_obs))
    seq2.update(observation: observations(:detailed_unknown_obs))
    seq3.update(observation: observations(:agaricus_campestris_obs))
    seq4.update(observation: observations(:peltigera_obs))
    assert_query([seq1, seq2], :Sequence, obs_date: %w[2006 2006])
    assert_query([seq1, seq2], :Sequence, observers: users(:mary))
    assert_query([seq1, seq2], :Sequence, names: "Fungi")
    assert_query([seq4], :Sequence,
                 names: "Petigera", include_synonyms: true)
    expects = Sequence.joins(:observation).
              where(observations: { location: locations(:burbank) }).
              or(Sequence.joins(:observation).
                 where(Observation[:where].matches("Burbank"))).
              order(created_at: :desc, id: :desc).uniq
    assert_query(expects, :Sequence, locations: "Burbank")
    assert_query([seq2], :Sequence, projects: "Bolete Project")
    assert_query([seq1, seq2], :Sequence,
                 species_lists: "List of mysteries")
    assert_query([seq4], :Sequence, confidence: "2")
    # The test returns these sequences in random order, can't work.
    # assert_query([seq1, seq2, seq3], :Sequence,
    #              north: "90", south: "0", west: "-180", east: "-100")
  end

  def test_uses_join_hash
    query = Query.lookup(:Sequence,
                         north: "90", south: "0", west: "-180", east: "-100")
    assert_not(query.uses_join_sub([], :location))
    assert(query.uses_join_sub([:location], :location))
    assert_not(query.uses_join_sub({}, :location))
    assert(query.uses_join_sub({ test: :location }, :location))
    assert(query.uses_join_sub(:location, :location))
  end

  def test_sequence_in_set
    list_set_ids = [sequences(:fasta_formatted_sequence).id,
                    sequences(:bare_formatted_sequence).id]
    assert_query(list_set_ids, :Sequence, ids: list_set_ids)
  end

  def test_sequence_pattern_search
    assert_query([], :Sequence, pattern: "nonexistent")
    assert_query(Sequence.where(Sequence[:locus].matches("ITS%")).
                 order(created_at: :desc, id: :desc).uniq,
                 :Sequence, pattern: "ITS")
    assert_query([sequences(:alternate_archive)],
                 :Sequence, pattern: "UNITE")
    assert_query([sequences(:deposited_sequence)],
                 :Sequence, pattern: "deposited_sequence")
  end

  def test_species_list_all
    expect = SpeciesList.order(title: :asc, id: :desc).to_a
    assert_query(expect, :SpeciesList)
  end

  def test_species_list_sort_by_user
    expect = SpeciesList.sort_by_user.to_a
    assert_query(expect, :SpeciesList, by: :user)
  end

  def test_species_list_sort_by_title
    expect = SpeciesList.order(:title).to_a
    assert_query(expect, :SpeciesList, by: :title)
  end

  def test_species_list_at_location
    expects = SpeciesList.where(location: locations(:burbank)).
              order(title: :asc, id: :desc).uniq
    assert_query(expects, :SpeciesList, location: locations(:burbank))
    assert_query(
      [], :SpeciesList, location: locations(:unused_location)
    )
  end

  def test_species_list_at_where
    assert_query([], :SpeciesList, user_where: "nowhere")
    assert_query([species_lists(:where_no_mushrooms_list)],
                 :SpeciesList, user_where: "no mushrooms")
  end

  def test_species_list_by_rss_log
    assert_query([species_lists(:first_species_list).id],
                 :SpeciesList, by: :rss_log)
  end

  def test_species_list_by_user
    expects = SpeciesList.where(user: mary).
              order(title: :asc, id: :desc).uniq
    assert_query(expects, :SpeciesList, by_user: mary)
    assert_query([], :SpeciesList, by_user: dick)
  end

  def test_species_list_by_user_sort_by_id
    expects = SpeciesList.where(user: rolf).
              order(id: :asc).uniq
    assert_query(expects, :SpeciesList, by_user: rolf, by: :id)
  end

  def test_species_list_for_project
    assert_query([],
                 :SpeciesList, project: projects(:empty_project))
    assert_query(projects(:bolete_project).species_lists,
                 :SpeciesList, project: projects(:bolete_project))
    assert_query(
      projects(:two_list_project).species_lists,
      :SpeciesList, project: projects(:two_list_project)
    )
  end

  def test_species_list_in_set
    list_set_ids = [species_lists(:first_species_list).id,
                    species_lists(:unknown_species_list).id]
    assert_query(list_set_ids, :SpeciesList, ids: list_set_ids)
  end

  def test_species_list_pattern_search
    assert_query([],
                 :SpeciesList, pattern: "nonexistent pattern")
    # in title
    pattern = "query_first_list"
    expects = species_list_pattern_search(pattern)
    assert_query(expects, :SpeciesList, pattern: "query_first_list")
    # in notes
    pattern = species_lists(:query_notes_list).notes
    expects = species_list_pattern_search(pattern)
    assert_query(expects, :SpeciesList, pattern: pattern)
    # in location
    pattern = locations(:burbank).name
    expects = species_list_pattern_search(pattern)
    assert_query(expects, :SpeciesList, pattern: locations(:burbank).name)
    # in where
    pattern = species_lists(:where_list).where
    expects = species_list_pattern_search(pattern)
    assert_query(expects, :SpeciesList, pattern: pattern)

    expects = SpeciesList.order(title: :asc, id: :desc).to_a
    assert_query(expects, :SpeciesList, pattern: "")
  end

  def species_list_pattern_search(pattern)
    SpeciesList.left_outer_joins(:location).
      where(SpeciesList[:title].matches("%#{pattern}%").
            or(SpeciesList[:notes].matches("%#{pattern}%")).
            or(SpeciesList[:where].matches("%#{pattern}%")).
            or(Location[:name].matches("%#{pattern}%"))).
      order(title: :asc, id: :desc).uniq
  end

  def test_user_all
    expect = User.order(:name).to_a
    assert_query(expect, :User)
    expect = User.order(:login).to_a
    assert_query(expect, :User, by: :login)
  end

  def test_user_in_set
    assert_query([rolf.id, mary.id, junk.id], :User,
                 ids: [junk.id, mary.id, rolf.id], by: :reverse_name)
  end

  def test_user_pattern_search_nonexistent
    assert_query([],
                 :User, pattern: "nonexistent pattern")
  end

  def test_user_pattern_search_login
    # in login
    expects = user_pattern_search(users(:spammer).login)
    assert_query(expects, :User, pattern: users(:spammer).login)
  end

  def test_user_pattern_search_name
    # in name
    expects = user_pattern_search(users(:mary).name)
    assert_query(expects, :User, pattern: users(:mary).name)
  end

  def test_user_pattern_search_blank
    assert_query(User.order(name: :asc, id: :desc).to_a,
                 :User, pattern: "")
  end

  def test_user_pattern_search_sorted_by_location
    # sorted by location should include Users without location
    # (Differs from searches on other Classes or by other sort orders)
    expects = User.left_outer_joins(:location).
              order(Location[:name].asc, User[:id].desc).uniq
    assert_query(expects, :User, pattern: "", by: "location")
  end

  def user_pattern_search(pattern)
    User.where(User[:login].matches("%#{pattern}%").
               or(User[:name].matches("%#{pattern}%"))).
      order(name: :asc, id: :desc).uniq
  end
  ##############################################################################
  #
  #  :section: Filters
  #
  ##############################################################################

  def test_filtering_content_with_images
    expects = Observation.where.not(thumb_image_id: nil).
              order(when: :desc, id: :desc).uniq
    assert_query(expects, :Observation, with_images: "yes")

    expects = Observation.where(thumb_image_id: nil).
              order(when: :desc, id: :desc).uniq
    assert_query(expects, :Observation, with_images: "no")
  end

  def test_filtering_content_with_specimen
    expects = Observation.where(specimen: true).
              order(when: :desc, id: :desc).uniq
    assert_query(expects, :Observation, with_specimen: "yes")

    expects = Observation.where(specimen: false).
              order(when: :desc, id: :desc).uniq
    assert_query(expects, :Observation, with_specimen: "no")
  end

  def test_filtering_content_with_lichen
    expects_obs = Observation.where(Observation[:lifeform].matches("%lichen%")).
                  order(when: :desc, id: :desc).uniq
    expects_names = Name.with_correct_spelling.
                    where(Name[:lifeform].matches("%lichen%")).
                    order(sort_name: :asc, id: :desc).uniq
    assert_query(expects_obs, :Observation, lichen: "yes")
    assert_query(expects_names, :Name, lichen: "yes")
  end

  def test_filtering_content_with_non_lichen
    expects_obs = Observation.
                  where(Observation[:lifeform].does_not_match("% lichen %")).
                  order(when: :desc, id: :desc).uniq
    expects_names = Name.with_correct_spelling.
                    where(Name[:lifeform].does_not_match("% lichen %")).
                    order(sort_name: :asc, id: :desc).uniq
    assert_query(expects_obs, :Observation, lichen: "no")
    assert_query(expects_names, :Name, lichen: "no")
  end

  def test_filtering_content_region
    expects = Location.where(Location[:name].matches("%California%")).
              order(name: :asc, id: :desc).uniq
    assert_query(expects, :Location, region: "California, USA")
    assert_query(expects, :Location, region: "USA, California")

    expects = Observation.
              where(Observation[:where].matches("%California, USA")).
              order(when: :desc, id: :desc).uniq
    assert_query(expects, :Observation, region: "California, USA")

    expects = Location.where(Location[:name].matches("%, USA").
              or(Location[:name].matches("%, Canada"))).
              order(name: :asc, id: :desc).uniq
    assert(expects.include?(locations(:albion))) # usa
    assert(expects.include?(locations(:elgin_co))) # canada
    assert_query(expects, :Location, region: "North America")
  end

  def test_filtering_content_clade
    names = Name.with_correct_spelling.where(text_name: "Agaricales").or(
      Name.where(
        Name[:classification].matches_regexp("Order: _Agaricales_")
      )
    ).order(sort_name: :asc, id: :desc).distinct
    obs = Observation.where(text_name: "Agaricales").or(
      Observation.where(
        Observation[:classification].matches_regexp("Order: _Agaricales_")
      )
    ).order(when: :desc, id: :desc).distinct
    assert_query(obs, :Observation, clade: "Agaricales")
    assert_query(names, :Name, clade: "Agaricales")
  end

  ##############################################################################
  #
  #  :section: Other stuff
  #
  ##############################################################################

  def test_whiny_nil_in_map_locations
    query = Query.lookup(:User, ids: [rolf.id, 1000, mary.id])
    query.query
    assert_equal(2, query.results.length)
  end

  def test_location_ordering
    albion = locations(:albion)
    elgin_co = locations(:elgin_co)

    User.current = rolf
    assert_equal("postal", User.current_location_format)
    assert_query([albion, elgin_co], :Location,
                 ids: [albion.id, elgin_co.id], by: :name)

    User.current = roy
    assert_equal("scientific", User.current_location_format)
    assert_query([elgin_co, albion], :Location,
                 ids: [albion.id, elgin_co.id], by: :name)

    obs1 = observations(:minimal_unknown_obs)
    obs2 = observations(:detailed_unknown_obs)
    obs1.update(location: albion)
    obs2.update(location: elgin_co)

    User.current = rolf
    assert_equal("postal", User.current_location_format)
    assert_query([obs1, obs2], :Observation,
                 ids: [obs1.id, obs2.id], by: :location)

    User.current = roy
    assert_equal("scientific", User.current_location_format)
    assert_query([obs2, obs1], :Observation,
                 ids: [obs1.id, obs2.id], by: :location)
  end

  def test_lookup_names_by_name
    User.current = rolf

    name1 = names(:macrolepiota)
    name2 = names(:macrolepiota_rachodes)
    name3 = names(:macrolepiota_rhacodes)
    name4 = create_test_name("Pseudolepiota")
    name5 = create_test_name("Pseudolepiota rachodes")

    name1.update(synonym_id: Synonym.create.id)
    name4.update(synonym_id: name1.synonym_id)
    name5.update(synonym_id: name2.synonym_id)

    assert_lookup_names_by_name([name1], names: ["Macrolepiota"])
    assert_lookup_names_by_name([name2], names: ["Macrolepiota rachodes"])
    assert_lookup_names_by_name([name1, name4],
                                names: ["Macrolepiota"],
                                include_synonyms: true)
    assert_lookup_names_by_name([name2, name3, name5],
                                names: ["Macrolepiota rachodes"],
                                include_synonyms: true)
    assert_lookup_names_by_name([name3, name5],
                                names: ["Macrolepiota rachodes"],
                                include_synonyms: true,
                                exclude_original_names: true)
    assert_lookup_names_by_name([name1, name2, name3],
                                names: ["Macrolepiota"],
                                include_subtaxa: true)
    assert_lookup_names_by_name([name1, name2, name3],
                                names: ["Macrolepiota"],
                                include_immediate_subtaxa: true)
    assert_lookup_names_by_name([name1, name2, name3, name4, name5],
                                names: ["Macrolepiota"],
                                include_synonyms: true,
                                include_subtaxa: true)
    assert_lookup_names_by_name([name2, name3, name4, name5],
                                names: ["Macrolepiota"],
                                include_synonyms: true,
                                include_subtaxa: true,
                                exclude_original_names: true)

    name5.update(synonym_id: nil)
    name5 = Name.where(text_name: "Pseudolepiota rachodes").first
    assert_lookup_names_by_name([name1, name2, name3, name4, name5],
                                names: ["Macrolepiota"],
                                include_synonyms: true,
                                include_subtaxa: true)
  end

  def test_lookup_names_by_name2
    User.current = rolf

    name1 = names(:peltigeraceae)
    name2 = names(:peltigera)
    name3 = names(:petigera)
    name4 = create_test_name("Peltigera canina")
    name5 = create_test_name("Peltigera canina var. spuria")
    name6 = create_test_name("Peltigera subg. Foo")
    name7 = create_test_name("Peltigera subg. Foo sect. Bar")

    name4.update(classification: name2.classification)
    name5.update(classification: name2.classification)
    name6.update(classification: name2.classification)
    name7.update(classification: name2.classification)

    assert_lookup_names_by_name([name2, name3], names: ["Peltigera"])
    assert_lookup_names_by_name([name2, name3], names: ["Petigera"])
    assert_lookup_names_by_name([name1, name2, name3, name4, name5, name6,
                                 name7],
                                names: ["Peltigeraceae"],
                                include_subtaxa: true)
    assert_lookup_names_by_name([name1, name2, name3],
                                names: ["Peltigeraceae"],
                                include_immediate_subtaxa: true)
    assert_lookup_names_by_name([name2, name3, name4, name5, name6, name7],
                                names: ["Peltigera"],
                                include_subtaxa: true)
    assert_lookup_names_by_name([name2, name3, name4, name6],
                                names: ["Peltigera"],
                                include_immediate_subtaxa: true)
    assert_lookup_names_by_name([name6, name7],
                                names: ["Peltigera subg. Foo"],
                                include_immediate_subtaxa: true)
    assert_lookup_names_by_name([name4, name5],
                                names: ["Peltigera canina"],
                                include_immediate_subtaxa: true)
  end

  def test_lookup_names_by_name3
    User.current = rolf

    name1 = names(:lactarius)
    name2 = create_test_name("Lactarius \"fakename\"")
    name2.update(classification: name1.classification)
    name2.save

    children = Name.where(Name[:text_name].matches("Lactarius %"))

    assert_lookup_names_by_name([name1] + children,
                                names: ["Lactarius"],
                                include_subtaxa: true)

    assert_lookup_names_by_name(children,
                                names: ["Lactarius"],
                                include_immediate_subtaxa: true,
                                exclude_original_names: true)
  end

  def test_lookup_names_by_name4
    assert_lookup_names_by_name([], names: ["¡not a name!"])
  end

  def create_test_name(name)
    name = Name.new_name(Name.parse_name(name).params)
    name.save
    name
  end

  def assert_lookup_names_by_name(expect, args)
    query = Query.new(:Name)
    actual = query.lookup_names_by_name(args)
    expect = expect.sort_by(&:text_name)
    actual = actual.map { |id| Name.find(id) }.sort_by(&:text_name)
    assert_name_arrays_equal(expect, actual)
  end
end
