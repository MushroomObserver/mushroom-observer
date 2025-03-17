# frozen_string_literal: true

require "test_helper"
require "query_extensions"

# tests of Query::CollectionNumbers class to be included in QueryTest
class Query::CollectionNumbersTest < UnitTestCase
  include QueryExtensions

  def test_collection_number_all
    expects = CollectionNumber.index_order
    assert_query(expects, :CollectionNumber)
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
