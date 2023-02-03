# frozen_string_literal: true

require("test_helper")

class RegexpExtensionsTest < UnitTestCase
  def test_escape_except_spaces
    assert_equal(" ", Regexp.escape_except_spaces(" "))
  end
end
