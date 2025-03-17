# frozen_string_literal: true

require("test_helper")

# helpers for QueryTest and subclass tests
module QueryExtensions
  def assert_query(expects, *)
    test_ids = expects.first.is_a?(Integer)
    expects = [expects].flatten
    query = Query.lookup(*)
    actual = test_ids ? query.result_ids : query.results
    msg = "Query results are wrong. SQL is:\n#{query.last_query}"
    if test_ids
      assert_equal(expects, actual, msg)
    else
      assert_obj_arrays_equal(expects, actual, msg)
    end
  end

  # Assert that explicit results, scope and query agree
  def assert_query_scope(expects, scope_expects, *)
    test_ids = expects.first.is_a?(Integer)
    expects = [expects].flatten
    scope_expects = scope_expects.pluck(:id) if test_ids
    query = Query.lookup(*)
    actual = test_ids ? query.result_ids : query.results
    msg1 = "Scope does not produce expects"
    msg2 = "Query results are wrong. SQL is:\n#{query.last_query}"
    msg3 = "Scope and Query do not agree. SQL is:\n#{query.last_query}"
    if test_ids
      assert_equal(expects, scope_expects, msg1)
      assert_equal(expects, actual, msg2)
      assert_equal(scope_expects, actual, msg3)
    else
      assert_obj_arrays_equal(expects, scope_expects, msg1)
      assert_obj_arrays_equal(expects, actual, msg2)
      assert_obj_arrays_equal(scope_expects, actual, msg3)
    end
  end

  def clean(str)
    str.gsub(/\s+/, " ").strip
  end
end
