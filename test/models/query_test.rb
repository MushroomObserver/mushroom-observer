require "test_helper"
require "set"

class QueryTest < UnitTestCase
  def assert_query(expect, *args)
    test_ids = expect.first.is_a?(Integer)
    expect = expect.to_a unless expect.respond_to?(:map!)
    query = Query.lookup(*args)
    actual = test_ids ? query.result_ids : query.results
    msg = "Query results are wrong. SQL is:\n" + query.last_query
    if test_ids
      assert_equal(expect.sort, actual.sort, msg)
    else
      assert_obj_list_equal(expect.sort_by(&:id), actual.sort_by(&:id), msg)
    end
    type = args[0].t.sub(/um$/, "(um|a)")
    assert_match(/#{type}|Advanced Search|(Lower|Higher) Taxa/, query.title)
    assert(!query.title.include?("[:"),
           "Title contains undefined localizations: <#{query.title}>")
  end

  def clean(str)
    str.gsub(/\s+/, " ").strip
  end

  ##############################################################################

  def test_basic
    assert_raises(NameError) { Query.lookup(:BogusModel) }
    assert_raises(NameError) { Query.lookup(:Name, :bogus) }

    query = Query.lookup(:Observation)
    assert(query.record.new_record?)
    assert_equal("Observation", query.model.to_s)
    assert_equal(:all, query.flavor)

    query2 = Query.lookup_and_save(:Observation)
    assert(!query2.record.new_record?)
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

    assert_raises(RuntimeError) { Query.lookup(:Name, :all, xxx: true) }
    assert_raises(RuntimeError) { Query.lookup(:Name, :all, by: [1, 2, 3]) }
    assert_raises(RuntimeError) { Query.lookup(:Name, :all, by: true) }
    assert_equal("id", Query.lookup(:Name, :all, by: :id).params[:by])

    assert_equal(
      :either,
      Query.lookup(:Name, :all, misspellings: :either).params[:misspellings]
    )
    assert_equal(
      :either,
      Query.lookup(:Name, :all, misspellings: "either").params[:misspellings]
    )
    assert_raises(RuntimeError) do
      Query.lookup(:Name, :all, misspellings: "bogus")
    end
    assert_raises(RuntimeError) do
      Query.lookup(:Name, :all, misspellings: true)
    end
    assert_raises(RuntimeError) { Query.lookup(:Name, :all, misspellings: 123) }

    assert_raises(RuntimeError) { Query.lookup(:Image, :by_user) }
    assert_raises(RuntimeError) { Query.lookup(:Image, :by_user, user: :bogus) }
    assert_raises(RuntimeError) { Query.lookup(:Image, :by_user, user: "rolf") }
    assert_raises(RuntimeError) { Query.lookup(:Image, :by_user, user: @fungi) }
    assert_equal(rolf.id,
                 Query.lookup(:Image, :by_user, user: rolf).params[:user])
    assert_equal(rolf.id,
                 Query.lookup(:Image, :by_user, user: rolf.id).params[:user])
    assert_equal(rolf.id,
                 Query.lookup(:Image, :by_user, user: rolf.id.to_s).
                 params[:user])

    assert_raises(RuntimeError) { Query.lookup(:User, :in_set) }
    # Oops, :in_set query is generic,
    # doesn't know to require Name instances here.
    # assert_raises(RuntimeError) { Query.lookup(:Name, :in_set, ids: rolf) }
    assert_raises(RuntimeError) { Query.lookup(:Name, :in_set, ids: "one") }
    assert_raises(RuntimeError) { Query.lookup(:Name, :in_set, ids: "1,2,3") }
    assert_equal([], Query.lookup(:User, :in_set, ids: []).params[:ids])
    assert_equal([rolf.id], Query.lookup(:User, :in_set,
                                         ids: rolf.id).params[:ids])
    assert_equal([names(:fungi).id],
                 Query.lookup(:Name, :in_set,
                              ids: names(:fungi).id.to_s).params[:ids])
    assert_equal([rolf.id, mary.id],
                 Query.lookup(:User, :in_set,
                              ids: [rolf.id, mary.id]).params[:ids])
    assert_equal([1, 2],
                 Query.lookup(:User, :in_set, ids: %w[1 2]).params[:ids])
    assert_equal([rolf.id, mary.id],
                 Query.lookup(:User, :in_set,
                              ids: [rolf.id.to_s, mary.id.to_s]).params[:ids])
    assert_equal([rolf.id], Query.lookup(:User, :in_set,
                                         ids: rolf).params[:ids])
    assert_equal([rolf.id, mary.id],
                 Query.lookup(:User, :in_set, ids: [rolf, mary]).params[:ids])
    assert_equal([rolf.id, mary.id, junk.id],
                 Query.lookup(:User, :in_set,
                              ids: [rolf, mary.id, junk.id.to_s]).params[:ids])

    assert_raises(RuntimeError) { Query.lookup(:Name, :pattern_search) }
    assert_raises(RuntimeError) do
      Query.lookup(:Name, :pattern_search, pattern: true)
    end
    assert_raises(RuntimeError) do
      Query.lookup(:Name, :pattern_search, pattern: [1, 2, 3])
    end
    assert_raises(RuntimeError) do
      Query.lookup(:Name, :pattern_search, pattern: rolf)
    end
    assert_equal("123",
                 Query.lookup(:Name, :pattern_search, pattern: 123).
                 params[:pattern])
    assert_equal("rolf",
                 Query.lookup(:Name, :pattern_search, pattern: "rolf").
                 params[:pattern])
    assert_equal("rolf",
                 Query.lookup(:Name, :pattern_search, pattern: :rolf).
                 params[:pattern])

    assert_raises(RuntimeError) { Query.lookup(:Name, :of_children) }
    assert_nil(Query.lookup(:Name, :of_children, name: @fungi).params[:all])
    assert_equal(false,
                 Query.lookup(:Name, :of_children, name: @fungi, all: false).
                 params[:all])
    assert_equal(false,
                 Query.lookup(:Name, :of_children, name: @fungi, all: "false").
                 params[:all])
    assert_equal(false,
                 Query.lookup(:Name, :of_children, name: @fungi, all: 0).
                 params[:all])
    assert_equal(false,
                 Query.lookup(:Name, :of_children, name: @fungi, all: :no).
                 params[:all])
    assert_equal(true,
                 Query.lookup(:Name, :of_children, name: @fungi, all: true).
                 params[:all])
    assert_equal(true,
                 Query.lookup(:Name, :of_children, name: @fungi, all: "true").
                 params[:all])
    assert_equal(true,
                 Query.lookup(:Name, :of_children, name: @fungi, all: 1).
                 params[:all])
    assert_equal(true,
                 Query.lookup(:Name, :of_children, name: @fungi, all: :yes).
                 params[:all])
    assert_raises(RuntimeError) do
      Query.lookup(:Name, :of_children, name: @fungi, all: [123])
    end
    assert_raises(RuntimeError) do
      Query.lookup(:Name, :of_children, name: @fungi, all: "bogus")
    end
    assert_raises(RuntimeError) do
      Query.lookup(:Name, :of_children, name: @fungi, all: rolf)
    end

    assert_equal(["table"],
                 Query.lookup(:Name, :all, join: :table).params[:join])
    assert_equal(%w[table1 table2],
                 Query.lookup(:Name, :all, join: %i[table1 table2]).
                 params[:join])
    assert_equal(["table"],
                 Query.lookup(:Name, :all, tables: :table).params[:tables])
    assert_equal(%w[table1 table2],
                 Query.lookup(:Name, :all, tables: %i[table1 table2]).
                 params[:tables])
    assert_equal(["foo = bar"],
                 Query.lookup(:Name, :all, where: "foo = bar").params[:where])
    assert_equal(["foo = bar", "id in (1,2,3)"],
                 Query.lookup(:Name, :all,
                              where: ["foo = bar", "id in (1,2,3)"]).
                 params[:where])
    assert_equal("names.id",
                 Query.lookup(:Name, :all, group: "names.id").params[:group])
    assert_equal("id DESC",
                 Query.lookup(:Name, :all, order: "id DESC").params[:order])
    assert_raises(RuntimeError) { Query.lookup(:Name, :all, group: %w[1 2]) }
    assert_raises(RuntimeError) { Query.lookup(:Name, :all, order: %w[1 2]) }
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

    Query.lookup_and_save(:Observation, :pattern_search, pattern: "blah")
    assert_equal(2, QueryRecord.count)

    # New because params are different from q1.
    q3 = Query.lookup_and_save(:Observation, :all, by: :id)
    assert_equal(3, QueryRecord.count)

    # Not new because flavor is explicitly defaulted before validate.
    q4 = Query.lookup_and_save(:Observation, :all)
    assert_equal(3, QueryRecord.count)
    assert_equal(q1, q4, QueryRecord.count)

    # Ditto default flavor.
    q5 = Query.lookup_and_save(:Observation, :all, by: :id)
    assert_equal(3, QueryRecord.count)
    assert_equal(q3, q5, QueryRecord.count)

    # New pattern is new query.
    Query.lookup_and_save(:Observation, :pattern_search, pattern: "new blah")
    assert_equal(4, QueryRecord.count)

    # Old pattern but new order.
    Query.lookup_and_save(:Observation,
                          :pattern_search, pattern: "blah", by: :date)
    assert_equal(5, QueryRecord.count)

    # Identical, even though :by is explicitly set in one.
    Query.lookup_and_save(:Observation, :pattern_search, pattern: "blah")
    assert_equal(5, QueryRecord.count)

    # Identical query, but new query because order given explicitly.  Order is
    # not given default until query is initialized, thus default not stored in
    # params, so lookup doesn't know about it.
    Query.lookup_and_save(:Observation, :all, by: :date)
    assert_equal(6, QueryRecord.count)

    # Just a sanity check.
    Query.lookup_and_save(:Name)
    assert_equal(7, QueryRecord.count)
  end

  # rubocop:disable Metrics/LineLength
  # def test_cleanup
  #   # Due to the modified => updated_at change explicitly setting updated_at
  #   # this way doesn't work. However, I don't really understand what this test
  #   # does or if it's important, since the time zone comment is definitely
  #   # inaccurate. - NJW
  #
  #   # It is supposed to verify that QueryRecord.cleanup culls old unused
  #   # queries.  This is called automatically periodicallt when clients create
  #   # or lookup new queries. - JPH
  #
  #   # This avoids any possible difference in time zone between mysql and you.
  #   # (This should be obsolete, but timezone handling is tested elsewhere.)
  #   now = DateTime.parse(QueryRecord.connection.select_value("SELECT NOW()")
  #         .to_s)
  #
  #   s11 = QueryRecord.new(access_count: 0, updated_at: now - 1.minute)
  #   s12 = QueryRecord.new(access_count: 0, updated_at: now - 6.hour + 1.minute)
  #   s13 = QueryRecord.new(access_count: 0, updated_at: now - 6.hour - 1.minute)
  #   s14 = QueryRecord.new(access_count: 0, updated_at: now - 1.day + 1.minute)
  #   s15 = QueryRecord.new(access_count: 0, updated_at: now - 1.day - 1.minute)
  #   s21 = QueryRecord.new(access_count: 1, updated_at: now - 1.minute)
  #   s22 = QueryRecord.new(access_count: 1, updated_at: now - 6.hour + 1.minute)
  #   s23 = QueryRecord.new(access_count: 1, updated_at: now - 6.hour - 1.minute)
  #   s24 = QueryRecord.new(access_count: 1, updated_at: now - 1.day + 1.minute)
  #   s25 = QueryRecord.new(access_count: 1, updated_at: now - 1.day - 1.minute)
  #
  #   assert_save(s11)
  #   assert_save(s12)
  #   assert_save(s13)
  #   assert_save(s14)
  #   assert_save(s15)
  #   assert_save(s21)
  #   assert_save(s22)
  #   assert_save(s23)
  #   assert_save(s24)
  #   assert_save(s25)
  #
  #   s11 = s11.id
  #   s12 = s12.id
  #   s13 = s13.id
  #   s14 = s14.id
  #   s15 = s15.id
  #   s21 = s21.id
  #   s22 = s22.id
  #   s23 = s23.id
  #   s24 = s24.id
  #   s25 = s25.id
  #
  #   assert_state_exists(s11)
  #   assert_state_exists(s12)
  #   assert_state_exists(s13)
  #   assert_state_exists(s14)
  #   assert_state_exists(s15)
  #   assert_state_exists(s21)
  #   assert_state_exists(s22)
  #   assert_state_exists(s23)
  #   assert_state_exists(s24)
  #   assert_state_exists(s25)
  #
  #   QueryRecord.cleanup
  #
  #   assert_state_exists(s11)
  #   assert_state_exists(s12)
  #   assert_state_not_exists(s13)
  #   assert_state_not_exists(s14)
  #   assert_state_not_exists(s15)
  #   assert_state_exists(s21)
  #   assert_state_exists(s22)
  #   assert_state_exists(s23)
  #   assert_state_exists(s24)
  #   assert_state_not_exists(s25)
  # end
  #
  # def assert_state_exists(id)
  #   assert(!id.nil? && QueryRecord.find(id))
  # end
  #
  # def assert_state_not_exists(id)
  #   assert_raises(ActiveRecord::RecordNotFound) { QueryRecord.find(id) }
  # end
  # rubocop:enable Metrics/LineLength

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
      "JOIN `observations` ON observations.name_id = names.id "\
      "JOIN `rss_logs` ON observations.rss_log_id = rss_logs.id",
      clean(query.query(join: { observations: :rss_logs }))
    )
    assert_equal(
      "SELECT DISTINCT names.id FROM `names`, `rss_logs`",
      clean(query.query(tables: :rss_logs))
    )
    assert_equal(
      "SELECT DISTINCT names.id FROM `names`, `images`, `comments`",
      clean(query.query(tables: %i[images comments]))
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
      clean(query.query(
              select: "names.*",
              join:   %i[observations users.reviewer],
              tables: :images,
              where:  ["one = two", "foo LIKE bar"],
              group:  "blah.id",
              order:  "names.id ASC",
              limit:  "10, 10"))
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
    #   names => observations => images_observations => images
    #   names => users (as reviewer)
    sql = query.query(
      join: [
        {
          observations: [
            :locations,
            :comments,
            { images_observations: :images }
          ]
        },
        :'users.reviewer'
      ]
    )
    assert_match(/names.reviewer_id = users.id/, sql)
    assert_match(/observations.name_id = names.id/, sql)
    assert_match(/observations.location_id = locations.id/, sql)
    assert_match(/comments.target_id = observations.id/, sql)
    assert_match(/comments.target_type = (['"])Observation\1/, sql)
    assert_match(/images_observations.observation_id = observations.id/, sql)
    assert_match(/images_observations.image_id = images.id/, sql)
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
    query = Query.lookup(:Name, :all, misspellings: :either, by: :id)

    @fungi = names(:fungi)
    @agaricus = names(:agaricus)
    num = Name.count
    num_agaricus = Name.where('text_name LIKE "Agaricus%"').count

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
                  names(:agaricus_campestros).id.to_s].sort,
                 query.select_values(where: 'text_name LIKE "Agaricus%"').
                       map(&:to_s).sort)

    agaricus = query.select_values(select: "text_name",
                                   where: 'text_name LIKE "Agaricus%"').
               map(&:to_s)
    assert_equal(num_agaricus, agaricus.uniq.length)
    assert_equal(num_agaricus,
                 agaricus.select { |x| x[0, 8] == "Agaricus" }.count)

    assert_equal(Name.all.map { |x| [x.id] }, query.select_rows)
    assert_equal(Name.all.map { |x| { "id" => x.id } }, query.select_all)
    assert_equal({ "id" => Name.first.id }, query.select_one)

    assert_equal([Name.first], query.find_by_sql(limit: 1))
    assert_equal(@agaricus.children.sort_by(&:id),
                 query.find_by_sql(where: 'text_name LIKE "Agaricus %"'))
  end

  def test_tables_used
    query = Query.lookup(:Observation, :all, by: :id)
    assert_equal([:observations], query.tables_used)

    query = Query.lookup(:Observation, :all, by: :name)
    assert_equal(%i[names observations], query.tables_used)

    query = Query.lookup(:Image, :all, by: :name)

    assert_equal(%i[images images_observations names observations],
                 query.tables_used)
    assert_equal(true, query.uses_table?(:images))
    assert_equal(true, query.uses_table?(:images_observations))
    assert_equal(true, query.uses_table?(:names))
    assert_equal(true, query.uses_table?(:observations))
    assert_equal(false, query.uses_table?(:comments))
  end

  def test_results
    query = Query.lookup(:User, :all, by: :id)

    assert_equal(
      Set.new,
      Set.new([rolf.id, mary.id, junk.id, dick.id, katrina.id, roy.id]) -
        query.result_ids
    )
    assert_equal(roy.location_format, :scientific)
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
    @names = Name.all.order(:id)
    @pages = MOPaginator.new(number: number,
                             num_per_page: num_per_page)
    @query = Query.lookup(:Name, :all, misspellings: :either, by: :id)
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
    name_ids = @names.map { |n| n[:id] }
    assert_equal(
      expected_nths,
      @query.paginate_ids(@pages).map { |id| name_ids.index(id) + 1 }
    )
    assert_equal(@names.size, @pages.num_total)
    assert_equal(@names[from_nth..to_nth], @query.paginate(@pages))
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
    assert_equal(@ells[3..5], @query.paginate(@pages))
  end

  def test_eager_instantiator
    query = Query.lookup(:Observation)
    ids = query.result_ids

    first = query.instantiate([ids[0]]).first
    assert(!first.images.loaded?)

    first = query.instantiate([ids[0]], include: :images).first
    assert(!first.images.loaded?)

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
    query = Query.lookup(:Name, :all, misspellings: :either, by: :id)
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
    outer = Query.lookup_and_save(:Observation, :all, by: :id)

    q = Query.lookup(
      :Image, :inside_observation,
      outer: outer,
      observation: observations(:minimal_unknown_obs).id, by: :id
    )
    assert_equal([], q.result_ids)

    # Because autogenerated fixture ids order is unpredictable, track which
    # observations and images go with each inner query.
    inners_details = [
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
      :Image, :inside_observation,
      outer: outer,
      observation: inners_details.first[:obs], by: :id
    )
    assert_equal(inners_details.first[:imgs], inner1.result_ids)

    inner2 = Query.lookup_and_save(
      :Image, :inside_observation,
      outer: outer,
      observation: inners_details.second[:obs], by: :id
    )
    assert_equal(inners_details.second[:imgs], inner2.result_ids)

    inner3 = Query.lookup_and_save(
      :Image, :inside_observation,
      outer: outer,
      observation: inners_details.third[:obs], by: :id
    )
    assert_equal(inners_details.third[:imgs], inner3.result_ids)

    inner4 = Query.lookup_and_save(
      :Image, :inside_observation,
      outer: outer,
      observation: inners_details.fourth[:obs], by: :id
    )
    assert_equal(inners_details.fourth[:imgs], inner4.result_ids)

    # Now that inner queries are defined, add them to inners_details
    inners_details.first[:inner]  = inner1
    inners_details.second[:inner] = inner2
    inners_details.third[:inner]  = inner3
    inners_details.fourth[:inner] = inner4

    # calculate some other details
    inners_query_ids = inners_details.map { |n| n[:inner].record.id }.sort
    inners_obs_ids = inners_details.map { |n| n[:obs] }.sort

    assert(inner1.has_outer?)
    # it's been tweaked but still same id
    assert_equal(outer.record.id, inner1.outer.record.id)
    assert_equal(inners_details.first[:obs],  inner1.get_outer_current_id)
    assert_equal(inners_details.second[:obs], inner2.get_outer_current_id)
    assert_equal(inners_details.third[:obs],  inner3.get_outer_current_id)
    assert_equal(inners_details.fourth[:obs], inner4.get_outer_current_id)

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
    # (Results are images of all obs with images, not just inner1 - inner4.)
    non_uniq_imgs_with_obs_count = Image.joins(:observations).size

    # Get 1st result, which is 1st image of 1st imaged observation
    obs = obs_with_imgs_ids.first
    imgs = Observation.find(obs).images.order("id ASC").map(&:id)
    img = imgs.first
    qr = QueryRecord.where(
      ["description REGEXP ?", "observation=##{obs}"]
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
        assert(
          inners_query_ids.include?(q.id),
          "A Query for Observation #{obs} should be in inner1 - inner4"
        )
        assert_equal(
          inners_details.find { |n| n[:obs] == obs }[:inner].id, q.id,
          "Query #{q.id} is not the inner for Observation #{obs}"
        )
      else
        refute(inners_query_ids.include?(q.id),
               "Observation #{obs} should not be in inner1 - inner4")
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
               "A Query for Observation #{obs} should be in inner1 - inner4")
        assert_equal(
          inners_details.find { |n| n[:obs] == obs }[:inner].id, q.id,
          "Query #{q.id} is not the inner for Observation #{obs}"
        )
      else
        refute(inners_query_ids.include?(q.id),
               "Observation #{obs} should not be in inner1 - inner4")
      end
      # And at the right image?
      assert_equal(img, q.current_id)
    end

    # Are we back at the first result?
    assert_equal(q_first_query, q, "Current query is not the first")
    assert_nil(q.prev, "Failed to step back to first result")
    assert_equal(obs_with_imgs_ids.first, obs,
                 "First result not for the first Observation with an Image")
    assert_equal(Observation.find(obs).images.first.id, img,
                 "First result not for first Image in an Observation")

    # Can we get to first query directly from an intermediate query?
    q = q.next
    assert_equal(q_first_query, q.first)
  end

  def obs_with_imgs_ids
    Observation.distinct.joins(:images).order(:id).map(&:id)
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
      imgs = Observation.find(obs).images.order("id ASC").map(&:id)
      # get first or last image in the list
      # depending on whether were going forward or back through results
      img = inc > 0 ? imgs.first : imgs.last
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

    q1 = Query.lookup_and_save(:Observation, :pattern_search, pattern: "search")
    assert_equal(1, QueryRecord.count)

    # Trvial coercion: any flavor from a model to the same model.
    q2 = q1.coerce(:Observation)
    assert_equal(q1, q2)
    assert_equal(1, QueryRecord.count)

    # No search is coercable to RssLog (yet).
    q3 = q1.coerce(:RssLog)
    assert_nil(q3)
    assert_equal(1, QueryRecord.count)
  end

  # rubocop:disable Naming/VariableName
  # RuboCop gives false positives here
  def test_observation_image_coercion
    # Several observation queries can be turned into image queries.
    q1a = Query.lookup_and_save(:Observation, :all, by: :id)
    q2a = Query.lookup_and_save(:Observation, :by_user, user: mary.id)
    q3a = Query.lookup_and_save(
      :Observation, :in_species_list,
      species_list: species_lists(:first_species_list).id
    )
    q4a = Query.lookup_and_save(:Observation, :of_name,
                                name: names(:conocybe_filaris).id)
    q5a = Query.lookup_and_save(:Observation, :in_set,
                                ids: [
                                  observations(:detailed_unknown_obs).id,
                                  observations(:agaricus_campestris_obs).id,
                                  observations(:agaricus_campestras_obs).id
                                ])
    q6a = Query.lookup_and_save(:Observation, :pattern_search,
                                pattern: '"somewhere else"')
    q7a = Query.lookup_and_save(:Observation, :advanced_search,
                                location: "glendale")
    q8a = Query.lookup_and_save(:Observation, :at_location,
                                location: locations(:burbank))
    q9a = Query.lookup_and_save(:Observation, :at_where,
                                location: "california")
    qAa = Query.lookup_and_save(:Observation, :of_children,
                                name: names(:conocybe_filaris).id)
    assert_equal(10, QueryRecord.count)

    # Try coercing them all.
    assert(q1b = q1a.coerce(:Image))
    assert(q2b = q2a.coerce(:Image))
    assert(q3b = q3a.coerce(:Image))
    assert(q4b = q4a.coerce(:Image))
    assert(q5b = q5a.coerce(:Image))
    assert(q6b = q6a.coerce(:Image))
    assert(q7b = q7a.coerce(:Image))
    assert(q8b = q8a.coerce(:Image))
    assert(q9b = q9a.coerce(:Image))
    assert(qAb = qAa.coerce(:Image))

    # They should all be new records
    assert(q1b.record.new_record?)
    assert_save(q1b)
    assert(q2b.record.new_record?)
    assert_save(q2b)
    assert(q3b.record.new_record?)
    assert_save(q3b)
    assert(q4b.record.new_record?)
    assert_save(q4b)
    assert(q5b.record.new_record?)
    assert_save(q5b)
    assert(q6b.record.new_record?)
    assert_save(q6b)
    assert(q7b.record.new_record?)
    assert_save(q7b)
    assert(q8b.record.new_record?)
    assert_save(q8b)
    assert(q9b.record.new_record?)
    assert_save(q9b)
    assert(qAb.record.new_record?)
    assert_save(qAb)

    # Check their descriptions.
    assert_equal("Image", q1b.model.to_s)
    assert_equal("Image", q2b.model.to_s)
    assert_equal("Image", q3b.model.to_s)
    assert_equal("Image", q4b.model.to_s)
    assert_equal("Image", q5b.model.to_s)
    assert_equal("Image", q6b.model.to_s)
    assert_equal("Image", q7b.model.to_s)
    assert_equal("Image", q8b.model.to_s)
    assert_equal("Image", q9b.model.to_s)
    assert_equal("Image", qAb.model.to_s)

    assert_equal(:with_observations, q1b.flavor)
    assert_equal(:with_observations_by_user, q2b.flavor)
    assert_equal(:with_observations_in_species_list, q3b.flavor)
    assert_equal(:with_observations_of_name, q4b.flavor)
    assert_equal(:with_observations_in_set, q5b.flavor)
    assert_equal(:with_observations_in_set, q6b.flavor)
    assert_equal(:with_observations_in_set, q7b.flavor)
    assert_equal(:with_observations_at_location, q8b.flavor)
    assert_equal(:with_observations_at_where, q9b.flavor)
    assert_equal(:with_observations_of_children, qAb.flavor)

    # Now try to coerce them back to Observation.
    assert(q1c = q1b.coerce(:Observation))
    assert(q2c = q2b.coerce(:Observation))
    assert(q3c = q3b.coerce(:Observation))
    assert(q4c = q4b.coerce(:Observation))
    assert(q5c = q5b.coerce(:Observation))
    assert(q6c = q6b.coerce(:Observation))
    assert(q7c = q7b.coerce(:Observation))
    assert(q8c = q8b.coerce(:Observation))
    assert(q9c = q9b.coerce(:Observation))
    assert(qAc = qAb.coerce(:Observation))

    # Only some should be new.
    assert(!q1c.record.new_record?)
    assert_equal(q1a, q1c)
    assert(!q2c.record.new_record?)
    assert_equal(q2a, q2c)
    assert(!q3c.record.new_record?)
    assert_equal(q3a, q3c)
    assert(!q4c.record.new_record?)
    assert_equal(q4a, q4c)
    assert(!q5c.record.new_record?)
    assert_equal(q5a, q5c)
    assert(q6c.record.new_record?)  # (converted to in_set)
    assert(q7c.record.new_record?)  # (converted to in_set)
    assert(!q8c.record.new_record?)
    assert_equal(q8a, q8c)
    assert(!q9c.record.new_record?)
    assert_equal(q9a, q9c)
    assert(!qAc.record.new_record?)
    assert_equal(qAa, qAc)
  end

  def test_observation_location_coercion
    # Almost any query on observations should be mappable, i.e. coercable into
    # a query on those observations' locations.
    q1a = Query.lookup_and_save(:Observation, :all, by: :id)
    q2a = Query.lookup_and_save(:Observation, :by_user, user: mary.id)
    q3a = Query.lookup_and_save(
      :Observation, :in_species_list,
      species_list: species_lists(:first_species_list).id
    )
    q4a = Query.lookup_and_save(:Observation, :of_name,
                                name: names(:conocybe_filaris).id)
    q5a = Query.lookup_and_save(:Observation, :in_set,
                                ids:
                                  [observations(:detailed_unknown_obs).id,
                                   observations(:agaricus_campestris_obs).id,
                                   observations(:agaricus_campestras_obs).id])
    q6a = Query.lookup_and_save(:Observation, :pattern_search,
                                pattern: '"somewhere else"')
    q7a = Query.lookup_and_save(:Observation, :advanced_search,
                                location: "glendale")
    q8a = Query.lookup_and_save(:Observation, :at_location,
                                location: locations(:burbank))
    q9a = Query.lookup_and_save(:Observation, :at_where,
                                location: "california")
    qAa = Query.lookup_and_save(:Observation, :of_children,
                                name: names(:conocybe_filaris).id)
    assert_equal(10, QueryRecord.count)

    # Try coercing them all.
    assert(q1b = q1a.coerce(:Location))
    assert(q2b = q2a.coerce(:Location))
    assert(q3b = q3a.coerce(:Location))
    assert(q4b = q4a.coerce(:Location))
    assert(q5b = q5a.coerce(:Location))
    assert(q6b = q6a.coerce(:Location))
    assert(q7b = q7a.coerce(:Location))
    assert(q8b = q8a.coerce(:Location))
    assert_nil(q9a.coerce(:Location))
    assert(qAb = qAa.coerce(:Location))

    # They should all be new records
    assert(q1b.record.new_record?)
    assert_save(q1b)
    assert(q2b.record.new_record?)
    assert_save(q2b)
    assert(q3b.record.new_record?)
    assert_save(q3b)
    assert(q4b.record.new_record?)
    assert_save(q4b)
    assert(q5b.record.new_record?)
    assert_save(q5b)
    assert(q6b.record.new_record?)
    assert_save(q6b)
    assert(q7b.record.new_record?)
    assert_save(q7b)
    assert(q8b.record.new_record?)
    assert_save(q8b)
    assert(qAb.record.new_record?)
    assert_save(qAb)

    # Check their descriptions.
    assert_equal("Location", q1b.model.to_s)
    assert_equal("Location", q2b.model.to_s)
    assert_equal("Location", q3b.model.to_s)
    assert_equal("Location", q4b.model.to_s)
    assert_equal("Location", q5b.model.to_s)
    assert_equal("Location", q6b.model.to_s)
    assert_equal("Location", q7b.model.to_s)
    assert_equal("Location", q8b.model.to_s)
    assert_equal("Location", qAb.model.to_s)

    assert_equal(:with_observations, q1b.flavor)
    assert_equal(:with_observations_by_user, q2b.flavor)
    assert_equal(:with_observations_in_species_list, q3b.flavor)
    assert_equal(:with_observations_of_name, q4b.flavor)
    assert_equal(:with_observations_in_set, q5b.flavor)
    assert_equal(:with_observations_in_set, q6b.flavor)
    assert_equal(:with_observations_in_set, q7b.flavor)
    assert_equal(:in_set, q8b.flavor)
    assert_equal(:with_observations_of_children, qAb.flavor)

    assert_equal({ old_by: "id" }, q1b.params)
    assert_equal({ user: mary.id }, q2b.params)
    assert_equal({ species_list: species_lists(:first_species_list).id },
                 q3b.params)
    assert_equal({ name: names(:conocybe_filaris).id }, q4b.params)
    assert_equal({ ids: [locations(:burbank).id] }, q8b.params)
    assert_equal({ name: names(:conocybe_filaris).id }, qAb.params)

    assert_equal([observations(:detailed_unknown_obs).id,
                  observations(:agaricus_campestris_obs).id,
                  observations(:agaricus_campestras_obs).id],
                 q5b.params[:ids])
    assert_equal([observations(:strobilurus_diminutivus_obs).id,
                  observations(:agaricus_campestros_obs).id,
                  observations(:agaricus_campestras_obs).id,
                  observations(:agaricus_campestrus_obs).id],
                 q6b.params[:ids])
    assert_equal([observations(:coprinus_comatus_obs).id], q7b.params[:ids])
    assert_match(/Observations.*Matching.*somewhere.*else/,
                 q6b.params[:old_title])
    assert_match(/Advanced.*Search/,
                 q7b.params[:old_title])
    assert_equal(1, q5b.params.keys.length)
    assert_equal(2, q6b.params.keys.length)
    assert_equal(2, q7b.params.keys.length)

    # Now try to coerce them back to Observation.
    assert(q1c = q1b.coerce(:Observation))
    assert(q2c = q2b.coerce(:Observation))
    assert(q3c = q3b.coerce(:Observation))
    assert(q4c = q4b.coerce(:Observation))
    assert(q5c = q5b.coerce(:Observation))
    assert(q6c = q6b.coerce(:Observation))
    assert(q7c = q7b.coerce(:Observation))
    assert_nil(q8b.coerce(:Observation))
    assert(qAc = qAb.coerce(:Observation))

    # Only some should be new.
    assert(!q1c.record.new_record?)
    assert_equal(q1a, q1c)
    assert(!q2c.record.new_record?)
    assert_equal(q2a, q2c)
    assert(!q3c.record.new_record?)
    assert_equal(q3a, q3c)
    assert(!q4c.record.new_record?)
    assert_equal(q4a, q4c)
    assert(!q5c.record.new_record?)
    assert_equal(q5a, q5c)
    assert(q6c.record.new_record?)  # (converted to in_set)
    assert(q7c.record.new_record?)  # (converted to in_set)
    assert(!qAc.record.new_record?)
    assert_equal(qAa, qAc)
  end

  def test_observation_name_coercion
    # Several observation queries can be turned into name queries.
    q1a = Query.lookup_and_save(:Observation, :all, by: :id)
    q2a = Query.lookup_and_save(:Observation, :by_user, user: mary.id)
    q3a = Query.lookup_and_save(
      :Observation, :in_species_list,
      species_list: species_lists(:first_species_list).id
    )
    q4a = Query.lookup_and_save(:Observation, :of_name,
                                name: names(:conocybe_filaris).id)
    q5a = Query.lookup_and_save(:Observation, :in_set,
                                ids: [
                                  observations(:detailed_unknown_obs).id,
                                  observations(:agaricus_campestris_obs).id,
                                  observations(:agaricus_campestras_obs).id
                                ])
    q6a = Query.lookup_and_save(:Observation, :pattern_search,
                                pattern: '"somewhere else"')
    q7a = Query.lookup_and_save(:Observation, :advanced_search,
                                location: "glendale")
    q8a = Query.lookup_and_save(:Observation, :at_location,
                                location: locations(:burbank))
    q9a = Query.lookup_and_save(:Observation, :at_where,
                                location: "california")
    assert_equal(9, QueryRecord.count)

    # Try coercing them all.
    assert(q1b = q1a.coerce(:Name))
    assert(q2b = q2a.coerce(:Name))
    assert(q3b = q3a.coerce(:Name))
    assert_nil(q4a.coerce(:Name))
    assert(q5b = q5a.coerce(:Name))
    assert(q6b = q6a.coerce(:Name))
    assert(q7b = q7a.coerce(:Name))
    assert(q8b = q8a.coerce(:Name))
    assert(q9b = q9a.coerce(:Name))

    # They should all be new records
    assert(q1b.record.new_record?)
    assert_save(q1b)
    assert(q2b.record.new_record?)
    assert_save(q2b)
    assert(q3b.record.new_record?)
    assert_save(q3b)
    assert(q5b.record.new_record?)
    assert_save(q5b)
    assert(q6b.record.new_record?)
    assert_save(q6b)
    assert(q7b.record.new_record?)
    assert_save(q7b)
    assert(q8b.record.new_record?)
    assert_save(q8b)
    assert(q9b.record.new_record?)
    assert_save(q9b)

    # Check their descriptions.
    assert_equal("Name", q1b.model.to_s)
    assert_equal("Name", q2b.model.to_s)
    assert_equal("Name", q3b.model.to_s)
    assert_equal("Name", q5b.model.to_s)
    assert_equal("Name", q6b.model.to_s)
    assert_equal("Name", q7b.model.to_s)
    assert_equal("Name", q8b.model.to_s)
    assert_equal("Name", q9b.model.to_s)

    assert_equal(:with_observations, q1b.flavor)
    assert_equal(:with_observations_by_user, q2b.flavor)
    assert_equal(:with_observations_in_species_list, q3b.flavor)
    assert_equal(:with_observations_in_set, q5b.flavor)
    assert_equal(:with_observations_in_set, q6b.flavor)
    assert_equal(:with_observations_in_set, q7b.flavor)
    assert_equal(:with_observations_at_location, q8b.flavor)
    assert_equal(:with_observations_at_where, q9b.flavor)

    # Now try to coerce them back to Observation.
    assert(q1c = q1b.coerce(:Observation))
    assert(q2c = q2b.coerce(:Observation))
    assert(q3c = q3b.coerce(:Observation))
    assert(q5c = q5b.coerce(:Observation))
    assert(q6c = q6b.coerce(:Observation))
    assert(q7c = q7b.coerce(:Observation))
    assert(q8c = q8b.coerce(:Observation))
    assert(q9c = q9b.coerce(:Observation))

    # Only some should be new.
    assert(!q1c.record.new_record?)
    assert_equal(q1a, q1c)
    assert(!q2c.record.new_record?)
    assert_equal(q2a, q2c)
    assert(!q3c.record.new_record?)
    assert_equal(q3a, q3c)
    assert(!q5c.record.new_record?)
    assert_equal(q5a, q5c)
    assert(q6c.record.new_record?)  # (converted to in_set)
    assert(q7c.record.new_record?)  # (converted to in_set)
    assert(!q8c.record.new_record?)
    assert_equal(q8a, q8c)
    assert(!q9c.record.new_record?)
    assert_equal(q9a, q9c)
  end

  def test_description_coercion
    # Several description queries can be turned into name queries and back.
    q1a = Query.lookup_and_save(:NameDescription, :all)
    q2a = Query.lookup_and_save(:NameDescription, :by_author, user: rolf.id)
    q3a = Query.lookup_and_save(:NameDescription, :by_editor, user: rolf.id)
    q4a = Query.lookup_and_save(:NameDescription, :by_user, user: rolf.id)
    assert_equal(4, QueryRecord.count)

    # Try coercing them into name queries.
    assert(q1b = q1a.coerce(:Name))
    assert(q2b = q2a.coerce(:Name))
    assert(q3b = q3a.coerce(:Name))
    assert(q4b = q4a.coerce(:Name))

    # They should all be new records
    assert(q1b.record.new_record?)
    assert_save(q1b)
    assert(q2b.record.new_record?)
    assert_save(q2b)
    assert(q3b.record.new_record?)
    assert_save(q3b)
    assert(q4b.record.new_record?)
    assert_save(q4b)

    # Make sure they're right.
    assert_equal("Name", q1b.model.to_s)
    assert_equal("Name", q2b.model.to_s)
    assert_equal("Name", q3b.model.to_s)
    assert_equal("Name", q4b.model.to_s)
    assert_equal(:with_descriptions, q1b.flavor)
    assert_equal(:with_descriptions_by_author, q2b.flavor)
    assert_equal(:with_descriptions_by_editor, q3b.flavor)
    assert_equal(:with_descriptions_by_user, q4b.flavor)
    assert_equal(rolf.id, q2b.params[:user])
    assert_equal(rolf.id, q3b.params[:user])
    assert_equal(rolf.id, q4b.params[:user])

    # Try coercing them back.
    assert(q1c = q1b.coerce(:NameDescription))
    assert(q2c = q2b.coerce(:NameDescription))
    assert(q3c = q3b.coerce(:NameDescription))
    assert(q4c = q4b.coerce(:NameDescription))

    # None should be new records
    assert_equal(q1a, q1c)
    assert_equal(q2a, q2c)
    assert_equal(q3a, q3c)
    assert_equal(q4a, q4c)
  end
  # rubocop:enable Naming/VariableName

  def test_rss_log_coercion
    # The site index's default RssLog query should be coercable into queries on
    # the member classes, so that when a user clicks on an RssLog entry in the
    # main index and goes to a show_object page, they can continue to browse
    # results via prev/next.  (Actually, it handles this better now,
    # recognizing in next/prev_object that the query is on RssLog and can skip
    # between controllers while browsing the results, but still worth testing
    # this old mechanism, just in case.)

    # This is the default query for list_rss_logs.
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

    assert_equal(:by_rss_log, q2.flavor)
    assert_equal(:by_rss_log, q3.flavor)
    assert_equal(:by_rss_log, q4.flavor)
    assert_equal(:by_rss_log, q5.flavor)

    assert_equal({}, q2.params)
    assert_equal({}, q3.params)
    assert_equal({}, q4.params)
    assert_equal({}, q5.params)
  end

  def test_coercable
    assert(Query.lookup(:Observation, :all, by: :id).coercable?(:Image))
    refute(Query.lookup(:Herbarium, :all, by: :id).coercable?(:Project))
  end

  ##############################################################################
  #
  #  :section: Test Query Results
  #
  ##############################################################################

  def test_article_all
    assert_query(Article.all, :Article, :all)
  end

  def test_article_by_rss_log
    assert_query(Article.joins(:rss_log).distinct,
                 :Article, :by_rss_log)
  end

  def test_article_in_set
    assert_query([articles(:premier_article).id], :Article,
                 :in_set, ids: [articles(:premier_article).id])
    assert_query([], :Article, :in_set, ids: [])
  end

  def test_article_pattern_search
    assert_query([],
                 :Article, :pattern_search, pattern: "no article has this")
    # title
    assert_query(Article.where("title LIKE '%premier_article%'
                               OR body LIKE '%premier_article%'"),
                 :Article, :pattern_search, pattern: "premier_article")
    # body
    assert_query(Article.where("title LIKE '%Body of Article%'
                               OR body LIKE '%Body of Article%'"),
                 :Article, :pattern_search, pattern: "Body of Article")
    assert_query(Article.all,
                 :Article, :pattern_search, pattern: "")
  end

  def test_collection_number_all
    expect = CollectionNumber.all.sort_by(&:format_name)
    assert_query(expect, :CollectionNumber, :all)
  end

  def test_collection_number_for_observation
    obs = observations(:detailed_unknown_obs)
    expect = obs.collection_numbers.sort_by(&:format_name)
    assert_query(expect, :CollectionNumber, :for_observation,
                 observation: obs.id)
  end

  def test_collection_number_pattern_search
    expect = CollectionNumber.
             where("name like '%Singer%' or number like '%Singer%'").
             sort_by(&:format_name)
    assert_query(expect, :CollectionNumber, :pattern_search, pattern: "Singer")

    expect = CollectionNumber.
             where("name like '%123a%' or number like '%123a%'").
             sort_by(&:format_name)
    assert_query(expect, :CollectionNumber, :pattern_search, pattern: "123a")
  end

  def test_comment_all
    expect = Comment.all.reverse
    assert_query(expect, :Comment, :all)
  end

  def test_comment_by_user
    expect = Comment.where(user_id: mary.id).reverse
    assert_query(expect, :Comment, :by_user, user: mary)
  end

  def test_comment_for_target
    obs = observations(:minimal_unknown_obs)
    expect = Comment.where(target_id: obs.id)
    assert_query(expect, :Comment, :for_target, target: obs,
                                                type: "Observation")
  end

  def test_comment_for_user
    expect = Comment.all.select { |c| c.target.user == mary }
    assert_query(expect, :Comment, :for_user, user: mary)
    assert_query([], :Comment, :for_user, user: rolf)
  end

  def test_comment_in_set
    assert_query([comments(:detailed_unknown_obs_comment).id,
                  comments(:minimal_unknown_obs_comment_1).id],
                 :Comment, :in_set,
                 ids: [comments(:detailed_unknown_obs_comment).id,
                       comments(:minimal_unknown_obs_comment_1).id])
  end

  def test_comment_pattern_search
    expect = [
      comments(:minimal_unknown_obs_comment_1),
      comments(:detailed_unknown_obs_comment)
    ]
    assert_query(expect, :Comment, :pattern_search, pattern: "unknown")
  end

  def test_external_link_all
    assert_query(ExternalLink.all.sort_by(&:url), :ExternalLink, :all)
    assert_query(ExternalLink.where(user: users(:mary)).sort_by(&:url),
                 :ExternalLink, :all, users: users(:mary))
    assert_query([], :ExternalLink, :all, users: users(:dick))
    obs = observations(:coprinus_comatus_obs)
    assert_query(obs.external_links.sort_by(&:url),
                 :ExternalLink, :all, observations: obs)
    obs = observations(:detailed_unknown_obs)
    assert_query([], :ExternalLink, :all, observations: obs)
    site = external_sites(:mycoportal)
    assert_query(site.external_links.sort_by(&:url),
                 :ExternalLink, :all, external_sites: site)
    site = external_sites(:inaturalist)
    assert_query(site.external_links.sort_by(&:url),
                 :ExternalLink, :all, external_sites: site)
    assert_query(site.external_links.sort_by(&:url),
                 :ExternalLink, :all, url: "iNaturalist")
  end

  def test_herbarium_all
    expect = Herbarium.all.sort_by(&:name)
    assert_query(expect, :Herbarium, :all)
  end

  def test_herbarium_in_set
    expect = [
      herbaria(:dick_herbarium),
      herbaria(:nybg_herbarium)
    ]
    assert_query(expect, :Herbarium, :in_set, ids: expect)
  end

  def test_herbarium_pattern_search
    expect = [herbaria(:nybg_herbarium)]
    assert_query(expect, :Herbarium, :pattern_search, pattern: "awesome")
  end

  def test_image_advanced_search
    assert_query([images(:agaricus_campestris_image).id],
                 :Image, :advanced_search, name: "Agaricus")
    assert_query(Image.joins(observations: :location).
                       where(observations: { location: locations(:burbank) }).
                       where(observations: { is_collection_location: true }),
                 :Image, :advanced_search, location: "burbank")
    assert_query([images(:connected_coprinus_comatus_image).id], :Image,
                 :advanced_search, location: "glendale")
    assert_query(Image.includes(:observations).
                       where(observations: { user: mary }),
                 :Image, :advanced_search, user: "mary")
    assert_query([images(:turned_over_image).id, images(:in_situ_image).id],
                 :Image, :advanced_search, content: "little")
    assert_query([images(:connected_coprinus_comatus_image).id],
                 :Image, :advanced_search, content: "fruiting")
    assert_query([],
                 :Image, :advanced_search,
                 name: "agaricus", location: "glendale")
    assert_query([images(:agaricus_campestris_image).id], :Image,
                 :advanced_search, name: "agaricus", location: "burbank")
    assert_query([images(:turned_over_image).id, images(:in_situ_image).id],
                 :Image, :advanced_search,
                 content: "little", location: "burbank")
  end

  def test_herbarium_record_all
    expect = HerbariumRecord.all.sort_by(&:herbarium_label)
    assert_query(expect, :HerbariumRecord, :all)
  end

  def test_herbarium_record_for_observation
    obs = observations(:coprinus_comatus_obs)
    expect = obs.herbarium_records.sort_by(&:herbarium_label)
    assert_query(expect, :HerbariumRecord, :for_observation,
                 observation: obs.id)
  end

  def test_herbarium_record_in_herbarium
    nybg = herbaria(:nybg_herbarium)
    expect = nybg.herbarium_records.sort_by(&:herbarium_label)
    assert_query(expect, :HerbariumRecord, :in_herbarium, herbarium: nybg.id)
  end

  def test_image_all
    expect = Image.all.reverse
    assert_query(expect, :Image, :all)
  end

  def test_image_by_user
    expect = Image.where(user_id: rolf.id).reverse
    assert_query(expect, :Image, :by_user, user: rolf)
    expect = Image.where(user_id: mary.id).reverse
    assert_query(expect, :Image, :by_user, user: mary)
    expect = Image.where(user_id: dick.id).reverse
    assert_query(expect, :Image, :by_user, user: dick)
  end

  def test_image_in_set
    assert_query([images(:turned_over_image).id,
                  images(:agaricus_campestris_image).id,
                  images(:disconnected_coprinus_comatus_image).id], :Image,
                 :in_set,
                 ids: [images(:turned_over_image).id,
                       images(:agaricus_campestris_image).id,
                       images(:disconnected_coprinus_comatus_image).id])
  end

  def test_image_inside_observation
    obs = observations(:detailed_unknown_obs)
    assert_equal(2, obs.images.length)
    expect = obs.images.sort_by(&:id)
    assert_query(expect, :Image, :inside_observation,
                 observation: obs, outer: 1) # (outer is only used by prev/next)
    obs = observations(:minimal_unknown_obs)
    assert_equal(0, obs.images.length)
    assert_query(obs.images, :Image, :inside_observation,
                 observation: obs, outer: 1) # (outer is only used by prev/next)
  end

  def test_image_for_project
    assert_query(
      projects(:bolete_project).images.sort,
      :Image, :for_project, project: projects(:bolete_project), by: :id
    )
    assert_query([], :Image, :for_project, project: projects(:empty_project))
  end

  def test_image_pattern_search
    assert_query([images(:agaricus_campestris_image).id],
                 :Image, :pattern_search, pattern: "agaricus") # name
    assert_query([images(:agaricus_campestris_image).id,
                  images(:connected_coprinus_comatus_image).id,
                  images(:turned_over_image).id,
                  images(:in_situ_image).id],
                 :Image, :pattern_search, pattern: "bob dob") # copyright holder
    assert_query(
      [images(:in_situ_image).id],
      :Image, :pattern_search, pattern: "looked gorilla OR original" # notes
    )
    assert_query([images(:agaricus_campestris_image).id,
                  images(:connected_coprinus_comatus_image).id],
                 :Image, :pattern_search, pattern: "notes some") # notes
    assert_query(
      [images(:turned_over_image).id, images(:in_situ_image).id],
      :Image, :pattern_search, pattern: "dobbs -notes" # (c), not notes
    )
    assert_query([images(:in_situ_image).id], :Image, :pattern_search,
                 pattern: "DSCN8835") # original filename
  end

  def test_image_with_observations
    assert_query(Image.includes(:observations).
                       where.not(observations: { thumb_image: nil }),
                 :Image, :with_observations)
  end

  def test_image_with_observations_at_location
    assert_query(Image.joins(observations: :location).
                       where(observations: { location: locations(:burbank) }).
                       where(observations: { is_collection_location: true }),
                 :Image, :with_observations_at_location,
                 location: locations(:burbank).id)
    assert_query([], :Image, :with_observations_at_location,
                 location: locations(:mitrula_marsh).id)
  end

  def test_image_with_observations_at_where
    assert_query([images(:connected_coprinus_comatus_image).id],
                 :Image, :with_observations_at_where,
                 user_where: "glendale", location: "glendale")
    assert_query([],
                 :Image, :with_observations_at_where,
                 user_where: "snazzle", location: "snazzle")
  end

  def test_image_with_observations_by_user
    assert_query(Image.joins(:observations).
                       where(observations: { user: rolf }),
                 :Image, :with_observations_by_user, user: rolf)

    assert_query(Image.joins(:observations).
                       where(observations: { user: mary }),
                 :Image, :with_observations_by_user, user: mary)

    assert_query([], :Image, :with_observations_by_user,
                 user: users(:zero_user))
  end

  def test_image_with_observations_for_project
    assert_query([],
                 :Image, :with_observations_for_project,
                 project: projects(:empty_project))
    assert_query(observations(:two_img_obs).images,
                 :Image, :with_observations_for_project,
                 project: projects(:two_img_obs_project))
  end

  def test_image_with_observations_in_set
    assert_query([images(:agaricus_campestris_image).id,
                  images(:turned_over_image).id,
                  images(:in_situ_image).id],
                 :Image,
                 :with_observations_in_set,
                 ids: [observations(:detailed_unknown_obs).id,
                       observations(:agaricus_campestris_obs).id])
    assert_query([], :Image,
                 :with_observations_in_set,
                 ids: [observations(:minimal_unknown_obs).id])
  end

  def test_image_with_observations_in_species_list
    assert_query([images(:turned_over_image).id,
                  images(:in_situ_image).id],
                 :Image, :with_observations_in_species_list,
                 species_list: species_lists(:unknown_species_list).id)
    assert_query([], :Image, :with_observations_in_species_list,
                 species_list: species_lists(:first_species_list).id)
  end

  def test_image_with_observations_of_children
    assert_query([images(:agaricus_campestris_image).id],
                 :Image, :with_observations_of_children,
                 name: names(:agaricus))
  end

  def test_image_sorted_by_original_name
    assert_query([images(:turned_over_image).id,
                  images(:connected_coprinus_comatus_image).id,
                  images(:disconnected_coprinus_comatus_image).id,
                  images(:in_situ_image).id,
                  images(:commercial_inquiry_image).id,
                  images(:agaricus_campestris_image).id],
                 :Image, :in_set,
                 ids: [images(:in_situ_image).id,
                       images(:turned_over_image).id,
                       images(:commercial_inquiry_image).id,
                       images(:disconnected_coprinus_comatus_image).id,
                       images(:connected_coprinus_comatus_image).id,
                       images(:agaricus_campestris_image).id],
                 by: :original_name)
  end

  def test_image_with_observations_of_name
    assert_query(Image.joins(:images_observations, :observations).
                       where(observations: { name: names(:fungi) }),
                 :Image, :with_observations_of_name, name: names(:fungi).id)
    assert_query([images(:connected_coprinus_comatus_image).id],
                 :Image, :with_observations_of_name,
                 name: names(:coprinus_comatus).id)
    assert_query([images(:agaricus_campestris_image).id], :Image,
                 :with_observations_of_name,
                 name: names(:agaricus_campestris).id)
    assert_query([], :Image, :with_observations_of_name,
                 name: names(:conocybe_filaris).id)
  end

  def test_location_advanced_search
    assert_query([locations(:burbank).id],
                 :Location, :advanced_search, name: "agaricus")
    assert_query([], :Location, :advanced_search, name: "coprinus")
    assert_query([locations(:burbank).id],
                 :Location, :advanced_search, location: "burbank")
    assert_query([locations(:howarth_park).id,
                  locations(:salt_point).id],
                 :Location, :advanced_search, location: "park")

    assert_query(Location.joins(observations: :user).
                          where(observations: { user: rolf }).uniq,
                 :Location, :advanced_search, user: "rolf")

    assert_query(Location.joins(:observations).
                          where(observations: { user: dick }).uniq,
                 :Location, :advanced_search, user: "dick")

    # content in obs.notes
    assert_query([locations(:burbank).id],
                 :Location, :advanced_search, content: '"strange place"')
    # content in Comment
    assert_query(
      [locations(:burbank).id],
      :Location, :advanced_search, content: '"a little of everything"'
    )
    # no search loc.notes
    assert_query([],
                 :Location, :advanced_search, content: '"play with"')
    assert_query([locations(:burbank).id],
                 :Location, :advanced_search, name: "agaricus",
                                              content: '"lawn"')
    assert_query([],
                 :Location, :advanced_search, name: "agaricus",
                                              content: '"play with"')
    # from observation and comment for same observation
    assert_query([locations(:burbank).id],
                 :Location, :advanced_search,
                 content: '"a little of everything" "strange place"')
    # from different comments, should fail
    assert_query([],
                 :Location, :advanced_search,
                 content: '"minimal unknown" "complicated"')
  end

  def test_location_all
    expect = Location.all.to_a
    assert_query(expect, :Location, :all, by: :id)
  end

  def test_location_by_user
    assert_query(Location.where(user: rolf),
                 :Location, :by_user, user: rolf, by: :id)
    assert_query([], :Location, :by_user, user: users(:zero_user))
  end

  def test_location_by_editor
    assert_query([], :Location, :by_editor, user: rolf)
    User.current = mary
    loc = Location.where.not(user: mary).first
    loc.display_name = "new name"
    loc.save
    assert_query([loc], :Location, :by_editor, user: mary)
    assert_query([], :Location, :by_editor, user: dick)
  end

  def test_location_by_rss_log
    assert_query(Location.joins(:rss_log).distinct,
                 :Location, :by_rss_log)
  end

  def test_location_in_set
    assert_query([locations(:gualala).id,
                  locations(:albion).id,
                  locations(:burbank).id,
                  locations(:elgin_co).id],
                 :Location, :in_set,
                 ids: [locations(:gualala).id,
                       locations(:albion).id,
                       locations(:burbank).id,
                       locations(:elgin_co).id])
  end

  def test_location_pattern_search
    expect = Location.all.select { |l| l.display_name =~ /california/i }
    assert_query(expect,
                 :Location, :pattern_search, pattern: "California", by: :id)
    assert_query([locations(:elgin_co).id],
                 :Location, :pattern_search, pattern: "Canada")
    assert_query([], :Location, :pattern_search, pattern: "Canada -Elgin")
  end

  def test_location_regexp_search
    assert_query(Location.where("name REGEXP 'California'"),
                 :Location, :regexp_search, regexp: ".alifornia")
  end

  def test_location_with_descriptions
    assert_query(LocationDescription.all.map(&:location_id).uniq,
                 :Location, :with_descriptions)
  end

  def test_location_with_descriptions_by_user
    assert_query([locations(:albion).id],
                 :Location, :with_descriptions_by_user, user: rolf)
    assert_query([], :Location, :with_descriptions_by_user, user: mary)
  end

  def test_location_with_descriptions_by_author
    assert_query([locations(:albion).id],
                 :Location, :with_descriptions_by_author, user: rolf)
    assert_query([], :Location, :with_descriptions_by_author, user: mary)
  end

  def test_location_with_descriptions_by_editor
    User.current = mary
    desc = location_descriptions(:albion_desc)
    desc.notes = "blah blah blah"
    desc.save
    assert_query([], :Location, :with_descriptions_by_editor, user: rolf)
    assert_query([locations(:albion).id],
                 :Location, :with_descriptions_by_editor, user: mary)
  end

  def test_location_with_descriptions_in_set
    assert_query([locations(:albion), locations(:no_mushrooms_location)],
                 :Location, :with_descriptions_in_set,
                 ids: [location_descriptions(:albion_desc).id,
                       location_descriptions(:no_mushrooms_location_desc).id])
    assert_query([locations(:albion)],
                 :Location, :with_descriptions_in_set,
                 ids: [location_descriptions(:albion_desc).id, rolf.id])
    assert_query([],
                 :Location, :with_descriptions_in_set, ids: [rolf.id])
  end

  def test_location_with_observations
    assert_query(Location.joins(:observations).uniq,
                 :Location, :with_observations)
  end

  def test_location_with_observations_by_user
    assert_query(Location.joins(:observations).
                          where(observations: { user: rolf }).to_a.uniq,
                 :Location, :with_observations_by_user, user: rolf.id)
    assert_query([], :Location, :with_observations_by_user,
                 user: users(:zero_user))
  end

  def test_location_with_observations_for_project
    assert_query([],
                 :Location, :with_observations_for_project,
                 project: projects(:empty_project))
    assert_query([observations(:collected_at_obs).location],
                 :Location, :with_observations_for_project,
                 project: projects(:obs_collected_and_displayed_project))
  end

  def test_location_with_observations_in_set
    assert_query([locations(:burbank).id], :Location,
                 :with_observations_in_set,
                 ids: [observations(:minimal_unknown_obs).id])
    assert_query([], :Location,
                 :with_observations_in_set,
                 ids: [observations(:coprinus_comatus_obs).id])
  end

  def test_location_with_observations_in_species_list
    assert_query([locations(:burbank).id], :Location,
                 :with_observations_in_species_list,
                 species_list: species_lists(:unknown_species_list).id)
    assert_query([], :Location, :with_observations_in_species_list,
                 species_list: species_lists(:first_species_list).id)
  end

  def test_location_with_observations_of_children
    assert_query([locations(:burbank).id],
                 :Location,
                 :with_observations_of_children, name: names(:agaricus))
  end

  def test_location_with_observations_of_name
    assert_query([locations(:burbank).id], :Location,
                 :with_observations_of_name,
                 name: names(:agaricus_campestris).id)
    assert_query([], :Location,
                 :with_observations_of_name,
                 name: names(:peltigera).id)
  end

  def test_location_description_all
    all = LocationDescription.all.to_a
    assert_query(all, :LocationDescription, :all, by: :id)
  end

  def test_location_description_by_user
    assert_query([location_descriptions(:albion_desc).id],
                 :LocationDescription, :by_user, user: rolf)
    assert_query([], :LocationDescription, :by_user, user: mary)
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
                 :LocationDescription, :by_author, user: rolf, by: :id)
    assert_query(descs.find_all { |d| d.authors.include?(mary) },
                 :LocationDescription, :by_author, user: mary)
    assert_query([], :LocationDescription, :by_author, user: users(:zero_user))
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
                 :LocationDescription, :by_editor, user: rolf, by: :id)
    assert_query(descs.find_all { |d| d.editors.include?(mary) },
                 :LocationDescription, :by_editor, user: mary)
    assert_query([], :LocationDescription, :by_editor, user: users(:zero_user))
  end

  def test_location_description_in_set
    assert_query([],
                 :LocationDescription, :in_set,
                 ids: rolf.id)
    assert_query(LocationDescription.all,
                 :LocationDescription, :in_set,
                 ids: LocationDescription.select(:id).to_a)
    assert_query([location_descriptions(:albion_desc).id],
                 :LocationDescription, :in_set,
                 ids: [rolf.id, location_descriptions(:albion_desc).id])
  end

  def test_name_advanced_search
    assert_query([names(:macrocybe_titans).id], :Name, :advanced_search,
                 name: "macrocybe*titans")
    assert_query([names(:coprinus_comatus).id], :Name, :advanced_search,
                 location: "glendale") # where
    expect = Name.where("observations.location_id" =>
                  locations(:burbank).id).
             includes(:observations).order(:text_name, :author).to_a
    assert_query(expect, :Name, :advanced_search,
                 location: "burbank") # location
    expect = Name.where("observations.user_id" => rolf.id).
             includes(:observations).order(:text_name, :author).to_a
    assert_query(expect, :Name, :advanced_search,
                 user: "rolf")
    assert_query([names(:coprinus_comatus).id], :Name, :advanced_search,
                 content: "second fruiting") # notes
    assert_query([names(:fungi).id], :Name, :advanced_search,
                 content: '"a little of everything"') # comment
  end

  def test_name_all
    expect = Name.all.order(:sort_name).to_a
    # SQL does not sort 'Kuhner' and 'Kühner'
    do_test_name_all(expect) if sql_collates_accents?

    pair = expect.select { |x| x.text_name == "Lentinellus ursinus" }
    a = expect.index(pair.first)
    b = expect.index(pair.last)
    expect[a], expect[b] = expect[b], expect[a]
    do_test_name_all(expect)
  end

  def do_test_name_all(expect)
    expect_good = expect.reject(&:is_misspelling?)
    expect_bad  = expect.select(&:is_misspelling?)
    assert_query(expect_good, :Name, :all)
    assert_query(expect, :Name, :all, misspellings: :either)
    assert_query(expect_good, :Name, :all, misspellings: :no)
    assert_query(expect_bad, :Name, :all, misspellings: :only)
  end

  def test_name_by_user
    assert_query(Name.where(user: mary).where(correct_spelling: nil),
                 :Name, :by_user, user: mary, by: :id)
    assert_query(Name.where(user: dick).where(correct_spelling: nil),
                 :Name, :by_user, user: dick, by: :id)
    assert_query(Name.where(user: rolf).where(correct_spelling: nil),
                 :Name, :by_user, user: rolf, by: :id)
    assert_query([], :Name, :by_user, user: users(:zero_user))
  end

  def test_name_by_editor
    assert_query([], :Name, :by_editor, user: rolf, by: :id)
    assert_query([], :Name, :by_editor, user: mary, by: :id)
    assert_query([names(:peltigera).id], :Name, :by_editor, user: dick, by: :id)
  end

  def test_name_by_rss_log
    assert_query([names(:fungi).id], :Name, :by_rss_log)
  end

  def test_name_in_set
    assert_query([names(:fungi).id,
                  names(:coprinus_comatus).id,
                  names(:conocybe_filaris).id,
                  names(:lepiota_rhacodes).id,
                  names(:lactarius_subalpinus).id], :Name,
                 :in_set,
                 ids: [names(:fungi).id,
                       names(:coprinus_comatus).id,
                       names(:conocybe_filaris).id,
                       names(:lepiota_rhacodes).id,
                       names(:lactarius_subalpinus).id])
  end

  def test_name_of_children
    expect = Name.where("text_name LIKE 'agaricus %'").order("text_name").to_a
    expect.reject!(&:is_misspelling?)
    assert_query(expect, :Name, :of_children, name: names(:agaricus))
  end

  def test_name_of_parents
    peltigeraceae = names(:peltigeraceae)
    peltigera = names(:peltigera)
    assert_query([peltigeraceae], :Name, :of_parents, name: peltigera)

    fungi = names(:fungi)
    basidiomycota = names(:basidiomycota)
    basidiomycetes = names(:basidiomycetes)
    agaricales = names(:agaricales)
    agaricaceae = names(:agaricaceae)
    agaricus = names(:agaricus)
    agaricus_campestris = names(:agaricus_campestris)
    assert_query([agaricaceae], :Name, :of_parents, name: agaricus)
    assert_query([agaricus], :Name, :of_parents, name: agaricus_campestris)
    assert_query([
      fungi,
      basidiomycota,
      basidiomycetes,
      agaricales,
      agaricaceae,
      agaricus
    ], :Name, :of_parents, name: agaricus_campestris, all: "yes")
  end

  def test_name_pattern_search
    assert_query(
      [],
      :Name, :pattern_search, pattern: "petigera" # search_name
    )
    assert_query(
      [names(:petigera).id],
      :Name, :pattern_search, pattern: "petigera", misspellings: :either
    )
    assert_query(
      [names(:peltigera).id],
      :Name, :pattern_search, pattern: "ye auld manual of lichenes" # citation
    )
    assert_query(
      [names(:agaricus_campestras).id],
      :Name, :pattern_search, pattern: "prevent me" # description notes
    )
    assert_query(
      [names(:suillus)],
      :Name, :pattern_search, pattern: "smell as sweet" # gen_desc
    )
    # Prove pattern search gets hits for description look_alikes
    assert_query(
      [names(:peltigera).id],
      :Name, :pattern_search, pattern: "superficially similar"
    )
  end

  def test_name_with_descriptions
    expect = NameDescription.distinct(:name_id).order(:name_id).pluck(:name_id)
    assert_query(expect, :Name, :with_descriptions, by: :id)
  end

  def test_name_with_descriptions_by_user
    assert_query([names(:agaricus_campestris).id,
                  names(:peltigera).id],
                 :Name,
                 :with_descriptions_by_user, user: mary, by: :id)
    assert_query([names(:boletus_edulis).id,
                  names(:peltigera).id,
                  names(:suillus).id],
                 :Name,
                 :with_descriptions_by_user, user: dick, by: :id)
  end

  def test_name_with_descriptions_by_author
    assert_query([names(:coprinus_comatus).id,
                  names(:peltigera).id],
                 :Name,
                 :with_descriptions_by_author, user: rolf, by: :id)
    assert_query([names(:agaricus_campestris).id,
                  names(:peltigera).id],
                 :Name,
                 :with_descriptions_by_author, user: mary, by: :id)
    assert_query([names(:boletus_edulis).id],
                 :Name,
                 :with_descriptions_by_author, user: dick, by: :id)
  end

  def test_name_with_descriptions_by_editor
    assert_query([names(:coprinus_comatus).id], :Name,
                 :with_descriptions_by_editor, user: rolf)
    assert_query([names(:coprinus_comatus).id], :Name,
                 :with_descriptions_by_editor, user: mary)
    assert_query([], :Name, :with_descriptions_by_editor, user: dick)
  end

  def test_name_with_descriptions_in_set
    desc1 = name_descriptions(:peltigera_desc)
    desc2 = name_descriptions(:peltigera_alt_desc)
    desc3 = name_descriptions(:draft_boletus_edulis)
    name1 = names(:peltigera)
    name2 = names(:boletus_edulis)
    assert_query([name2, name1],
                 :Name, :with_descriptions_in_set, ids: [desc1, desc2, desc3])
  end

  def test_name_with_observations
    expect = Observation.select(:name).distinct.pluck(:name_id).sort
    assert_query(expect, :Name, :with_observations, by: :id)
  end

  def test_name_with_observations_at_location
    assert_query(Name.joins(:observations).
                      where(observations: { location: locations(:burbank) }).
                      distinct,
                 :Name, :with_observations_at_location,
                 location: locations(:burbank))
  end

  def test_name_with_observations_at_where
    assert_query([names(:coprinus_comatus).id], :Name,
                 :with_observations_at_where,
                 user_where: "glendale", location: "glendale")
  end

  def test_name_with_observations_by_user
    assert_query(Name.joins(:observations).
                      where(observations: { user: rolf }).distinct,
                 :Name, :with_observations_by_user, user: rolf)
    assert_query(Name.joins(:observations).
                      where(observations: { user: mary }).distinct,
                 :Name, :with_observations_by_user, user: mary)
    assert_query([], :Name, :with_observations_by_user, user: users(:zero_user))
  end

  def test_name_with_observations_for_project
    assert_query([],
                 :Name, :with_observations_for_project,
                 project: projects(:empty_project))

    assert_query([observations(:two_img_obs).name],
                 :Name, :with_observations_for_project,
                 project: projects(:two_img_obs_project))
  end

  def test_name_with_observations_in_set
    assert_query([names(:agaricus_campestras).id,
                  names(:agaricus_campestris).id,
                  names(:fungi).id],
                 :Name,
                 :with_observations_in_set,
                 ids: [observations(:detailed_unknown_obs).id,
                       observations(:agaricus_campestris_obs).id,
                       observations(:agaricus_campestras_obs).id])
  end

  def test_name_with_observations_in_species_list
    assert_query([names(:fungi).id], :Name,
                 :with_observations_in_species_list,
                 species_list: species_lists(:unknown_species_list).id)
    assert_query([], :Name,
                 :with_observations_in_species_list,
                 species_list: species_lists(:first_species_list).id)
  end

  def test_name_description_all
    all = NameDescription.all.to_a
    assert_query(all, :NameDescription, :all, by: :id)
  end

  def test_name_description_by_user
    assert_query([name_descriptions(:draft_agaricus_campestris).id,
                  name_descriptions(:peltigera_user_desc).id],
                 :NameDescription, :by_user, user: mary, by: :id)
    assert_query([name_descriptions(:draft_coprinus_comatus).id,
                  name_descriptions(:draft_lactarius_alpinus).id,
                  name_descriptions(:peltigera_source_desc).id],
                 :NameDescription, :by_user, user: katrina, by: :id)
    assert_query([], :NameDescription, :by_user, user: junk, by: :id)
  end

  def test_name_description_by_author
    assert_query([name_descriptions(:peltigera_alt_desc).id,
                  name_descriptions(:coprinus_comatus_desc).id],
                 :NameDescription, :by_author, user: rolf, by: :id)
    assert_query([name_descriptions(:draft_agaricus_campestris).id,
                  name_descriptions(:peltigera_user_desc).id],
                 :NameDescription, :by_author, user: mary, by: :id)
    assert_query([], :NameDescription, :by_author, user: junk)
  end

  def test_name_description_by_editor
    assert_query([name_descriptions(:coprinus_comatus_desc).id],
                 :NameDescription, :by_editor, user: rolf)
    assert_query([name_descriptions(:coprinus_comatus_desc).id],
                 :NameDescription, :by_editor, user: mary)
    assert_query([], :NameDescription, :by_editor, user: dick)
  end

  def test_name_description_in_set
    assert_query([],
                 :NameDescription, :in_set,
                 ids: rolf.id)
    assert_query(NameDescription.all,
                 :NameDescription, :in_set,
                 ids: NameDescription.select(:id).to_a)
    assert_query([NameDescription.first.id],
                 :NameDescription, :in_set,
                 ids: [rolf.id, NameDescription.first.id])
  end

  def test_observation_advanced_search
    assert_query([observations(:strobilurus_diminutivus_obs).id], :Observation,
                 :advanced_search, name: "diminutivus")
    assert_query([observations(:coprinus_comatus_obs).id], :Observation,
                 :advanced_search, location: "glendale") # where
    expect = Observation.where(location_id: locations(:burbank)).to_a
    assert_query(expect, :Observation,
                 :advanced_search, location: "burbank", by: :id) # location
    expect = Observation.where(user_id: rolf.id).to_a
    assert_query(expect, :Observation, :advanced_search, user: "rolf", by: :id)
    assert_query([observations(:coprinus_comatus_obs).id], :Observation,
                 :advanced_search, content: "second fruiting") # notes
    assert_query([observations(:minimal_unknown_obs).id], :Observation,
                 :advanced_search, content: "agaricus") # comment
  end

  def test_observation_all
    expect = Observation.all.order("`when` DESC, id DESC").to_a
    assert_query(expect, :Observation, :all)
  end

  def test_observation_at_location
    expect = Observation.where(location_id: locations(:burbank).id).
             includes(:name).
             order("names.text_name, names.author, observations.id DESC").to_a
    assert_query(expect, :Observation, :at_location,
                 location: locations(:burbank))
  end

  def test_observation_at_where
    assert_query([observations(:coprinus_comatus_obs).id],
                 :Observation, :at_where, user_where: "glendale",
                                          location: "glendale")
  end

  def test_observation_by_rss_log
    expect = Observation.where.not(rss_log: nil)
    assert_query(expect, :Observation, :by_rss_log)
  end

  def test_observation_by_user
    expect = Observation.where(user_id: rolf.id).to_a
    assert_query(expect, :Observation, :by_user, user: rolf, by: :id)
    expect = Observation.where(user_id: mary.id).to_a
    assert_query(expect, :Observation, :by_user, user: mary, by: :id)
    expect = Observation.where(user_id: dick.id).to_a
    assert_query(expect, :Observation, :by_user, user: dick, by: :id)
    assert_query([], :Observation, :by_user, user: junk, by: :id)
  end

  def test_observation_for_project
    assert_query([],
                 :Observation, :for_project, project: projects(:empty_project))
    assert_query(projects(:bolete_project).observations,
                 :Observation, :for_project, project: projects(:bolete_project))
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
    assert_query(obs_set_ids, :Observation, :in_set, ids: obs_set_ids)
  end

  def test_observation_in_species_list
    # These two are identical, so should be disambiguated by reverse_id.
    assert_query([observations(:detailed_unknown_obs).id,
                  observations(:minimal_unknown_obs).id], :Observation,
                 :in_species_list,
                 species_list: species_lists(:unknown_species_list).id)
  end

  def test_observation_of_children
    assert_query([observations(:agaricus_campestras_obs).id,
                  observations(:agaricus_campestris_obs).id,
                  observations(:agaricus_campestros_obs).id,
                  observations(:agaricus_campestrus_obs).id],
                 :Observation, :of_children, name: names(:agaricus))
  end

  def test_observation_of_name
    User.current = rolf
    names = Name.where("text_name like 'Agaricus camp%'").to_a
    name = names.pop
    names.each { |n| name.merge_synonyms(n) }
    observations(:agaricus_campestras_obs).update(user: mary)
    observations(:agaricus_campestros_obs).update(user: mary)
    spl = species_lists(:first_species_list)
    spl.observations << observations(:agaricus_campestrus_obs)
    spl.observations << observations(:agaricus_campestros_obs)
    proj = projects(:eol_project)
    proj.observations << observations(:agaricus_campestris_obs)
    proj.observations << observations(:agaricus_campestras_obs)

    assert_query(Observation.where(name: names(:fungi)),
                 :Observation, :of_name, name: names(:fungi).id)
    assert_query([],
                 :Observation, :of_name, name: names(:macrolepiota_rachodes).id)
    assert_query([observations(:agaricus_campestris_obs).id],
                 :Observation,
                 :of_name, name: names(:agaricus_campestris).id)
    assert_query([observations(:agaricus_campestros_obs).id,
                  observations(:agaricus_campestras_obs).id,
                  observations(:agaricus_campestrus_obs).id],
                 :Observation, :of_name, name: names(:agaricus_campestris).id,
                                         synonyms: :exclusive)
    assert_query([observations(:agaricus_campestros_obs).id,
                  observations(:agaricus_campestras_obs).id,
                  observations(:agaricus_campestrus_obs).id,
                  observations(:agaricus_campestris_obs).id],
                 :Observation, :of_name, name: names(:agaricus_campestris).id,
                                         synonyms: :all)
    assert_query([observations(:coprinus_comatus_obs).id],
                 :Observation, :of_name, name: names(:agaricus_campestris).id,
                                         nonconsensus: :exclusive)
    assert_query([observations(:agaricus_campestris_obs).id,
                  observations(:coprinus_comatus_obs).id],
                 :Observation, :of_name, name: names(:agaricus_campestris).id,
                                         nonconsensus: :all)
  end

  def test_observation_pattern_search
    # notes
    assert_query([observations(:agaricus_campestras_obs).id,
                  observations(:agaricus_campestros_obs).id,
                  observations(:agaricus_campestrus_obs).id,
                  observations(:strobilurus_diminutivus_obs).id],
                 :Observation, :pattern_search, pattern: '"somewhere else"')
    # where
    assert_query([observations(:strobilurus_diminutivus_obs).id],
                 :Observation, :pattern_search, pattern: "pipi valley")
    # location
    expect = Observation.where(location_id: locations(:burbank)).
             includes(:name).
             order("names.text_name, names.author,observations.id DESC").to_a
    assert_query(expect,
                 :Observation, :pattern_search, pattern: "burbank", by: :name)

    # name
    expect = Observation.
             where("names.text_name LIKE 'agaricus%'").includes(:name).
             order("names.text_name, names.author, observations.id DESC")
    assert_query(expect.map(&:id),
                 :Observation, :pattern_search, pattern: "agaricus", by: :name)
  end

  def test_project_all
    assert_query(Project.all, :Project, :all)
  end

  def test_project_by_rss_log
    assert_query(Project.joins(:rss_log).distinct,
                 :Project, :by_rss_log)
  end

  def test_project_in_set
    assert_query([projects(:eol_project).id], :Project,
                 :in_set, ids: [projects(:eol_project).id])
    assert_query([], :Project, :in_set, ids: [])
  end

  def test_project_pattern_search
    assert_query([],
                 :Project, :pattern_search, pattern: "no project has this")
    # title
    assert_query(Project.where("summary LIKE '%bolete%'
                               OR title LIKE '%bolete%'"),
                 :Project, :pattern_search, pattern: "bolete")
    # summary
    assert_query(Project.where("summary LIKE '%two lists%'
                               OR title LIKE '%two lists%'"),
                 :Project, :pattern_search, pattern: "two lists")
    assert_query(Project.all,
                 :Project, :pattern_search, pattern: "")
  end

  def test_rss_log_all
    ids = RssLog.all.map(&:id)
    assert_query(ids, :RssLog, :all)
  end

  def test_rss_log_in_set
    rsslog_set_ids = [rss_logs(:species_list_rss_log).id,
                      rss_logs(:name_rss_log).id]
    assert_query(rsslog_set_ids, :RssLog, :in_set, ids: rsslog_set_ids)
  end

  def test_sequence_all
    expect = Sequence.all.order("created_at").to_a
    assert_query(expect, :Sequence, :all)
    assert_query(Sequence.where("locus LIKE 'ITS%'"),
                 :Sequence, :all, locus_has: "ITS")
    assert_query([sequences(:alternate_archive)],
                 :Sequence, :all, archive: "UNITE")
    assert_query([sequences(:deposited_sequence)],
                 :Sequence, :all, accession_has: "968605")
    assert_query([sequences(:deposited_sequence)],
                 :Sequence, :all, notes_has: "deposited_sequence")
    obs = observations(:locally_sequenced_obs)
    assert_query([sequences(:local_sequence)],
                 :Sequence, :all, observations: [obs.id])
  end

  def test_sequence_filters
    sequences = Sequence.all
    seq1 = sequences[0]
    seq2 = sequences[1]
    seq3 = sequences[2]
    seq4 = sequences[3]
    seq1.update_attribute(:observation, observations(:minimal_unknown_obs))
    seq2.update_attribute(:observation, observations(:detailed_unknown_obs))
    seq3.update_attribute(:observation, observations(:agaricus_campestris_obs))
    seq4.update_attribute(:observation, observations(:peltigera_obs))
    assert_query([seq1, seq2], :Sequence, :all, obs_date: ["2006", "2006"])
    assert_query([seq1, seq2], :Sequence, :all, observers: users(:mary))
    assert_query([seq1, seq2], :Sequence, :all, names: "Fungi")
    assert_query([seq4], :Sequence, :all, synonym_names: "Petigera")
    assert_query([seq1, seq2, seq3], :Sequence, :all, locations: "Burbank")
    assert_query([seq2], :Sequence, :all, projects: "Bolete Project")
    assert_query([seq1, seq2], :Sequence, :all,
                 species_lists: "List of mysteries")
    assert_query([seq4], :Sequence, :all, confidence: "2")
    assert_query([seq1, seq2, seq3], :Sequence, :all,
                 north: "90", south: "0", west: "-180", east: "-100")
  end

  def test_sequence_in_set
    list_set_ids = [sequences(:fasta_formatted_sequence).id,
                    sequences(:bare_formatted_sequence).id]
    assert_query(list_set_ids, :Sequence, :in_set, ids: list_set_ids)
  end

  def test_sequence_pattern_search
    assert_query([], :Sequence, :pattern_search, pattern: "nonexistent")
    assert_query(Sequence.where("locus LIKE 'ITS%'"),
                 :Sequence, :pattern_search, pattern: "ITS")
    assert_query([sequences(:alternate_archive)],
                 :Sequence, :pattern_search, pattern: "UNITE")
    assert_query([sequences(:deposited_sequence)],
                 :Sequence, :pattern_search, pattern: "deposited_sequence")
  end

  def test_species_list_all
    expect = SpeciesList.all.order("title").to_a
    assert_query(expect, :SpeciesList, :all)
  end

  def test_species_list_at_location
    assert_query(SpeciesList.where(location: locations(:burbank)),
                 :SpeciesList, :at_location, location: locations(:burbank))
    assert_query(
      [],
      :SpeciesList, :at_location, location: locations(:unused_location)
    )
  end

  def test_species_list_at_where
    assert_query([],
                 :SpeciesList, :at_where, user_where: "nowhere",
                                          location: "nowhere")
    assert_query([species_lists(:where_no_mushrooms_list)],
                 :SpeciesList, :at_where, user_where: "no mushrooms",
                                          location: "no mushrooms")
  end

  def test_species_list_by_rss_log
    assert_query([species_lists(:first_species_list).id],
                 :SpeciesList, :by_rss_log)
  end

  def test_species_list_by_user
    assert_query([species_lists(:first_species_list).id,
                  species_lists(:another_species_list).id],
                 :SpeciesList, :by_user, user: rolf, by: :id)
    assert_query(SpeciesList.where(user: mary),
                 :SpeciesList, :by_user, user: mary)
    assert_query([], :SpeciesList, :by_user, user: dick)
  end

  def test_species_list_for_project
    assert_query([],
                 :SpeciesList, :for_project, project: projects(:empty_project))
    assert_query(projects(:bolete_project).species_lists,
                 :SpeciesList, :for_project, project: projects(:bolete_project))
    assert_query(
      projects(:two_list_project).species_lists,
      :SpeciesList, :for_project, project: projects(:two_list_project)
    )
  end

  def test_species_list_in_set
    list_set_ids = [species_lists(:first_species_list).id,
                    species_lists(:unknown_species_list).id]
    assert_query(list_set_ids, :SpeciesList, :in_set, ids: list_set_ids)
  end

  def test_species_list_pattern_search
    assert_query([],
                 :SpeciesList, :pattern_search, pattern: "nonexistent pattern")
    # in title
    assert_query(SpeciesList.where(title: "query_first_list"),
                 :SpeciesList, :pattern_search, pattern: "query_first_list")
    # in notes
    pattern = species_lists(:query_notes_list).notes
    assert_query(SpeciesList.where(notes: pattern),
                 :SpeciesList, :pattern_search, pattern: pattern)
    # in location
    assert_query(
      SpeciesList.where(location: locations(:burbank)),
      :SpeciesList, :pattern_search, pattern: locations(:burbank).name
    )
    # in where
    pattern = species_lists(:where_list).where
    assert_query(SpeciesList.where(where: pattern),
                 :SpeciesList, :pattern_search, pattern: pattern)

    assert_query(SpeciesList.all,
                 :SpeciesList, :pattern_search, pattern: "")
  end

  def test_herbarium_record_pattern_search
    assert_query([], :HerbariumRecord, :pattern_search,
                 pattern: "no herbarium record has this")
    assert_query(HerbariumRecord.where("initial_det LIKE '%Agaricus%'"),
                 :HerbariumRecord, :pattern_search, pattern: "Agaricus")
    assert_query(HerbariumRecord.where("notes LIKE '%rare%'"),
                 :HerbariumRecord, :pattern_search, pattern: "rare")
    assert_query(HerbariumRecord.all,
                 :HerbariumRecord, :pattern_search, pattern: "")
  end

  def test_user_all
    expect = User.all.order("name").to_a
    assert_query(expect, :User, :all)
    expect = User.all.order("login").to_a
    assert_query(expect, :User, :all, by: :login)
  end

  def test_user_in_set
    assert_query([rolf.id, mary.id, junk.id],
                 :User, :in_set,
                 ids: [junk.id, mary.id, rolf.id],
                 by: :reverse_name)
  end

  def test_user_pattern_search
    assert_query([],
                 :User, :pattern_search, pattern: "nonexistent pattern")
    # in login
    assert_query(User.where(login: users(:spammer).login),
                 :User, :pattern_search, pattern: users(:spammer).login)
    # in name
    assert_query(User.where(name: users(:mary).name),
                 :User, :pattern_search, pattern: users(:mary).name)
    assert_query(User.all,
                 :User, :pattern_search, pattern: "")
    # sorted by location should include Users without location
    # (Differs from searches on other Classes or by other sort orders)
    assert_query(User.all,
                 :User, :pattern_search, pattern: "", by: "location")
  end

  ##############################################################################
  #
  #  :section: Filters
  #
  ##############################################################################

  def test_filtering_content
    ##### has_images filter #####
    expect = Observation.where.not(thumb_image_id: nil)
    assert_query(expect, :Observation, :all, has_images: "yes")

    expect = Observation.where(thumb_image_id: nil)
    assert_query(expect, :Observation, :all, has_images: "no")

    ##### has_specimen filter #####
    expect = Observation.where(specimen: true)
    assert_query(expect, :Observation, :all, has_specimen: "yes")

    expect = Observation.where(specimen: false)
    assert_query(expect, :Observation, :all, has_specimen: "no")

    ##### lichen filters #####
    expect_obs = Observation.where("lifeform LIKE '%lichen%'").to_a
    expect_names = Name.where("lifeform LIKE '%lichen%'").
                   reject(&:correct_spelling_id).to_a
    assert_query(expect_obs, :Observation, :all, lichen: "yes")
    assert_query(expect_names, :Name, :all, lichen: "yes")

    expect_obs = Observation.where("lifeform NOT LIKE '% lichen %'").to_a
    expect_names = Name.where("lifeform NOT LIKE '% lichen %'").
                   reject(&:correct_spelling_id).to_a
    assert_query(expect_obs, :Observation, :all, lichen: "no")
    assert_query(expect_names, :Name, :all, lichen: "no")

    ##### region filter #####
    expect = Location.where("name LIKE '%California%'")
    assert_query(expect, :Location, :all, region: "California, USA")
    assert_query(expect, :Location, :all, region: "USA, California")

    expect = Observation.where("`where` LIKE '%California, USA'")
    assert_query(expect, :Observation, :all, region: "California, USA")

    expect = Location.where("name LIKE '%, USA' OR name LIKE '%, Canada'")
    assert(expect.include?(locations(:albion))) # usa
    assert(expect.include?(locations(:elgin_co))) # canada
    assert_query(expect, :Location, :all, region: "North America")

    ##### clade filter #####
    expect_names = Name.where("classification LIKE '%Agaricales%'").
                   reject(&:correct_spelling_id).to_a
    expect_names << names(:agaricales)
    expect_obs = expect_names.map(&:observations).flatten
    assert_query(expect_obs, :Observation, :all, clade: "Agaricales")
    assert_query(expect_names, :Name, :all, clade: "Agaricales")
  end

  ##############################################################################
  #
  #  :section: Other stuff
  #
  ##############################################################################

  def test_whiny_nil_in_map_locations
    query = Query.lookup(:User, :in_set,
                         ids: [rolf.id, 1000, mary.id])
    query.query
    assert_equal(2, query.results.length)
  end

  def test_location_ordering
    albion = locations(:albion)
    elgin_co = locations(:elgin_co)

    User.current = rolf
    assert_equal(:postal, User.current_location_format)
    assert_query([albion, elgin_co], :Location, :in_set,
                 ids: [albion.id, elgin_co.id], by: :name)

    User.current = roy
    assert_equal(:scientific, User.current_location_format)
    assert_query([elgin_co, albion], :Location, :in_set,
                 ids: [albion.id, elgin_co.id], by: :name)

    obs1 = observations(:minimal_unknown_obs)
    obs2 = observations(:detailed_unknown_obs)
    obs1.update(location: albion)
    obs2.update(location: elgin_co)

    User.current = rolf
    assert_equal(:postal, User.current_location_format)
    assert_query([obs1, obs2], :Observation, :in_set,
                 ids: [obs1.id, obs2.id], by: :location)

    User.current = roy
    assert_equal(:scientific, User.current_location_format)
    assert_query([obs2, obs1], :Observation, :in_set,
                 ids: [obs1.id, obs2.id], by: :location)
  end
end
