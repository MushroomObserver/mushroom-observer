# frozen_string_literal: true

require("test_helper")

class LiteralIDCoercionTest < UnitTestCase
  def test_to_id
    assert_equal(42, LiteralIDCoercion::TO_ID.call("42"))
    assert_nil(LiteralIDCoercion::TO_ID.call(nil))
    assert_nil(LiteralIDCoercion::TO_ID.call(""))
    assert_raises(ArgumentError) { LiteralIDCoercion::TO_ID.call("abc") }
  end

  def test_to_id_array
    assert_equal([1, 3],
                 LiteralIDCoercion::TO_ID_ARRAY.call(["1", "", "3"]))
    assert_nil(LiteralIDCoercion::TO_ID_ARRAY.call(nil))
  end

  # Regression: a request omitting the `[]` suffix (`?key=5` instead of
  # `?key[]=5`) hands Rack a bare String instead of an Array. Used to
  # raise NoMethodError on `.compact_blank` -- Copilot flagged this on
  # PR #5051 as a "suppressed" (low-confidence but valid) finding.
  def test_to_id_array_with_non_array_input
    assert_nil(LiteralIDCoercion::TO_ID_ARRAY.call("5"))
    assert_nil(LiteralIDCoercion::TO_ID_ARRAY.call(
                 ActionController::Parameters.new(foo: "bar")
               ))
  end
end
