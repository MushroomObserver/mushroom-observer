# frozen_string_literal: true

require("test_helper")

class BoxTest < UnitTestCase
  def test_valid
    valid_args = { n: 10, s: -10, e: 10, w: -10 }
    assert(Box.new(**valid_args).valid?)
    assert(Box.new(**valid_args.merge({ e: -10, w: 10 })).valid?)

    assert_not(Box.new(**valid_args.merge({ n: nil })).valid?,
               "Box missing n should be invalid")
    assert_not(Box.new(**valid_args.merge({ s: nil })).valid?,
               "Box missing w should be invalid")
    assert_not(Box.new(**valid_args.merge({ e: nil })).valid?,
               "Box missing e should be invalid")
    assert_not(Box.new(**valid_args.merge({ w: nil })).valid?,
               "Box missing w should be invalid")

    assert_not(Box.new(**valid_args.merge({ n: 91 })).valid?,
               "Box with out of bounds n should be invalid")
    assert_not(Box.new(**valid_args.merge({ s: -91 })).valid?,
               "Box with out of bounds s should be invalid")
    assert_not(Box.new(**valid_args.merge({ e: 181 })).valid?,
               "Box with out of bounds e should be invalid")
    assert_not(Box.new(**valid_args.merge({ w: -181 })).valid?,
               "Box with out of bound w should be invalid")

    assert_not(Box.new(**valid_args.merge({ s: 20 })).valid?,
               "Box with s > n should be invalid")
    assert_not(Box.new(**valid_args.merge({ w: 20 })).valid?,
               "Box with w > e and not straddling dateline should be invalid")
  end

  def test_straddle_dateline
    assert(Box.new(n: 10, s: -10, e: -10, w: 10).straddles_180_deg?)
    assert_not(Box.new(n: 10, s: -10, e: 10, w: -10).straddles_180_deg?)
    assert_not(Box.new(n: 10, s: -10, e: 10, w: 20).straddles_180_deg?)
  end
end
