# frozen_string_literal: true

require("test_helper")
require("query_extensions")

# tests of Query::Interests class to be included in QueryTest
class Query::InterestsTest < UnitTestCase
  include QueryExtensions

  def test_interests_default_order
    expects = Interest.order_by(:target_type)
    assert_query(expects, :Interest)
  end

  def test_interests_by_users
    expects = Interest.by_users(junk.id).order_by(:target_type)
    assert_query(expects, :Interest, by_users: junk.id)
  end

  def test_interests_types
    expects = [interests(:detailed_unknown_obs_interest)]
    scope = Interest.types(:observation)
    assert_query_scope(expects, scope, :Interest, types: :observation)
  end

  def test_interests_state
    all_watching = Interest.state(true).order_by(:target_type)
    assert_query(all_watching, :Interest, state: true)

    assert_query([], :Interest, state: false)
  end

  def test_interests_id_in_set
    set = [interests(:detailed_unknown_obs_interest).id,
           interests(:agaricus_campestros_interest).id]
    scope = Interest.id_in_set(set)
    assert_query_scope(set, scope, :Interest, id_in_set: set)
  end
end
