# frozen_string_literal: true

require("test_helper")

# helpers for QueryTest and subclass tests
module QueryExtensions
  def assert_query(expects, *args)
    test_ids = expects.first.is_a?(Integer)
    expects = expects.to_a unless expects.respond_to?(:map!)
    query = Query.lookup(*args)
    actual = test_ids ? query.result_ids : query.results
    msg = "Query results are wrong. SQL is:\n#{query.last_query}"
    if test_ids
      assert_equal(expects, actual, msg)
    else
      assert_obj_arrays_equal(expects, actual, msg)
    end
    type = args[0].to_s.underscore.to_sym.t.titleize.sub(/um$/, "(um|a)")
    assert_match(/#{type}|Advanced Search|(Lower|Higher) Taxa/, query.title)
    assert_not(query.title.include?("[:"),
               "Title contains undefined localizations: <#{query.title}>")
  end

  # Assert that explicit results, scope and query agree
  def assert_query_scope(expects, scope_expects, *args)
    test_ids = expects.first.is_a?(Integer)
    expects = expects.to_a unless expects.respond_to?(:map!)
    query = Query.lookup(*args)
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
    type = args[0].to_s.underscore.to_sym.t.titleize.sub(/um$/, "(um|a)")
    assert_match(/#{type}|Advanced Search|(Lower|Higher) Taxa/, query.title)
    assert_not(query.title.include?("[:"),
               "Title contains undefined localizations: <#{query.title}>")
  end

  def clean(str)
    str.gsub(/\s+/, " ").strip
  end
end
