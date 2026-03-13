# frozen_string_literal: true

require("test_helper")
require("query_extensions")

# tests of Query::Users class to be included in QueryTest
class Query::UsersTest < UnitTestCase
  include QueryExtensions

  def test_user_all_by_name
    expects = User.order_by(:name)
    assert_query(expects, :User, order_by: :name)
  end

  def test_user_order_by_login
    expects = User.order_by(:login)
    assert_query(expects, :User, order_by: :login)
  end

  def test_user_order_by_contribution
    expects = User.order_by(:contribution)
    assert_query(expects, :User)
  end

  def test_user_order_by_last_login
    expects = User.order_by(:last_login)
    assert_query(expects, :User, order_by: :last_login)
  end

  def test_user_id_in_set
    ids = [rolf.id, mary.id, junk.id]
    scope = User.id_in_set(ids)
    assert_query_scope(ids, scope, :User, id_in_set: ids)
  end

  def test_user_has_contribution
    expects = User.has_contribution.order_by_default
    assert_query(expects, :User, has_contribution: true)
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
    assert_query(User.order(contribution: :desc, id: :desc).to_a,
                 :User, pattern: "")
  end

  def test_user_pattern_search_sorted_by_location
    # sorted by location should include Users without location
    # (Differs from searches on other Classes or by other sort orders)
    expects = User.left_outer_joins(:location).
              order(Location[:name].asc, User[:id].desc).uniq
    scope = User.pattern("").order_by(:location)
    assert_query_scope(expects, scope, :User, pattern: "", order_by: :location)
  end

  def user_pattern_search(pattern)
    User.pattern(pattern)
  end
end
