# frozen_string_literal: true

require "test_helper"

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

  def test_deep_compact
    h = { a: 1, b: { d: nil, e: 2, f: { g: nil, h: nil } }, c: 3 }
    assert_equal({ a: 1, b: { e: 2, f: {} }, c: 3 }, h.deep_compact)
  end

  def test_deep_compact_blank
    h = { a: 1, b: { d: nil, e: false, f: { g: nil, h: false } }, c: 3, i: [] }
    assert_equal({ a: 1, c: 3 }, h.deep_compact_blank)
  end
end
