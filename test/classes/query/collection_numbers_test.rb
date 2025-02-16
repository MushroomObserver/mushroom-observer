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

  def test_collection_number_for_observation
    obs = observations(:detailed_unknown_obs)
    expects = CollectionNumber.index_order.for_observation(obs)
    assert_query(expects, :CollectionNumber, observation: obs.id)
  end

  def test_collection_number_pattern_search
    expects = CollectionNumber.index_order.
              where(CollectionNumber[:name].matches("%Singer%").
                    or(CollectionNumber[:number].matches("%Singer%"))).
              sort_by(&:format_name)
    assert_query(expects, :CollectionNumber, pattern: "Singer")

    expects = CollectionNumber.index_order.
              where(CollectionNumber[:name].matches("%123a%").
                    or(CollectionNumber[:number].matches("%123a%"))).
              sort_by(&:format_name)
    assert_query(expects, :CollectionNumber, pattern: "123a")
  end
end
