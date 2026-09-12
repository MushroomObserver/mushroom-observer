# frozen_string_literal: true

require("test_helper")

class ScalarParamsTest < UnitTestCase
  include ScalarParams

  def test_safe_integer
    assert_equal(42, safe_integer("42"))
    assert_equal(42, safe_integer(42))
    assert_nil(safe_integer(nil))
    # Non-numeric String: Integer() raises, safe_integer rescues to nil
    # rather than crashing at the request boundary.
    assert_nil(safe_integer("abc"))
    # Anything that isn't a String or Integer (e.g. a nested-hash
    # attack shape) is filtered out before Integer() is ever called.
    assert_nil(safe_integer(ActionController::Parameters.new(foo: "bar")))
  end
end
