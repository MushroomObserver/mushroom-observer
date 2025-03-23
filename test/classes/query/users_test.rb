# frozen_string_literal: true

require("test_helper")
require("query_extensions")

# tests of Query::Users class to be included in QueryTest
class Query::UsersTest < UnitTestCase
  include QueryExtensions

  def test_user_all_by_name
    expects = User.order(name: :asc, id: :desc).to_a
    assert_query(expects, :User)
  end

  def test_user_all_by_login
    expects = User.order(login: :asc, id: :desc).to_a
    assert_query(expects, :User, order_by: :login)
  end

  def test_user_id_in_set
    ids = [rolf.id, mary.id, junk.id]
    scope = User.id_in_set(ids)
    assert_query_scope(ids, scope,
                       :User, id_in_set: ids.reverse, order_by: :reverse_name)
  end

  def test_user_pattern_search_nonexistent
    assert_query([], :User, pattern: "nonexistent pattern")
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
    assert_query(expects, :User, pattern: "", order_by: "location")
  end

  def user_pattern_search(pattern)
    User.pattern(pattern)
  end
end
