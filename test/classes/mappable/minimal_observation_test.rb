# frozen_string_literal: true

require("test_helper")

class Mappable::MinimalObservationTest < UnitTestCase
  def test_valid_with_a_real_location
    mo = Mappable::MinimalObservation.new(
      lat: 40, lng: -70, location: locations(:albion)
    )
    assert(mo.valid?)
  end

  def test_invalid_when_location_is_not_a_location
    # The custom `location=` setter needs something that responds to
    # `#id` to avoid crashing outright, so assign a same-shaped but
    # wrong-type record to reach the type-check validation itself.
    mo = Mappable::MinimalObservation.new(
      lat: 40, lng: -70, location: users(:rolf)
    )
    assert_not(mo.valid?)
  end
end
