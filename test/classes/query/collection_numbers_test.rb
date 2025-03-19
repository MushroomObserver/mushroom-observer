# frozen_string_literal: true

require("test_helper")
require("query_extensions")

# tests of Query::CollectionNumbers class to be included in QueryTest
class Query::CollectionNumbersTest < UnitTestCase
  include QueryExtensions

  def test_collection_number_all
    expects = CollectionNumber.index_order
    assert_query(expects, :CollectionNumber)
  end

  def test_collection_number_created_at_range
    expects = [collection_numbers(:minimal_unknown_coll_num)]
    early = "2005-01-01"
    late = "2005-12-31"
    scope = CollectionNumber.created_at(early, late)
    assert_query_scope(expects, scope,
                       :CollectionNumber, created_at: [early, late])
    # check that scope tolerates an array at first position
    scope = CollectionNumber.created_at([early, late])
    assert_query_scope(expects, scope,
                       :CollectionNumber, created_at: [early, late])
  end

  def test_collection_number_created_after_date
    expects = [collection_numbers(:coprinus_comatus_coll_num)]
    date = "2012-01-01"
    scope = CollectionNumber.created_at(date)
    assert_query_scope(expects, scope, :CollectionNumber, created_at: date)
  end

  def test_collection_number_created_on_date
    expects = [collection_numbers(:coprinus_comatus_coll_num)]
    early = "2012-12-08"
    late = "2012-12-08"
    scope = CollectionNumber.created_at(early, late)
    assert_query_scope(expects, scope,
                       :CollectionNumber, created_at: [early, late])
    # check that scope tolerates an array at first position
    scope = CollectionNumber.created_at([early, late])
    assert_query_scope(expects, scope,
                       :CollectionNumber, created_at: [early, late])
  end

  def test_collection_number_created_at_datetime
    expects = [collection_numbers(:coprinus_comatus_coll_num)]
    early = "2012-12-08-14-23-00"
    late = "2012-12-08-14-23-00"
    scope = CollectionNumber.created_at(early, late)
    assert_query_scope(expects, scope,
                       :CollectionNumber, created_at: [early, late])
    # check that scope tolerates an array at first position
    scope = CollectionNumber.created_at([early, late])
    assert_query_scope(expects, scope,
                       :CollectionNumber, created_at: [early, late])
  end

  def test_collection_number_id_in_set
    set = CollectionNumber.order(id: :asc).last(3).pluck(:id)
    scope = CollectionNumber.id_in_set(set)
    assert_query_scope(set, scope, :CollectionNumber, id_in_set: set)
  end

  def newbie_collections
    [collection_numbers(:minimal_unknown_coll_num),
     collection_numbers(:detailed_unknown_coll_num_one)]
  end

  def test_collection_number_by_users
    expects = newbie_collections <<
              collection_numbers(:detailed_unknown_coll_num_two)
    scope = CollectionNumber.by_users(mary).index_order
    assert_query_scope(expects, scope, :CollectionNumber, by_users: mary)
  end

  def test_collection_number_collectors
    expects = newbie_collections
    scope = CollectionNumber.collectors("Mary Newbie").index_order
    assert_query_scope(expects, scope,
                       :CollectionNumber, collectors: "Mary Newbie")
  end

  def test_collection_number_collector_has
    expects = newbie_collections
    scope = CollectionNumber.collector_has("Newbie").index_order
    assert_query_scope(expects, scope,
                       :CollectionNumber, collector_has: "Newbie")
  end

  def test_collection_number_numbers
    expects = [collection_numbers(:agaricus_campestris_coll_num)]
    scope = CollectionNumber.numbers("07-123a").index_order
    assert_query_scope(expects, scope, :CollectionNumber, numbers: "07-123a")
    expects = [collection_numbers(:minimal_unknown_coll_num),
               collection_numbers(:detailed_unknown_coll_num_one)]
    scope = CollectionNumber.numbers(%w[173 174]).index_order
    assert_query_scope(expects, scope, :CollectionNumber, numbers: %w[173 174])
  end

  def test_collection_number_number_has
    expects = [collection_numbers(:detailed_unknown_coll_num_two)]
    scope = CollectionNumber.number_has("n").index_order
    assert_query_scope(expects, scope, :CollectionNumber, number_has: "n")
  end

  def test_collection_number_observations
    obs = observations(:detailed_unknown_obs)
    expects = CollectionNumber.index_order.observations(obs)
    assert_query(expects, :CollectionNumber, observations: obs.id)
  end

  def test_collection_number_pattern_search
    expects = [collection_numbers(:agaricus_campestris_coll_num),
               collection_numbers(:coprinus_comatus_coll_num)]
    scope = CollectionNumber.pattern("Singer").sort_by(&:format_name)
    assert_query_scope(expects, scope, :CollectionNumber, pattern: "Singer")

    expects = [collection_numbers(:agaricus_campestris_coll_num)]
    scope = CollectionNumber.pattern("123a").sort_by(&:format_name)
    assert_query_scope(expects, scope, :CollectionNumber, pattern: "123a")
  end
end
