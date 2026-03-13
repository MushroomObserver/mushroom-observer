# frozen_string_literal: true

require("test_helper")

class BoxTest < UnitTestCase
  def valid_args
    { north: 10, south: -10, east: 10, west: -10 }
  end

  def test_valid
    assert(Mappable::Box.new(**valid_args).valid?)
    assert(Mappable::Box.new(**valid_args,  east: -10, west: 10).
           valid?)
    # Box 370 degrees wide & wraps around date line
    assert(Mappable::Box.new(**valid_args,  west: 20).valid?)

    assert_not(Mappable::Box.new(**valid_args,  north: nil).valid?,
               "Box missing north should be invalid")
    assert_not(Mappable::Box.new(**valid_args,  south: nil).valid?,
               "Box missing west should be invalid")
    assert_not(Mappable::Box.new(**valid_args,  east: nil).valid?,
               "Box missing east should be invalid")
    assert_not(Mappable::Box.new(**valid_args,  west: nil).valid?,
               "Box missing west should be invalid")

    assert_not(Mappable::Box.new(**valid_args,  north: 91).valid?,
               "Box with out of bounds north should be invalid")
    assert_not(Mappable::Box.new(**valid_args,  south: -91).valid?,
               "Box with out of bounds south should be invalid")
    assert_not(Mappable::Box.new(**valid_args,  east: 181).valid?,
               "Box with out of bounds east should be invalid")
    assert_not(Mappable::Box.new(**valid_args,  west: -181).valid?,
               "Box with out of bound west should be invalid")

    assert_not(Mappable::Box.new(**valid_args,  south: 20).valid?,
               "Box with south > north should be invalid")
  end

  def test_straddle_dateline
    assert(Mappable::Box.new(**valid_args,  east: -10, west: 10).
           straddles_180_deg?)
    assert(Mappable::Box.new(**valid_args,  west: 20).
           straddles_180_deg?)
    assert_not(Mappable::Box.new(**valid_args).straddles_180_deg?)
  end

  def test_expand
    box = Mappable::Box.new(**valid_args)
    expanded_box = box.expand(MO.box_epsilon)

    assert_operator(expanded_box.north, :>, box.north)
    assert_operator(expanded_box.south, :<, box.south)
    assert_operator(expanded_box.east, :>, box.east)
    assert_operator(expanded_box.west, :<, box.west)
  end
end
