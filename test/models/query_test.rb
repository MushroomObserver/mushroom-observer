# encoding: utf-8

require 'test_helper'
require 'set'
class QueryTest < UnitTestCase

  def assert_state_exists(id)
    assert(!id.nil? && Query.find(id))
  end

  def assert_state_not_exists(id)
    assert_nil(Query.safe_find(id))
  end

  def assert_query(expect, *args)
    expect.map!(&:id) if expect.first.is_a?(AbstractModel)
    query = Query.lookup(*args)
    assert((Set.new(expect) - Set.new(query.result_ids)).empty?, query.last_query)
    assert_match(/#{args[0].t}|Advanced Search|(Lower|Higher) Taxa/, query.title)
    assert(!query.title.include?('[:'), "Title contains undefined localizations: <#{query.title}>")
  end

  def clean(str)
    str.gsub(/\s+/, ' ').strip
  end

################################################################################

  def test_basic
    assert(Query.all_models.include?(:Observation))
    assert(!Query.all_models.include?(:BogusModel))
    assert_raises(RuntimeError) {Query.lookup(:BogusModel)}

    assert(Query.all_flavors.include?(:all))
    assert(!Query.all_models.include?(:bogus))
    assert_raises(RuntimeError) {Query.lookup(:Name, :bogus)}

    query = Query.lookup(:Observation)
    assert(query.new_record?)

    assert_equal(Observation, query.model)
    assert_equal(:Observation, query.model_symbol)
    assert_equal('Observation', query.model_string)
    assert_equal(:all, query.flavor)

    query2 = Query.lookup_and_save(:Observation)
    assert(!query2.new_record?)
    assert_not_equal(query, query2)

    assert_equal(query2, Query.safe_find(query2.id))
    assert_nil(Query.safe_find(0))

    updated_at = query2.updated_at
    assert_equal(0, query2.access_count)
    query3 = Query.lookup(:Observation)
    assert_equal(query2, query3)
    assert_equal(updated_at.to_s, query3.updated_at.to_s)
    assert_equal(0, query3.access_count)
  end

  def test_validate_params
    @fungi = names(:fungi)

    assert_raises(RuntimeError) { Query.lookup(:Name, :all, :xxx => true) }
    assert_raises(RuntimeError) { Query.lookup(:Name, :all, :by => [1, 2, 3]) }
    assert_raises(RuntimeError) { Query.lookup(:Name, :all, :by => true) }
    assert_equal('id', Query.lookup(:Name, :all, :by => :id).params[:by])

    assert_equal(:either, Query.lookup(:Name, :all, :misspellings => :either).params[:misspellings])
    assert_equal(:either, Query.lookup(:Name, :all, :misspellings => 'either').params[:misspellings])
    assert_raises(RuntimeError) { Query.lookup(:Name, :all, :misspellings => 'bogus') }
    assert_raises(RuntimeError) { Query.lookup(:Name, :all, :misspellings => true) }
    assert_raises(RuntimeError) { Query.lookup(:Name, :all, :misspellings => 123) }

    assert_raises(RuntimeError) { Query.lookup(:Image, :by_user) }
    assert_raises(RuntimeError) { Query.lookup(:Image, :by_user, :user => :bogus) }
    assert_raises(RuntimeError) { Query.lookup(:Image, :by_user, :user => 'rolf') }
    assert_raises(RuntimeError) { Query.lookup(:Image, :by_user, :user => @fungi) }
    assert_equal(1, Query.lookup(:Image, :by_user, :user => rolf).params[:user])
    assert_equal(1, Query.lookup(:Image, :by_user, :user => rolf.id).params[:user])
    assert_equal(1, Query.lookup(:Image, :by_user, :user => rolf.id.to_s).params[:user])

    assert_raises(RuntimeError) { Query.lookup(:User, :in_set) }
    # Oops, :in_set query is generic, doesn't know to require Name instances here.
    # assert_raises(RuntimeError) { Query.lookup(:Name, :in_set, :ids => rolf) }
    assert_raises(RuntimeError) { Query.lookup(:Name, :in_set, :ids => 'one') }
    assert_raises(RuntimeError) { Query.lookup(:Name, :in_set, :ids => '1,2,3') }
    assert_equal([],    Query.lookup(:User, :in_set, :ids => []).params[:ids])
    assert_equal([1],   Query.lookup(:User, :in_set, :ids => 1).params[:ids])
    assert_equal([1],   Query.lookup(:Name, :in_set, :ids => '1').params[:ids])
    assert_equal([1,2], Query.lookup(:User, :in_set, :ids => [1,2]).params[:ids])
    assert_equal([1,2], Query.lookup(:User, :in_set, :ids => ['1','2']).params[:ids])
    assert_equal([1],   Query.lookup(:User, :in_set, :ids => rolf).params[:ids])
    assert_equal([1,2], Query.lookup(:User, :in_set, :ids => [rolf, mary]).params[:ids])
    assert_equal([1,2,3], Query.lookup(:User, :in_set, :ids => [rolf, 2, '3']).params[:ids])

    assert_raises(RuntimeError) { Query.lookup(:Name, :pattern_search) }
    assert_raises(RuntimeError) { Query.lookup(:Name, :pattern_search, :pattern => true) }
    assert_raises(RuntimeError) { Query.lookup(:Name, :pattern_search, :pattern => [1, 2, 3]) }
    assert_raises(RuntimeError) { Query.lookup(:Name, :pattern_search, :pattern => rolf) }
    assert_equal('123', Query.lookup(:Name, :pattern_search, :pattern => 123).params[:pattern])
    assert_equal('rolf', Query.lookup(:Name, :pattern_search, :pattern => 'rolf').params[:pattern])
    assert_equal('rolf', Query.lookup(:Name, :pattern_search, :pattern => :rolf).params[:pattern])

    assert_raises(RuntimeError) { Query.lookup(:Name, :of_children) }
    assert_equal(nil, Query.lookup(:Name, :of_children, :name => @fungi).params[:all])
    assert_equal(false, Query.lookup(:Name, :of_children, :name => @fungi, :all => false).params[:all])
    assert_equal(false, Query.lookup(:Name, :of_children, :name => @fungi, :all => 'false').params[:all])
    assert_equal(false, Query.lookup(:Name, :of_children, :name => @fungi, :all => 0).params[:all])
    assert_equal(false, Query.lookup(:Name, :of_children, :name => @fungi, :all => :no).params[:all])
    assert_equal(true, Query.lookup(:Name, :of_children, :name => @fungi, :all => true).params[:all])
    assert_equal(true, Query.lookup(:Name, :of_children, :name => @fungi, :all => 'true').params[:all])
    assert_equal(true, Query.lookup(:Name, :of_children, :name => @fungi, :all => 1).params[:all])
    assert_equal(true, Query.lookup(:Name, :of_children, :name => @fungi, :all => :yes).params[:all])
    assert_raises(RuntimeError) { Query.lookup(:Name, :of_children, :name => @fungi, :all => [123]) }
    assert_raises(RuntimeError) { Query.lookup(:Name, :of_children, :name => @fungi, :all => 'bogus') }
    assert_raises(RuntimeError) { Query.lookup(:Name, :of_children, :name => @fungi, :all => rolf) }

    assert_equal(['table'], Query.lookup(:Name, :all, :join => :table).params[:join])
    assert_equal(['table1','table2'], Query.lookup(:Name, :all, :join => [:table1, :table2]).params[:join])
    assert_equal(['table'], Query.lookup(:Name, :all, :tables => :table).params[:tables])
    assert_equal(['table1','table2'], Query.lookup(:Name, :all, :tables => [:table1, :table2]).params[:tables])
    assert_equal(['foo = bar'], Query.lookup(:Name, :all, :where => 'foo = bar').params[:where])
    assert_equal(['foo = bar','id in (1,2,3)'], Query.lookup(:Name, :all, :where => ['foo = bar', 'id in (1,2,3)']).params[:where])
    assert_equal('names.id', Query.lookup(:Name, :all, :group => 'names.id').params[:group])
    assert_equal('id DESC', Query.lookup(:Name, :all, :order => 'id DESC').params[:order])
    assert_raises(RuntimeError) { Query.lookup(:Name, :all, :group => ['1', '2']) }
    assert_raises(RuntimeError) { Query.lookup(:Name, :all, :order => ['1', '2']) }
  end

    def test_initialize_helpers
      query = Query.lookup(:Name)

      assert_equal('4,1,2', query.clean_id_set(['4', 1, 4, 2, 4, 1, 2]))
      assert_equal('-1', query.clean_id_set([]))

      assert_equal('blah', query.clean_pattern('blah'))
      assert_equal('foo bar', query.clean_pattern('foo bar'))
      assert_equal('\\"foo\\%bar\\"', query.clean_pattern('"foo%bar"'))
      assert_equal('one\\\\two', query.clean_pattern('one\\two'))
      assert_equal("foo%bar", query.clean_pattern('foo*bar'))

      assert_equal(nil, query.and_clause())
      assert_equal('one', query.and_clause('one'))
      assert_equal('(one AND two)', query.and_clause('one', 'two'))
      assert_equal('(one AND two AND three)', query.and_clause('one', 'two', 'three'))

      assert_equal(nil, query.or_clause())
      assert_equal('one', query.or_clause('one'))
      assert_equal('(one OR two)', query.or_clause('one', 'two'))
      assert_equal('(one OR two OR three)', query.or_clause('one', 'two', 'three'))
    end

    def test_google_parse
      query = Query.lookup(:Name)
      assert_equal([['blah']], query.google_parse('blah').goods)
      assert_equal([['foo','bar']], query.google_parse('foo OR bar').goods)
      assert_equal([['one'],['foo','bar'],['two']], query.google_parse('one foo OR bar two').goods)
      assert_equal([['one'],['foo','bar','quoted phrase','-gar'],['two']], query.google_parse('one foo OR bar OR "quoted phrase" OR -gar two').goods)
      assert_equal([], query.google_parse('-bad').goods)
      assert_equal(['bad'], query.google_parse('-bad').bads)
      assert_equal(['bad'], query.google_parse('foo -bad bar').bads)
      assert_equal(['bad wolf'], query.google_parse('foo -"bad wolf" bar').bads)
      assert_equal(['bad wolf','foo','bar'], query.google_parse('-"bad wolf" -foo -bar').bads)
    end

    def test_google_conditions
      query = Query.lookup(:Name)
      assert_equal(
        ["x LIKE '%blah%'"],
        query.google_conditions(query.google_parse('blah'), 'x')
      )
      assert_equal(
        ["x NOT LIKE '%bad%'"],
        query.google_conditions(query.google_parse('-bad'), 'x')
      )
      assert_equal(
        ["x LIKE '%foo%' AND x NOT LIKE '%bad%'"],
        query.google_conditions(query.google_parse('foo -bad'), 'x')
      )
      assert_equal(
        ["x LIKE '%foo%' AND x LIKE '%bar%' AND x NOT LIKE '%bad%'"],
        query.google_conditions(query.google_parse('foo bar -bad'), 'x')
      )
      assert_equal(
        ["(x LIKE '%foo%' OR x LIKE '%bar%') AND x NOT LIKE '%bad%'"],
        query.google_conditions(query.google_parse('foo OR bar -bad'), 'x')
      )
      assert_equal(
        ["(x LIKE '%foo%' OR x LIKE '%bar%' OR x LIKE '%any%thing%') AND x LIKE '%surprise!%' AND x NOT LIKE '%bad%' AND x NOT LIKE '%lost boys%'"],
        query.google_conditions(query.google_parse('foo OR bar OR "any*thing" -bad surprise! -"lost boys"'), 'x')
      )
    end

  def test_lookup
    assert_equal(0, Query.count)

    q1 = Query.lookup_and_save(:Observation)
    assert_equal(1, Query.count)

    q2 = Query.lookup_and_save(:Observation, :pattern_search, :pattern => 'blah')
    assert_equal(2, Query.count)

    # New because params are different from q1.
    q3 = Query.lookup_and_save(:Observation, :all, :by => :id)
    assert_equal(3, Query.count)

    # Not new because flavor is explicitly defaulted before validate.
    q4 = Query.lookup_and_save(:Observation, :all)
    assert_equal(3, Query.count)
    assert_equal(q1, q4, Query.count)

    # Ditto default flavor.
    q5 = Query.lookup_and_save(:Observation, :default, :by => :id)
    assert_equal(3, Query.count)
    assert_equal(q3, q5, Query.count)

    # New pattern is new query.
    q6 = Query.lookup_and_save(:Observation, :pattern_search, :pattern => 'new blah')
    assert_equal(4, Query.count)

    # Old pattern but new order.
    q7 = Query.lookup_and_save(:Observation, :pattern_search, :pattern => 'blah', :by => :date)
    assert_equal(5, Query.count)

    # Identical, even though :by is explicitly set in one.
    q8 = Query.lookup_and_save(:Observation, :pattern_search, :pattern => 'blah')
    assert_equal(5, Query.count)

    # Identical query, but new query because order given explicitly.  Order is
    # not given default until query is initialized, thus default not stored in
    # params, so lookup doesn't know about it.
    q9 = Query.lookup_and_save(:Observation, :all, :by => :date)
    assert_equal(6, Query.count)

    # Just a sanity check.
    q10 = Query.lookup_and_save(:Name)
    assert_equal(7, Query.count)
  end

  def test_cleanup
    # Due to the modified => updated_at change explicitly setting updated_at this way doesn't
    # work.  However, I don't really understand what this test does or if it's important, since
    # the time zone comment is definitely inaccurate. - NJW

    # This avoids any possible difference in time zone between mysql and you.
    # (This should be obsolete, but timezone handling is tested elsewhere.)
    now = DateTime.parse(Query.connection.select_value("SELECT NOW()").to_s)

    s11 = Query.new(:access_count => 0, :updated_at => now - 1.minute)
    s12 = Query.new(:access_count => 0, :updated_at => now - 6.hour + 1.minute)
    s13 = Query.new(:access_count => 0, :updated_at => now - 6.hour - 1.minute)
    s14 = Query.new(:access_count => 0, :updated_at => now - 1.day + 1.minute)
    s15 = Query.new(:access_count => 0, :updated_at => now - 1.day - 1.minute)
    s21 = Query.new(:access_count => 1, :updated_at => now - 1.minute)
    s22 = Query.new(:access_count => 1, :updated_at => now - 6.hour + 1.minute)
    s23 = Query.new(:access_count => 1, :updated_at => now - 6.hour - 1.minute)
    s24 = Query.new(:access_count => 1, :updated_at => now - 1.day + 1.minute)
    s25 = Query.new(:access_count => 1, :updated_at => now - 1.day - 1.minute)

    assert_save(s11)
    assert_save(s12)
    assert_save(s13)
    assert_save(s14)
    assert_save(s15)
    assert_save(s21)
    assert_save(s22)
    assert_save(s23)
    assert_save(s24)
    assert_save(s25)

    s11 = s11.id
    s12 = s12.id
    s13 = s13.id
    s14 = s14.id
    s15 = s15.id
    s21 = s21.id
    s22 = s22.id
    s23 = s23.id
    s24 = s24.id
    s25 = s25.id

    assert_state_exists(s11)
    assert_state_exists(s12)
    assert_state_exists(s13)
    assert_state_exists(s14)
    assert_state_exists(s15)
    assert_state_exists(s21)
    assert_state_exists(s22)
    assert_state_exists(s23)
    assert_state_exists(s24)
    assert_state_exists(s25)

    Query.cleanup

    assert_state_exists(s11)
    assert_state_exists(s12)
    assert_state_not_exists(s13)
    assert_state_not_exists(s14)
    assert_state_not_exists(s15)
    assert_state_exists(s21)
    assert_state_exists(s22)
    assert_state_exists(s23)
    assert_state_exists(s24)
    assert_state_not_exists(s25)
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
      assert_equal('', query.group)
      assert_not_equal('', query.order) # whatever the default order is

      # Clean it out completely.
      query.where = []
      query.order = ''

      assert_equal(
        'SELECT DISTINCT names.id FROM `names`',
        clean(query.query)
      )
      assert_equal(
        'SELECT foo bar FROM `names`',
        clean(query.query(:select => 'foo bar'))
      )
      assert_equal(
        'SELECT DISTINCT names.id FROM `names` JOIN `rss_logs` ON names.rss_log_id = rss_logs.id',
        clean(query.query(:join => :rss_logs))
      )
      assert_equal(
        'SELECT DISTINCT names.id FROM `names` JOIN `observations` ON observations.name_id = names.id JOIN `rss_logs` ON observations.rss_log_id = rss_logs.id',
        clean(query.query(:join => {:observations => :rss_logs}))
      )
      assert_equal(
        'SELECT DISTINCT names.id FROM `names`, `rss_logs`',
        clean(query.query(:tables => :rss_logs))
      )
      assert_equal(
        'SELECT DISTINCT names.id FROM `names`, `images`, `comments`',
        clean(query.query(:tables => [:images, :comments]))
      )
      assert_equal(
        'SELECT DISTINCT names.id FROM `names` WHERE shazam!',
        clean(query.query(:where => 'shazam!'))
      )
      assert_equal(
        'SELECT DISTINCT names.id FROM `names` WHERE foo AND bar',
        clean(query.query(:where => ['foo', 'bar']))
      )
      assert_equal(
        'SELECT DISTINCT names.id FROM `names` WHERE foo AND bar',
        clean(query.query(:where => ['foo', 'bar']))
      )
      assert_equal(
        'SELECT DISTINCT names.id FROM `names` GROUP BY blah blah blah',
        clean(query.query(:group => 'blah blah blah'))
      )
      assert_equal(
        'SELECT DISTINCT names.id FROM `names` ORDER BY foo, bar, names.id DESC',
        clean(query.query(:order => 'foo, bar')) # (tacks on 'id DESC' for disambiguation)
      )
      assert_equal(
        'SELECT DISTINCT names.id FROM `names` ORDER BY comments.id ASC',
        clean(query.query(:order => 'comments.id ASC')) # (sees id in there already)
      )
      assert_equal(
        'SELECT DISTINCT names.id FROM `names` LIMIT 10',
        clean(query.query(:limit => 10))
      )

      # Now, all together...
      assert_equal(
        'SELECT names.* FROM `names`, `images` ' +
        'JOIN `observations` ON observations.name_id = names.id ' +
        'JOIN `users` ON names.reviewer_id = users.id ' +
        'WHERE one = two AND foo LIKE bar ' +
        'GROUP BY blah.id ORDER BY names.id ASC LIMIT 10, 10',
        clean(query.query(
          :select => 'names.*',
          :join   => [:observations, :'users.reviewer'],
          :tables => :images,
          :where  => ['one = two', 'foo LIKE bar'],
          :group  => 'blah.id',
          :order  => 'names.id ASC',
          :limit  => '10, 10'
        ))
      )
    end

    def test_join_conditions
      query = Query.lookup(:Name)
      query.initialize_query
      query.where = []
      query.order = ''

      # Yikes!!  This should about test everything.
      sql = query.query(:join => [{:observations => [:locations, :comments, {:images_observations => :images}]}, :'users.reviewer'])
      assert_match(/names.reviewer_id = users.id/, sql)
      assert_match(/observations.name_id = names.id/, sql)
      assert_match(/observations.location_id = locations.id/, sql)
      assert_match(/comments.target_id = observations.id/, sql)
      assert_match(/comments.target_type = 'Observation'/, sql)
      assert_match(/images_observations.observation_id = observations.id/, sql)
      assert_match(/images_observations.image_id = images.id/, sql)
    end

    def test_reverse_order
      query = Query.lookup(:Name)
      assert_equal('', query.reverse_order(''))
      assert_equal('id ASC', query.reverse_order('id DESC'))
      assert_equal('one ASC, two DESC, three ASC', query.reverse_order('one DESC, two ASC, three DESC'))
      assert_equal('IF(users.name = "", users.login, users.name) DESC, users.id ASC',
        query.reverse_order('IF(users.name = "", users.login, users.name) ASC, users.id DESC'))
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
    query = Query.lookup(:Name, :all, :misspellings => :either, :by => :id)

    @fungi = names(:fungi)
    @agaricus = names(:agaricus)
    num = Name.count
    # num_agaricus = Name.count(:conditions => 'text_name LIKE "Agaricus%"') # Rails 3
    num_agaricus = Name.where('text_name LIKE "Agaricus%"').count

    assert_equal(num, query.select_count)
    assert_equal(num, query.select_count(limit: 10)) # limit limits no. of counts!!
    assert_equal(num_agaricus,
                 query.select_count(where: 'text_name LIKE "Agaricus%"'))

    assert_equal("1", query.select_value.to_s) # first id
    assert_equal("11", query.select_value(limit: "10, 10").to_s) # tenth id
    assert_equal(num.to_s, query.select_value(order: :reverse).to_s) # last id
    assert_equal("Fungi", query.select_value(select: "text_name").to_s)

    assert_equal((1..num).map(&:to_s), query.select_values.map(&:to_s))
    assert_equal(['3','18','19','20','21'],
                 query.select_values(where: 'text_name LIKE "Agaricus%"').
                       map(&:to_s))

    agaricus = query.select_values(select: "text_name",
                                   where: 'text_name LIKE "Agaricus%"').
                     map(&:to_s)
    assert_equal(num_agaricus, agaricus.uniq.length)
    assert_equal(num_agaricus,
                 agaricus.select {|x| x[0,8] == "Agaricus"}.length)

    if RUBY_VERSION < "1.9"
      assert_equal((1..num).map {|x| [x.to_s]}, query.select_rows)
      assert_equal((1..num).map {|x| {"id" => x.to_s}}, query.select_all)
      assert_equal({"id" => "1"}, query.select_one)
    else
      assert_equal((1..num).map {|x| [x]}, query.select_rows)
      assert_equal((1..num).map {|x| {"id" => x}}, query.select_all)
      assert_equal({"id" => 1}, query.select_one)
    end
    assert_equal([@fungi], query.find_by_sql(limit: 1))
    assert_equal(@agaricus.children.sort_by(&:id),
                 query.find_by_sql(where: 'text_name LIKE "Agaricus %"'))
  end

  def test_tables_used
    query = Query.lookup(:Observation, :all, :by => :id)
    assert_equal([:observations], query.tables_used)

    query = Query.lookup(:Observation, :all, :by => :name)
    assert_equal([:names,:observations], query.tables_used)

    query = Query.lookup(:Image, :all, :by => :name)
    assert_equal([:images,:images_observations,:names,:observations], query.tables_used)
    assert_equal(true, query.uses_table?(:images))
    assert_equal(true, query.uses_table?(:images_observations))
    assert_equal(true, query.uses_table?(:names))
    assert_equal(true, query.uses_table?(:observations))
    assert_equal(false, query.uses_table?(:comments))
  end

  def test_results
    query = Query.lookup(:User, :all, :by => :id)
    assert_equal(Set.new, Set.new([1,2,3,4,5,6]) - query.result_ids)
    assert_equal(roy.location_format, :scientific)
    assert_equal(Set.new, Set.new([rolf,mary,junk,dick,katrina,roy]) - query.results)
    assert_equal(2, query.index(3))
    assert_equal(3, query.index('4'))
    assert_equal(1, query.index(mary))

    # Verify that it's getting all this crap from cache.
    query.result_ids = [1,3,5,100]
    assert_equal([rolf,junk,katrina], query.results)

    # Should be able to set it this way, to.
    query.results = [dick, mary, rolf]
    assert_equal(3, query.num_results)
    assert_equal([4,2,1], query.result_ids)
    assert_equal([dick,mary,rolf], query.results)
    assert_equal(1, query.index(mary))
    assert_equal(2, query.index(1))
  end

  def test_paginate
    # The only methods of Paginator used by Query are:
    #   from, to      index of first and last itemto show
    #   num_total=    lets Query tell it how many results there are
    #   letter        selected letter (if any)
    #   used_letters= lets Query tell it which letters have results
    query = Query.lookup(:Name, :all, :misspellings => :either, :by => :id)
    @names = Name.all

    pages = Wrapper.new(:from => 1, :to => 4)
    assert_equal([2,3,4,5], query.paginate_ids(pages))
    assert_equal(@names.size, pages.num_total)
    assert_equal(@names[1..4], query.paginate(pages))

    pages = Wrapper.new(:from => 5, :to => 8)
    assert_equal([6,7,8,9], query.paginate_ids(pages))
    assert_equal(@names.size, pages.num_total)
    assert_equal(@names[5..8], query.paginate(pages))

    pages = Wrapper.new(:from => 1, :to => 4)
    query.need_letters = 'names.text_name'
    assert_equal([2,3,4,5], query.paginate_ids(pages))
    assert_equal(@names.size, pages.num_total)
    assert_equal(@names[1..4], query.paginate(pages))
    letters = @names.map {|n| n.text_name[0,1]}.uniq
    assert_equal(letters.sort, pages.used_letters.sort)

    # Make sure we have a bunch of Lactarii, Leptiotas, etc.
    @ells = @names.select {|n| n.text_name[0,1] == 'L'}
    assert(@ells.length >= 9)

    pages = Wrapper.new(:from => 3, :to => 6, :letter => 'L')
    # Need to clear out cache or used_letters will be wrong.
    query.clear_cache
    assert_equal(@ells[3..6].map(&:id), query.paginate_ids(pages))
    assert_equal(letters.sort, pages.used_letters.sort)
    assert_equal(@ells[3..6], query.paginate(pages))
  end

  def test_eager_instantiator
    query = Query.lookup(:Observation)
    ids = query.result_ids

    first = query.instantiate([ids[0]]).first
    assert(!first.images.loaded?)

    first = query.instantiate([ids[0]], :include => :images).first
    assert(!first.images.loaded?)

    # Have to test it on a different one, because first is now cached.
    second = query.instantiate([ids[1]], :include => :images).first
    assert(second.images.loaded?)

    # Or we can clear out the cache and it will work...
    query.clear_cache
    first = query.instantiate([ids[0]], :include => :images).first
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

    query.current_id = 1
    assert_equal(1, query.current_id)
    assert_equal(@fungi, query.current)

    query.current = @agaricus
    assert_equal(@agaricus.id, query.current_id)
    assert_equal(@agaricus, query.current)

    query.current = @peltigera.id
    assert_equal(@peltigera.id, query.current_id)
    assert_equal(@peltigera, query.current)
  end

  def test_next_and_prev
    query = Query.lookup(:Name, :all, :misspellings => :either, :by => :id)
    @names = Name.all

    query.current = @names[2]
    assert_equal(query, query.prev); assert_equal(@names[1].id, query.current_id)
    assert_equal(query, query.prev); assert_equal(@names[0].id, query.current_id)
    assert_equal(nil, query.prev)  ; assert_equal(@names[0].id, query.current_id)
    assert_equal(query, query.next); assert_equal(@names[1].id, query.current_id)
    assert_equal(query, query.next); assert_equal(@names[2].id, query.current_id)
    assert_equal(query, query.last); assert_equal(@names[-1].id, query.current_id)
    assert_equal(query, query.last); assert_equal(@names[-1].id, query.current_id)
    assert_equal(nil,   query.next); assert_equal(@names[-1].id, query.current_id)
    assert_equal(query, query.first); assert_equal(@names[0].id, query.current_id)
    assert_equal(query, query.first); assert_equal(@names[0].id, query.current_id)
    query.reset;                      assert_equal(@names[2].id, query.current_id)
  end

  def assert_starts_with(expected, result)
    assert_equal(expected, result[0..expected.length-1])
  end

  def test_inner_outer
    # obs 2: imgs 1, 2
    # obs 3: imgs 5
    # obs 4: imgs 6
    # obs 12: imgs 8

    outer = Query.lookup_and_save(:Observation, :all, by: :id)

    q = Query.lookup(:Image, :inside_observation, outer: outer,
                     observation: 1, by: :id)
    assert_equal([], q.result_ids)

    inner1 = Query.lookup_and_save(:Image, :inside_observation, outer: outer,
                                   observation: 2, by: :id)
    assert_equal([1,2], inner1.result_ids)

    inner2 = Query.lookup_and_save(:Image, :inside_observation, outer: outer,
                                   observation: 3, by: :id)
    assert_equal([5], inner2.result_ids)

    inner3 = Query.lookup_and_save(:Image, :inside_observation, outer: outer,
                                   observation: 4, by: :id)
    assert_equal([6], inner3.result_ids)

    inner4 = Query.lookup_and_save(:Image, :inside_observation, outer: outer,
                                   observation: 12, by: :id)
    assert_equal([8], inner4.result_ids)

    q = inner1
    assert(q.has_outer?)
    assert_equal(outer, q.outer) # it's been tweaked but still same id
    assert_equal(2, inner1.get_outer_current_id)
    assert_equal(3, inner2.get_outer_current_id)
    assert_equal(4, inner3.get_outer_current_id)
    assert_equal(12, inner4.get_outer_current_id)

    q = q.outer
    results = q.result_ids
    assert_starts_with([2, 3, 4, 12], results)
    q.current_id = results[1]
    assert_equal(q, q.first); assert_equal(results[0], q.current_id)
    assert_equal(q, q.last); assert_equal(results[-1], q.current_id)

    q = inner1
    q.current_id = 1
    assert_nil(q.prev)
    assert_equal(inner1, (q=q.next));  assert_equal(2, q.current_id)
    assert_equal(inner1, (q=q.prev));  assert_equal(1, q.current_id)
    assert_equal(inner1, (q=q.next));  assert_equal(2, q.current_id)
    assert_equal(inner2, (q=q.next));  assert_equal(5, q.current_id)
    assert_equal(inner3, (q=q.next));  assert_equal(6, q.current_id)
    assert_equal(inner4, (q=q.next));  assert_equal(8, q.current_id)
    assert(q.next)
    assert_equal(inner3, (q=q.prev));  assert_equal(6, q.current_id)
    assert_equal(inner2, (q=q.prev));  assert_equal(5, q.current_id)
    assert_equal(inner1, (q=q.prev));  assert_equal(2, q.current_id)
    assert_equal(inner2, (q=q.next));  assert_equal(5, q.current_id)
    assert_equal(inner1, (q=q.first)); assert_equal(1, q.current_id)
    # assert_equal(inner4, (q=q.last));  assert_equal(8, q.current_id)
    assert_nil(q.last.next)
  end

  ##############################################################################
  #
  #  :section: Test Coerce
  #
  ##############################################################################

  def test_basic_coerce
    assert_equal(0, Query.count)

    q1 = Query.lookup_and_save(:Observation, :pattern_search, :pattern => 'search')
    assert_equal(1, Query.count)

    # Trvial coercion: any flavor from a model to the same model.
    q2 = q1.coerce(:Observation)
    assert_equal(q1, q2)
    assert_equal(1, Query.count)

    # No search is coercable to RssLog (yet).
    q3 = q1.coerce(:RssLog)
    assert_nil(q3)
    assert_equal(1, Query.count)
  end

  def test_observation_image_coercion
    # Several observation queries can be turned into name queries.
    q1a = Query.lookup_and_save(:Observation, :all, :by => :id)
    q2a = Query.lookup_and_save(:Observation, :by_user, :user => 2)
    q3a = Query.lookup_and_save(:Observation, :in_species_list, :species_list => 1)
    q4a = Query.lookup_and_save(:Observation, :of_name, :name => 4)
    q5a = Query.lookup_and_save(:Observation, :in_set, :ids => [2,4,6])
    q6a = Query.lookup_and_save(:Observation, :pattern_search, :pattern => '"somewhere else"')
    q7a = Query.lookup_and_save(:Observation, :advanced_search, :location => 'glendale')
    q8a = Query.lookup_and_save(:Observation, :at_location, :location => 2)
    q9a = Query.lookup_and_save(:Observation, :at_where, :user_where => 'california', :location => 'california')
    qAa = Query.lookup_and_save(:Observation, :of_children, :name => 4)
    assert_equal(10, Query.count)

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
    assert(q1b.new_record?); assert_save(q1b)
    assert(q2b.new_record?); assert_save(q2b)
    assert(q3b.new_record?); assert_save(q3b)
    assert(q4b.new_record?); assert_save(q4b)
    assert(q5b.new_record?); assert_save(q5b)
    assert(q6b.new_record?); assert_save(q6b)
    assert(q7b.new_record?); assert_save(q7b)
    assert(q8b.new_record?); assert_save(q8b)
    assert(q9b.new_record?); assert_save(q9b)
    assert(qAb.new_record?); assert_save(qAb)

    # Check their descriptions.
    assert_equal(:Image, q1b.model_symbol)
    assert_equal(:Image, q2b.model_symbol)
    assert_equal(:Image, q3b.model_symbol)
    assert_equal(:Image, q4b.model_symbol)
    assert_equal(:Image, q5b.model_symbol)
    assert_equal(:Image, q6b.model_symbol)
    assert_equal(:Image, q7b.model_symbol)
    assert_equal(:Image, q8b.model_symbol)
    assert_equal(:Image, q9b.model_symbol)
    assert_equal(:Image, qAb.model_symbol)

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
    assert(q1c.new_record?)  # (lost order)
    assert(!q2c.new_record?); assert_equal(q2a, q2c)
    assert(!q3c.new_record?); assert_equal(q3a, q3c)
    assert(!q4c.new_record?); assert_equal(q4a, q4c)
    assert(q5c.new_record?)  # (has an explicit title now)
    assert(q6c.new_record?)  # (converted to in_set)
    assert(q7c.new_record?)  # (converted to in_set)
    assert(!q8c.new_record?); assert_equal(q8a, q8c)
    assert(!q9c.new_record?); assert_equal(q9a, q9c)
    assert(!qAc.new_record?); assert_equal(qAa, qAc)

    # All four "new" ones should now be reversable.
    q1c.save; q1d = q1c.coerce(:Image); assert_equal(q1b, q1d)
    q5c.save; q5d = q5c.coerce(:Image); assert_equal(q5b, q5d)
    q6c.save; q6d = q6c.coerce(:Image); assert_equal(q6b, q6d)
    q7c.save; q7d = q7c.coerce(:Image); assert_equal(q7b, q7d)
  end

  def test_observation_location_coercion

    # Almost any query on observations should be mappable, i.e. coercable into
    # a query on those observations' locations.
    q1a = Query.lookup_and_save(:Observation, :all, :by => :id)
    q2a = Query.lookup_and_save(:Observation, :by_user, :user => 2)
    q3a = Query.lookup_and_save(:Observation, :in_species_list, :species_list => 1)
    q4a = Query.lookup_and_save(:Observation, :of_name, :name => 4)
    q5a = Query.lookup_and_save(:Observation, :in_set, :ids => [2,4,6])
    q6a = Query.lookup_and_save(:Observation, :pattern_search, :pattern => '"somewhere else"')
    q7a = Query.lookup_and_save(:Observation, :advanced_search, :location => 'glendale')
    q8a = Query.lookup_and_save(:Observation, :at_location, :location => 2)
    q9a = Query.lookup_and_save(:Observation, :at_where, :user_where => 'california', :location => 'california')
    qAa = Query.lookup_and_save(:Observation, :of_children, :name => 4)
    assert_equal(10, Query.count)

    # Try coercing them all.
    assert(q1b = q1a.coerce(:Location))
    assert(q2b = q2a.coerce(:Location))
    assert(q3b = q3a.coerce(:Location))
    assert(q4b = q4a.coerce(:Location))
    assert(q5b = q5a.coerce(:Location))
    assert(q6b = q6a.coerce(:Location))
    assert(q7b = q7a.coerce(:Location))
    assert(q8b = q8a.coerce(:Location))
    assert_nil(q9b = q9a.coerce(:Location))
    assert(qAb = qAa.coerce(:Location))

    # They should all be new records
    assert(q1b.new_record?); assert_save(q1b)
    assert(q2b.new_record?); assert_save(q2b)
    assert(q3b.new_record?); assert_save(q3b)
    assert(q4b.new_record?); assert_save(q4b)
    assert(q5b.new_record?); assert_save(q5b)
    assert(q6b.new_record?); assert_save(q6b)
    assert(q7b.new_record?); assert_save(q7b)
    assert(q8b.new_record?); assert_save(q8b)
    assert(qAb.new_record?); assert_save(qAb)

    # Check their descriptions.
    assert_equal(:Location, q1b.model_symbol)
    assert_equal(:Location, q2b.model_symbol)
    assert_equal(:Location, q3b.model_symbol)
    assert_equal(:Location, q4b.model_symbol)
    assert_equal(:Location, q5b.model_symbol)
    assert_equal(:Location, q6b.model_symbol)
    assert_equal(:Location, q7b.model_symbol)
    assert_equal(:Location, q8b.model_symbol)
    assert_equal(:Location, qAb.model_symbol)

    assert_equal(:with_observations, q1b.flavor)
    assert_equal(:with_observations_by_user, q2b.flavor)
    assert_equal(:with_observations_in_species_list, q3b.flavor)
    assert_equal(:with_observations_of_name, q4b.flavor)
    assert_equal(:with_observations_in_set, q5b.flavor)
    assert_equal(:with_observations_in_set, q6b.flavor)
    assert_equal(:with_observations_in_set, q7b.flavor)
    assert_equal(:in_set, q8b.flavor)
    assert_equal(:with_observations_of_children, qAb.flavor)

    assert_equal({}, q1b.params) # loses ordering
    assert_equal({:user => 2}, q2b.params)
    assert_equal({:species_list => 1}, q3b.params)
    assert_equal({:name => 4}, q4b.params)
    assert_equal({:ids => [2]}, q8b.params)
    assert_equal({:name => 4}, qAb.params)

    assert_equal([2,4,6],   q5b.params[:ids])
    assert_equal([8,7,6,5], q6b.params[:ids])
    assert_equal([3],       q7b.params[:ids])
    assert_match(/Selected.*Observations/,                  q5b.params[:old_title])
    assert_match(/Observations.*Matching.*somewhere.*else/, q6b.params[:old_title])
    assert_match(/Advanced.*Search/,                        q7b.params[:old_title])
    assert_equal(2, q5b.params.keys.length)
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
    assert_nil(q8c = q8b.coerce(:Observation))
    assert(qAc = qAb.coerce(:Observation))

    # Only some should be new.
    assert(q1c.new_record?)  # (lost order)
    assert(!q2c.new_record?); assert_equal(q2a, q2c)
    assert(!q3c.new_record?); assert_equal(q3a, q3c)
    assert(!q4c.new_record?); assert_equal(q4a, q4c)
    assert(q5c.new_record?)  # (has an explicit title now)
    assert(q6c.new_record?)  # (converted to in_set)
    assert(q7c.new_record?)  # (converted to in_set)
    assert(!qAc.new_record?); assert_equal(qAa, qAc)

    # All four "new" ones should now be reversable.
    q1c.save; q1d = q1c.coerce(:Location); assert_equal(q1b, q1d)
    q5c.save; q5d = q5c.coerce(:Location); assert_equal(q5b, q5d)
    q6c.save; q6d = q6c.coerce(:Location); assert_equal(q6b, q6d)
    q7c.save; q7d = q7c.coerce(:Location); assert_equal(q7b, q7d)
  end

  def test_observation_name_coercion
    # Several observation queries can be turned into name queries.
    q1a = Query.lookup_and_save(:Observation, :all, :by => :id)
    q2a = Query.lookup_and_save(:Observation, :by_user, :user => 2)
    q3a = Query.lookup_and_save(:Observation, :in_species_list, :species_list => 1)
    q4a = Query.lookup_and_save(:Observation, :of_name, :name => 4)
    q5a = Query.lookup_and_save(:Observation, :in_set, :ids => [2,4,6])
    q6a = Query.lookup_and_save(:Observation, :pattern_search, :pattern => '"somewhere else"')
    q7a = Query.lookup_and_save(:Observation, :advanced_search, :location => 'glendale')
    q8a = Query.lookup_and_save(:Observation, :at_location, :location => 2)
    q9a = Query.lookup_and_save(:Observation, :at_where, :user_where => 'california', :location => 'california')
    assert_equal(9, Query.count)

    # Try coercing them all.
    assert(q1b = q1a.coerce(:Name))
    assert(q2b = q2a.coerce(:Name))
    assert(q3b = q3a.coerce(:Name))
    assert_nil(q4b = q4a.coerce(:Name))  # (TODO)
    assert(q5b = q5a.coerce(:Name))
    assert(q6b = q6a.coerce(:Name))
    assert(q7b = q7a.coerce(:Name))
    assert(q8b = q8a.coerce(:Name))
    assert(q9b = q9a.coerce(:Name))

    # They should all be new records
    assert(q1b.new_record?); assert_save(q1b)
    assert(q2b.new_record?); assert_save(q2b)
    assert(q3b.new_record?); assert_save(q3b)
    # assert(q4b.new_record?); assert_save(q4b)
    assert(q5b.new_record?); assert_save(q5b)
    assert(q6b.new_record?); assert_save(q6b)
    assert(q7b.new_record?); assert_save(q7b)
    assert(q8b.new_record?); assert_save(q8b)
    assert(q9b.new_record?); assert_save(q9b)

    # Check their descriptions.
    assert_equal(:Name, q1b.model_symbol)
    assert_equal(:Name, q2b.model_symbol)
    assert_equal(:Name, q3b.model_symbol)
    # assert_equal(:Name, q4b.model_symbol)
    assert_equal(:Name, q5b.model_symbol)
    assert_equal(:Name, q6b.model_symbol)
    assert_equal(:Name, q7b.model_symbol)
    assert_equal(:Name, q8b.model_symbol)
    assert_equal(:Name, q9b.model_symbol)

    assert_equal(:with_observations, q1b.flavor)
    assert_equal(:with_observations_by_user, q2b.flavor)
    assert_equal(:with_observations_in_species_list, q3b.flavor)
    # assert_equal(:synonyms, q4b.flavor)
    assert_equal(:with_observations_in_set, q5b.flavor)
    assert_equal(:with_observations_in_set, q6b.flavor)
    assert_equal(:with_observations_in_set, q7b.flavor)
    assert_equal(:with_observations_at_location, q8b.flavor)
    assert_equal(:with_observations_at_where, q9b.flavor)

    # Now try to coerce them back to Observation.
    assert(q1c = q1b.coerce(:Observation))
    assert(q2c = q2b.coerce(:Observation))
    assert(q3c = q3b.coerce(:Observation))
    # assert(q4c = q4b.coerce(:Observation))
    assert(q5c = q5b.coerce(:Observation))
    assert(q6c = q6b.coerce(:Observation))
    assert(q7c = q7b.coerce(:Observation))
    assert(q8c = q8b.coerce(:Observation))
    assert(q9c = q9b.coerce(:Observation))

    # Only some should be new.
    assert(q1c.new_record?)  # (lost order)
    assert(!q2c.new_record?); assert_equal(q2a, q2c)
    assert(!q3c.new_record?); assert_equal(q3a, q3c)
    # assert(!q4c.new_record?); assert_equal(q4a, q4c)
    assert(q5c.new_record?)  # (has an explicit title now)
    assert(q6c.new_record?)  # (converted to in_set)
    assert(q7c.new_record?)  # (converted to in_set)
    assert(!q8c.new_record?); assert_equal(q8a, q8c)
    assert(!q9c.new_record?); assert_equal(q9a, q9c)

    # All four "new" ones should now be reversable.
    q1c.save; q1d = q1c.coerce(:Name); assert_equal(q1b, q1d)
    q5c.save; q5d = q5c.coerce(:Name); assert_equal(q5b, q5d)
    q6c.save; q6d = q6c.coerce(:Name); assert_equal(q6b, q6d)
    q7c.save; q7d = q7c.coerce(:Name); assert_equal(q7b, q7d)
  end

  def test_description_coercion
    # Several description queries can be turned into name queries and back.
    q1a = Query.lookup_and_save(:NameDescription, :all)
    q2a = Query.lookup_and_save(:NameDescription, :by_author, :user => 1)
    q3a = Query.lookup_and_save(:NameDescription, :by_editor, :user => 1)
    q4a = Query.lookup_and_save(:NameDescription, :by_user, :user => 1)
    assert_equal(4, Query.count)

    # Try coercing them into name queries.
    assert(q1b = q1a.coerce(:Name))
    assert(q2b = q2a.coerce(:Name))
    assert(q3b = q3a.coerce(:Name))
    assert(q4b = q4a.coerce(:Name))

    # They should all be new records
    assert(q1b.new_record?); assert_save(q1b)
    assert(q2b.new_record?); assert_save(q2b)
    assert(q3b.new_record?); assert_save(q3b)
    assert(q4b.new_record?); assert_save(q4b)

    # Make sure they're right.
    assert_equal(:Name, q1b.model_symbol)
    assert_equal(:Name, q2b.model_symbol)
    assert_equal(:Name, q3b.model_symbol)
    assert_equal(:Name, q4b.model_symbol)
    assert_equal(:with_descriptions, q1b.flavor)
    assert_equal(:with_descriptions_by_author, q2b.flavor)
    assert_equal(:with_descriptions_by_editor, q3b.flavor)
    assert_equal(:with_descriptions_by_user, q4b.flavor)
    assert_equal(1, q2b.params[:user])
    assert_equal(1, q3b.params[:user])
    assert_equal(1, q4b.params[:user])

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
    assert(q2); assert(q2.new_record?); assert_save(q2)
    assert(q3); assert(q3.new_record?); assert_save(q3)
    assert(q4); assert(q4.new_record?); assert_save(q4)
    assert(q5); assert(q5.new_record?); assert_save(q5)
    assert_nil(q6)

    # Make sure they are correct.
    assert_equal(:Location,    q2.model_symbol)
    assert_equal(:Name,        q3.model_symbol)
    assert_equal(:Observation, q4.model_symbol)
    assert_equal(:SpeciesList, q5.model_symbol)

    assert_equal(:by_rss_log, q2.flavor)
    assert_equal(:by_rss_log, q3.flavor)
    assert_equal(:by_rss_log, q4.flavor)
    assert_equal(:by_rss_log, q5.flavor)

    assert_equal({}, q2.params)
    assert_equal({}, q3.params)
    assert_equal({}, q4.params)
    assert_equal({}, q5.params)
  end

  ##############################################################################
  #
  #  :section: Test Query Results
  #
  ##############################################################################

  def test_comment_all
    expect = Comment.all.reverse
    assert_query(expect, :Comment, :all)
  end

  def test_comment_by_user
    expect = Comment.where(user_id: mary.id).reverse
    assert_query(expect, :Comment, :by_user, :user => mary)
  end

  def test_comment_in_set
    assert_query([3,1], :Comment, :in_set, :ids => [3,1])
  end

  def test_comment_for_user
    expect = Comment.all.reverse
    assert_query(expect, :Comment, :for_user, :user => mary)
    assert_query([], :Comment, :for_user, :user => rolf)
  end

  def test_image_advanced
    assert_query([6], :Image, :advanced_search, :name => 'Agaricus')
    assert_query([6,2,1], :Image, :advanced_search, :location => 'burbank')
    assert_query([5], :Image, :advanced_search, :location => 'glendale')
    assert_query([2,1], :Image, :advanced_search, :user => 'mary')
    assert_query([2,1], :Image, :advanced_search, :content => 'little')
    assert_query([5], :Image, :advanced_search, :content => 'fruiting')
    assert_query([], :Image, :advanced_search, :name => 'agaricus', :location => 'glendale')
    assert_query([6], :Image, :advanced_search, :name => 'agaricus', :location => 'burbank')
    assert_query([2,1], :Image, :advanced_search, :content => 'little', :location => 'burbank')
  end

  def test_image_all
    expect = Image.all.reverse
    assert_query(expect, :Image, :all)
  end

  def test_image_by_user
    expect = Image.where(user_id: rolf.id).reverse
    assert_query(expect, :Image, :by_user, :user => rolf)
#    expect = where(user_id: mary.id).reverse # Rails 3
    expect = Image.where(user_id: mary.id).reverse
    assert_query(expect, :Image, :by_user, :user => mary)
#    expect = where(user_id: dick.id).reverse # Rails 3
    expect = Image.where(user_id: dick.id).reverse
    assert_query(expect, :Image, :by_user, :user => dick)
  end

  def test_image_in_set
    assert_query([2,6,4], :Image, :in_set, :ids => [2,6,4])
  end

  def test_image_inside_observation
    obs = observations(:detailed_unknown)
    assert_equal(2, obs.images.length)
    expect = obs.images.sort_by(&:id)
    assert_query(expect, :Image, :inside_observation, :observation => obs,
                     :outer => 1) # (outer is only used by prev/next)
    obs = observations(:minimal_unknown)
    assert_equal(0, obs.images.length)
    assert_query(obs.images, :Image, :inside_observation, :observation => obs,
                     :outer => 1) # (outer is only used by prev/next)
  end

  def test_image_pattern
    assert_query([6], :Image, :pattern_search, :pattern => 'agaricus') # name
    assert_query([6, 5, 2, 1], :Image, :pattern_search, :pattern => 'bob dob') # copyright holder
    assert_query([1], :Image, :pattern_search, :pattern => 'looked gorilla OR original') # notes
    assert_query([6, 5], :Image, :pattern_search, :pattern => 'notes some') # notes
    assert_query([2, 1], :Image, :pattern_search, :pattern => 'dobbs -notes') # copyright and not notes
    assert_query([1], :Image, :pattern_search, :pattern => 'DSCN8835') # original filename
  end

  def test_image_with_observations
    assert_query([6, 5, 2, 1, 8], :Image, :with_observations)
  end

  def test_image_with_observations_at_location
    assert_query([6, 2, 1], :Image, :with_observations_at_location, :location => 2)
    assert_query([], :Image, :with_observations_at_location, :location => 3)
  end

  def test_image_with_observations_at_where
    assert_query([5], :Image, :with_observations_at_where, :user_where => 'glendale', :location => 'glendale')
    assert_query([], :Image, :with_observations_at_where, :user_where => 'snazzle', :location => 'snazzle')
  end

  def test_image_with_observations_by_user
    assert_query([6, 5, 8], :Image, :with_observations_by_user, :user => rolf)
    assert_query([2,1], :Image, :with_observations_by_user, :user => mary)
    assert_query([], :Image, :with_observations_by_user, :user => dick)
  end

  def test_image_with_observations_in_set
    assert_query([6, 2, 1], :Image, :with_observations_in_set, :ids => [2,4])
    assert_query([], :Image, :with_observations_in_set, :ids => [1])
  end

  def test_image_with_observations_in_species_list
    assert_query([2,1], :Image, :with_observations_in_species_list, :species_list => 3)
    assert_query([], :Image, :with_observations_in_species_list, :species_list => 1)
  end

  def test_image_with_observations_of_children
    assert_query([6], :Image, :with_observations_of_children, :name => names(:agaricus))
  end

  def test_image_sorted_by_original_name
    assert_query([2,5,4,1,3,6], :Image, :in_set, :ids => [1,2,3,4,5,6], :by => :original_name)
  end

  def test_image_with_observations_of_name
    assert_query([2,1], :Image, :with_observations_of_name, :name => 1)
    assert_query([5], :Image, :with_observations_of_name, :name => 2)
    assert_query([6], :Image, :with_observations_of_name, :name => 3)
    assert_query([], :Image, :with_observations_of_name, :name => 4)
  end

  def test_location_advanced
    assert_query([2], :Location, :advanced_search, :name => 'agaricus')
    assert_query([],  :Location, :advanced_search, :name => 'coprinus')
    assert_query([2], :Location, :advanced_search, :location => 'burbank')
    assert_query([9,4], :Location, :advanced_search, :location => 'park')
    assert_query([2], :Location, :advanced_search, :user => 'rolf')
    assert_query([],  :Location, :advanced_search, :user => 'dick')
    assert_query([2], :Location, :advanced_search, :content => '"strange place"') # obs.notes
    assert_query([2], :Location, :advanced_search, :content => '"a little of everything"') # comment
    assert_query([],  :Location, :advanced_search, :content => '"play with"') # no search loc.notes
    assert_query([2], :Location, :advanced_search, :name => 'agaricus', :content => '"lawn"')
    assert_query([],  :Location, :advanced_search, :name => 'agaricus', :content => '"play with"')
    assert_query([2], :Location, :advanced_search, :content => '"a little of everything" "strange place"') # from observation and comment for same observation
    assert_query([],  :Location, :advanced_search, :content => '"minimal unknown" "complicated"')          # from different comments, should fail
  end

  def test_location_all
#    expect = Location.all # Rails 3
    expect = Location.all.to_a
    assert_query(expect, :Location, :all, :by => :id)
  end

  def test_location_by_user
    # Rolf appears to have created every one except "unknown" (created by admin).
    assert_query(Location.all - [Location.unknown], :Location, :by_user,
                 :user => rolf, :by => :id)
    assert_query([], :Location, :by_user, :user => mary)
  end

  def test_location_by_editor
    assert_query([], :Location, :by_editor, :user => rolf)
    User.current = mary
    loc = Location.first
    loc.display_name = 'new name'
    loc.save
    assert_query([loc], :Location, :by_editor, :user => mary)
    assert_query([], :Location, :by_editor, :user => dick)
  end

  def test_location_by_rss_log
    assert_query([3], :Location, :by_rss_log)
  end

  def test_location_in_set
    assert_query([5,1,2,6], :Location, :in_set, :ids => [5,1,2,6])
  end

  def test_location_pattern
    expect = Location.all.select {|l| l.display_name =~ /california/i}
    assert_query(expect, :Location, :pattern_search, :pattern => "California", :by => :id)
    assert_query([6], :Location, :pattern_search, :pattern => 'Canada')
    assert_query([], :Location, :pattern_search, :pattern => 'Canada -Elgin')
  end

  def test_location_with_descriptions
    assert_query([1], :Location, :with_descriptions)
  end

  def test_location_with_descriptions_by_user
    assert_query([1], :Location, :with_descriptions_by_user, :user => rolf)
    assert_query([], :Location, :with_descriptions_by_user, :user => mary)
  end

  def test_location_with_descriptions_by_author
    assert_query([1], :Location, :with_descriptions_by_author, :user => rolf)
    assert_query([], :Location, :with_descriptions_by_author, :user => mary)
  end

  def test_location_with_descriptions_by_editor
    User.current = mary
    desc = location_descriptions(:albion_desc)
    desc.notes = "blah blah blah"
    desc.save
    assert_query([], :Location, :with_descriptions_by_editor, :user => rolf)
    assert_query([1], :Location, :with_descriptions_by_editor, :user => mary)
  end

  def test_location_with_observations
    assert_query([2], :Location, :with_observations)
  end

  def test_location_with_observations_by_user
    assert_query([2], :Location, :with_observations_by_user, :user => 1)
    assert_query([], :Location, :with_observations_by_user, :user => 4)
  end

  def test_location_with_observations_in_set
    assert_query([2], :Location, :with_observations_in_set, :ids => [1])
    assert_query([], :Location, :with_observations_in_set, :ids => [3])
  end

  def test_location_with_observations_in_species_list
    assert_query([2], :Location, :with_observations_in_species_list,
                 :species_list => 3)
    assert_query([], :Location, :with_observations_in_species_list,
                 :species_list => 1)
  end

  def test_location_with_observations_of_children
    assert_query([2], :Location, :with_observations_of_children, :name => names(:agaricus))
  end

  def test_location_with_observations_of_name
    name = names(:agaricus_campestris)
    assert_query([2], :Location, :with_observations_of_name, :name => name.id)
    name = names(:peltigera)
    assert_query([], :Location, :with_observations_of_name, :name => name.id)
  end

  def test_location_description_all
#    all = LocationDescription.all # Rails 3
    all = LocationDescription.all.to_a
    assert_query(all, :LocationDescription, :all, :by => :id)
  end

  def test_location_description_by_user
    assert_query([1], :LocationDescription, :by_user, :user => rolf)
    assert_query([], :LocationDescription, :by_user, :user => dick)
  end

  def test_location_description_by_author
    loc1, loc2, loc3 = Location.all
    desc1 = loc1.description ||= LocationDescription.create!(:location_id => loc1.id)
    desc2 = loc2.description ||= LocationDescription.create!(:location_id => loc2.id)
    desc3 = loc3.description ||= LocationDescription.create!(:location_id => loc3.id)
    desc1.add_author(rolf)
    desc2.add_author(mary)
    desc3.add_author(rolf)
    assert_query([desc1, desc3], :LocationDescription, :by_author, :user => rolf, :by => :id)
    assert_query([desc2], :LocationDescription, :by_author, :user => mary)
    assert_query([], :LocationDescription, :by_author, :user => dick)
  end

  def test_location_description_by_editor
    loc1, loc2, loc3 = Location.all
    desc1 = loc1.description ||= LocationDescription.create!(:location_id => loc1.id)
    desc2 = loc2.description ||= LocationDescription.create!(:location_id => loc2.id)
    desc3 = loc3.description ||= LocationDescription.create!(:location_id => loc3.id)
    desc1.add_editor(rolf) # Fails since he's already an author!
    desc2.add_editor(mary)
    desc3.add_editor(rolf)
    assert_query([desc3], :LocationDescription, :by_editor, :user => rolf, :by => :id)
    assert_query([desc2], :LocationDescription, :by_editor, :user => mary)
    assert_query([], :LocationDescription, :by_editor, :user => dick)
  end

  def test_name_advanced
    assert_query([38], :Name, :advanced_search, :name => 'macrocybe*titans')
    assert_query([2], :Name, :advanced_search, :location => 'glendale') # where
#    expect = Name.all(:conditions => 'observations.location_id = 2', # Rails 3
#                      :include => :observations, :order => 'text_name, author')
    expect = Name.where("observations.location_id" => 2).
                  includes(:observations).order("text_name, author").to_a
    assert_query(expect, :Name, :advanced_search, :location => 'burbank') # location
#    expect = Name.all(:conditions => 'observations.user_id = 1', # Rails 3
#                      :include => :observations, :order => 'text_name, author')
    expect = Name.where("observations.user_id" => 1).
                  includes(:observations).order("text_name, author").to_a
    assert_query(expect, :Name, :advanced_search, :user => 'rolf')
    assert_query([2], :Name, :advanced_search, :content => 'second fruiting') # notes
    assert_query([1], :Name, :advanced_search, :content => '"a little of everything"') # comment
  end

  def test_name_all
#    expect = Name.all(:order => 'sort_name') # Rails 3
    expect = Name.all.order("sort_name").to_a
    do_test_name_all(expect)
  rescue
    # Having problems with "Kuhner" and "Kühner" sorting correctly in all versions.
    pair = expect.select {|x| x.text_name == 'Lentinellus ursinus'}
    a = expect.index(pair.first)
    b = expect.index(pair.last)
    expect[a], expect[b] = expect[b], expect[a]
    do_test_name_all(expect)
  end

  def do_test_name_all(expect)
    expect_good = expect.reject(&:is_misspelling?)
    expect_bad  = expect.select(&:is_misspelling?)
    assert_query(expect_good, :Name, :all)
    assert_query(expect, :Name, :all, :misspellings => :either)
    assert_query(expect_good, :Name, :all, :misspellings => :no)
    assert_query(expect_bad, :Name, :all, :misspellings => :only)
  end

  def test_name_by_user
    assert_query([10,12], :Name, :by_user, :user => mary, :by => :id)
    assert_query([39,42,43,49], :Name, :by_user, :user => dick, :by => :id)
    assert_query(Name.all.map(&:id) - [10,12,39,41,42,43,44,49],
                          :Name, :by_user, :user => rolf, :by => :id)
    assert_query([], :Name, :by_user, :user => junk)
  end

  def test_name_by_editor
    assert_query([], :Name, :by_editor, :user => rolf, :by => :id)
    assert_query([], :Name, :by_editor, :user => mary, :by => :id)
    assert_query([40], :Name, :by_editor, :user => dick, :by => :id)
  end

  def test_name_by_rss_log
    assert_query([1], :Name, :by_rss_log)
  end

  def test_name_in_set
    assert_query([1,2,4,8,16], :Name, :in_set, :ids => [1,2,4,8,16])
  end

  def test_name_of_children
    expect = Name.where("text_name LIKE 'agaricus %'").order("text_name").to_a
    expect.reject!(&:is_misspelling?)
    assert_query(expect, :Name, :of_children, :name => names(:agaricus))
  end

  def test_name_of_parents
    fungi = names(:fungi)
    peltigera = names(:peltigera)
    agaricus = names(:agaricus)
    agaricus_campestris = names(:agaricus_campestris)
    assert_query([fungi], :Name, :of_parents, :name => peltigera)
    assert_query([], :Name, :of_parents, :name => agaricus)
    assert_query([agaricus], :Name, :of_parents, :name => agaricus_campestris)
  end

  def test_name_pattern
    assert_query([], :Name, :pattern_search, :pattern => 'petigera') # search_name
    assert_query([41], :Name, :pattern_search, :pattern => 'petigera', :misspellings => :either)
    # assert_query([40], :Name, :pattern_search, :pattern => 'ye auld manual of lichenes') # citation
    # assert_query([20], :Name, :pattern_search, :pattern => 'prevent me') # notes
    # assert_query([42], :Name, :pattern_search, :pattern => 'smell as sweet') # gen_desc
    # assert_query([40], :Name, :pattern_search, :pattern => 'superficially similar') # look_alikes
  end

  def test_name_with_descriptions
    assert_query([2,3,13,20,21,32,33,34,39,40,42], :Name, :with_descriptions, :by => :id)
  end

  def test_name_with_descriptions_by_user
    assert_query([3,40], :Name, :with_descriptions_by_user, :user => mary, :by => :id)
    assert_query([39,40,42], :Name, :with_descriptions_by_user, :user => dick, :by => :id)
  end

  def test_name_with_descriptions_by_author
    assert_query([2,40], :Name, :with_descriptions_by_author, :user => rolf, :by => :id)
    assert_query([3,40], :Name, :with_descriptions_by_author, :user => mary, :by => :id)
    assert_query([39], :Name, :with_descriptions_by_author, :user => dick, :by => :id)
  end

  def test_name_with_descriptions_by_editor
    assert_query([2], :Name, :with_descriptions_by_editor, :user => rolf)
    assert_query([2], :Name, :with_descriptions_by_editor, :user => mary)
    assert_query([], :Name, :with_descriptions_by_editor, :user => dick)
  end

  def test_name_with_observations
    expect = Observation.connection.select_values %(
      SELECT DISTINCT name_id FROM observations ORDER BY name_id ASC
    )
    assert_query(expect.map(&:to_i), :Name, :with_observations, :by => :id)
  end

  def test_name_with_observations_at_location
    assert_query([20, 3, 21, 19, 1], :Name, :with_observations_at_location, :location => 2)
  end

  def test_name_with_observations_at_where
    assert_query([2], :Name, :with_observations_at_where, :user_where => 'glendale', :location => 'glendale')
  end

  def test_name_with_observations_by_user
    assert_query([20, 3, 21, 19, 2, 40, 24], :Name, :with_observations_by_user, :user => rolf)
    assert_query([1], :Name, :with_observations_by_user, :user => mary)
    assert_query([], :Name, :with_observations_by_user, :user => dick)
  end

  def test_name_with_observations_in_set
    assert_query([20, 3, 1], :Name, :with_observations_in_set, :ids => [2,4,6])
  end

  def test_name_with_observations_in_species_list
    assert_query([1], :Name, :with_observations_in_species_list, :species_list => 3)
    assert_query([], :Name, :with_observations_in_species_list, :species_list => 1)
  end

  def test_name_description_all
    all = NameDescription.all.to_a
    assert_query(all, :NameDescription, :all, :by => :id)
  end

  def test_name_description_by_user
    assert_query([9, 13], :NameDescription, :by_user, :user => mary, :by => :id)
    assert_query([8, 11, 14], :NameDescription, :by_user, :user => katrina, :by => :id)
    assert_query([], :NameDescription, :by_user, :user => junk, :by => :id)
  end

  def test_name_description_by_author
    assert_query([12, 15], :NameDescription, :by_author, :user => rolf, :by => :id)
    assert_query([9, 13], :NameDescription, :by_author, :user => mary, :by => :id)
    assert_query([], :NameDescription, :by_author, :user => junk)
  end

  def test_name_description_by_editor
    assert_query([15], :NameDescription, :by_editor, :user => rolf)
    assert_query([15], :NameDescription, :by_editor, :user => mary)
    assert_query([], :NameDescription, :by_editor, :user => dick)
  end

  def test_observation_advanced
    assert_query([8], :Observation, :advanced_search, :name => 'diminutivus')
    assert_query([3], :Observation, :advanced_search, :location => 'glendale') # where
    expect = Observation.where(location_id: 2).to_a
    assert_query(expect, :Observation, :advanced_search, :location => 'burbank', :by => :id) # location
    expect = Observation.where(user_id: 1).to_a
    assert_query(expect, :Observation, :advanced_search, :user => 'rolf', :by => :id)
    assert_query([3], :Observation, :advanced_search, :content => 'second fruiting') # notes
    assert_query([1], :Observation, :advanced_search, :content => 'agaricus') # comment
  end

  def test_observation_all
    expect = Observation.all.order('`when` DESC, id DESC').to_a
    assert_query(expect, :Observation, :all)
  end

  def test_observation_at_location
    # expect = Observation.find_all_by_location_id(2, :include => :name, # Rails 3
    #   :order => 'names.text_name, names.author, observations.id DESC')
    expect = Observation.where(location_id: 2).includes(:name).
                         order("names.text_name, names.author,
                           observations.id DESC").to_a
    assert_query(expect, :Observation, :at_location, :location => 2)
  end

  def test_observation_at_where
    assert_query([3], :Observation, :at_where, :user_where => 'glendale', :location => 'glendale')
  end

  def test_observation_by_rss_log
    assert_query([2], :Observation, :by_rss_log)
  end

  def test_observation_by_user
    expect = Observation.where(user_id: rolf.id).to_a
    assert_query(expect, :Observation, :by_user, :user => rolf, :by => :id)
    expect = Observation.where(user_id: mary.id).to_a
    assert_query(expect, :Observation, :by_user, :user => mary, :by => :id)
    expect = Observation.where(user_id: dick.id).to_a
    assert_query(expect, :Observation, :by_user, :user => dick, :by => :id)
    expect = Observation.where(user_id: junk.id).to_a
    assert_query([], :Observation, :by_user, :user => junk, :by => :id)
  end

  def test_observation_in_set
    assert_query([9,1,8,2,7,3,6,4,5], :Observation, :in_set, :ids => [9,1,8,2,7,3,6,4,5])
  end

  def test_observation_in_species_list
    # These two are identical in everyway, so should be disambiguated by reverse_id.
    assert_query([2,1], :Observation, :in_species_list, :species_list => 3)
  end

  def test_observation_of_children
    assert_query([6,4,7,5], :Observation, :of_children, :name => names(:agaricus))
  end

  def test_observation_of_name
    User.current = rolf
    names = Name.where("text_name like 'Agaricus camp%'").to_a
    name = names.pop
    names.each {|n| name.merge_synonyms(n)}
    Observation.find(6).update_attribute(:user, mary)
    Observation.find(7).update_attribute(:user, mary)
    spl = SpeciesList.first
    spl.observations << Observation.find(5)
    spl.observations << Observation.find(7)
    proj = Project.first
    proj.observations << Observation.find(4)
    proj.observations << Observation.find(6)
    assert_query([10,9,2,1], :Observation, :of_name, :name => 1)
    assert_query([],  :Observation, :of_name, :name => 9)
    assert_query([4], :Observation, :of_name, :name => 3)
    assert_query([7,6,5],  :Observation, :of_name, :name => 3, :synonyms => :exclusive)
    assert_query([7,6,5,4], :Observation, :of_name, :name => 3, :synonyms => :all)
    assert_query([3], :Observation, :of_name, :name => 3, :nonconsensus => :exclusive)
    assert_query([4,3], :Observation, :of_name, :name => 3, :nonconsensus => :all)
    assert_query([5,4], :Observation, :of_name, :name => 3, :synonyms => :all, :user => 1)
    assert_query([7,6], :Observation, :of_name, :name => 3, :synonyms => :all, :user => 2)
    assert_query([7,5], :Observation, :of_name, :name => 3, :synonyms => :all, :species_list => 1)
    assert_query([6,4], :Observation, :of_name, :name => 3, :synonyms => :all, :project => 1)
  end

  def test_observation_pattern
    # notes
    assert_query([6,7,5,8], :Observation, :pattern_search,
                            pattern: '"somewhere else"', by: :name)
    # assert_query([1], :Observation, :pattern_search,
    #                   :pattern => 'wow!') # comment
    # where
    assert_query([8], :Observation, :pattern_search, pattern: "pipi valley")

    # location
    expect = Observation.where(location_id: 2).includes(:name).
                         order("names.text_name, names.author,
                                observations.id DESC").to_a
    assert_query(expect, :Observation, :pattern_search, pattern: "burbank",
                         by: :name)

    # name
    expect = Observation.where("text_name LIKE 'agaricus%'").includes(:name).
                         order("names.text_name, names.author,
                                observations.id DESC")
    assert_query(expect.map(&:id), :Observation, :pattern_search,
                                   pattern: "agaricus", by: :name)
  end

  def test_project_all
    assert_query([2,1], :Project, :all)
  end

  def test_project_in_set
    assert_query([1], :Project, :in_set, :ids => [1])
    assert_query([], :Project, :in_set, :ids => [])
  end

  def test_rsslog_all
#    ids = RssLog.find(:all).map {|log| log.id} # Rails 3
    ids = RssLog.all.map {|log| log.id}
    assert_query(ids, :RssLog, :all)
  end

  def test_rsslog_in_set
    assert_query([2,3], :RssLog, :in_set, :ids => [2,3])
  end

  def test_specieslist_all
#    expect = SpeciesList.all(:order => 'title') # Rails 3
    expect = SpeciesList.all.order("title").to_a
    assert_query(expect, :SpeciesList, :all)
  end

  def test_specieslist_by_rss_log
    assert_query([1], :SpeciesList, :by_rss_log)
  end

  def test_specieslist_by_user
    assert_query([1,2], :SpeciesList, :by_user, :user => rolf, :by => :id)
    assert_query([3], :SpeciesList, :by_user, :user => mary, :by => :id)
    assert_query([], :SpeciesList, :by_user, :user => dick)
  end

  def test_specieslist_in_set
    assert_query([1,3], :SpeciesList, :in_set, :ids => [1,3])
  end

  def test_user_all
#    expect = User.all(:order => 'name') # Rails 3
    expect = User.all.order("name").to_a
    assert_query(expect, :User, :all)
#    expect = User.all(:order => 'login') # Rails 3
    expect = User.all.order("login").to_a
    assert_query(expect, :User, :all, :by => :login)
  end

  def test_user_in_set
    assert_query([1,2,3], :User, :in_set, :ids => [3,2,1], :by => :reverse_name)
  end

  def test_whiny_nil_in_map_locations
    query = Query.lookup(:User, :in_set, :ids => [1,1000,2])
    query.query
    assert_equal(2, query.results.length)
  end

  def test_location_ordering
    loc1 = locations(:albion)
    loc2 = locations(:elgin_co)

    User.current = rolf
    assert_equal(:postal, User.current_location_format)
    assert_query([loc1, loc2], :Location, :in_set, :ids => [1, 6], :by => :name)

    User.current = roy
    assert_equal(:scientific, User.current_location_format)
    assert_query([loc2, loc1], :Location, :in_set, :ids => [1, 6], :by => :name)

    obs1 = Observation.find(1)
    obs2 = Observation.find(2)
    obs1.update_attribute(:location, loc1)
    obs2.update_attribute(:location, loc2)

    User.current = rolf
    assert_equal(:postal, User.current_location_format)
    assert_query([obs1, obs2], :Observation, :in_set, :ids => [1, 2], :by => :location)

    User.current = roy
    assert_equal(:scientific, User.current_location_format)
    assert_query([obs2, obs1], :Observation, :in_set, :ids => [1, 2], :by => :location)
  end
end
