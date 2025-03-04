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

  def newbie_collections
    [collection_numbers(:minimal_unknown_coll_num),
     collection_numbers(:detailed_unknown_coll_num_one)]
  end

  def test_collection_number_names
    expects = CollectionNumber.names("Mary Newbie").index_order
    assert_query(expects, :CollectionNumber, names: "Mary Newbie")
    expects = newbie_collections
    assert_query(expects, :CollectionNumber, names: "Mary Newbie")
  end

  def test_collection_number_name_has
    expects = CollectionNumber.name_has("Newbie").index_order
    assert_query(expects, :CollectionNumber, name_has: "Newbie")
    expects = newbie_collections
    assert_query(expects, :CollectionNumber, name_has: "Newbie")
  end

  def test_collection_number_numbers
    expects = CollectionNumber.numbers("07-123a").index_order
    assert_query(expects, :CollectionNumber, numbers: "07-123a")
  end

  def test_collection_number_number_has
    expects = CollectionNumber.number_has("n").index_order
    assert_query(expects, :CollectionNumber, number_has: "n")
    expects = [collection_numbers(:detailed_unknown_coll_num_two)]
    assert_query(expects, :CollectionNumber, number_has: "n")
  end

  def test_collection_number_for_observation
    obs = observations(:detailed_unknown_obs)
    expects = CollectionNumber.index_order.observations(obs)
    assert_query(expects, :CollectionNumber, observations: obs.id)
  end

  def test_collection_number_pattern_search
    expects = CollectionNumber.index_order.
              where(CollectionNumber[:name].matches("%Singer%").
                    or(CollectionNumber[:number].matches("%Singer%"))).
              sort_by(&:format_name)
    assert_query(expects, :CollectionNumber, pattern: "Singer")

    expects = CollectionNumber.pattern("Singer").index_order.
              sort_by(&:format_name)
    assert_query(expects, :CollectionNumber, pattern: "Singer")

    expects = CollectionNumber.index_order.
              where(CollectionNumber[:name].matches("%123a%").
                    or(CollectionNumber[:number].matches("%123a%"))).
              sort_by(&:format_name)
    assert_query(expects, :CollectionNumber, pattern: "123a")

    expects = CollectionNumber.pattern("123a").index_order.
              sort_by(&:format_name)
    assert_query(expects, :CollectionNumber, pattern: "123a")
  end
end
