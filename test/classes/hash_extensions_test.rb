# frozen_string_literal: true

require("test_helper")

# test MO extensions to Ruby's Hash class
class HashExtensionsTest < UnitTestCase
  def test_flatten
    assert_equal({ id: 5, q: 123 },
                 { id: 5, params: { q: 123 } }.flatten)
    assert_equal({}, {}.flatten)
  end

  def test_remove_nils!
    h = { a: 1, b: nil, c: 3 }
    assert_equal({ a: 1, c: 3 }, h.remove_nils!)
  end
end
