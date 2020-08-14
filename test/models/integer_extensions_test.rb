# frozen_string_literal: true

require("test_helper")

# Test MO extensions to Ruby Integer class
class IntegerExtensionsTest < UnitTestCase
  def test_convert_decimal_to_base62
    assert_equal("0", 0.alphabetize)
    assert_equal("g", 42.alphabetize)
    assert_equal("8M0kX", 123_456_789.alphabetize)
  end

  def test_alphabetize_decimal_to_hex
    assert_equal("0", 0.alphabetize("0123456789ABCDEF"))
    assert_equal("2A", 42.alphabetize("0123456789ABCDEF"))
    assert_equal("75BCD15", 123_456_789.alphabetize("0123456789ABCDEF"))
  end
end
