# frozen_string_literal: true

require("test_helper")

module Locations
  class MergesControllerTest < FunctionalTestCase
    include ObjectLinkHelper

    def test_location_merge_options
      albion = locations(:albion)

      # Full match with "Albion, California, USA"
      requires_login(:new, where: albion.display_name)
      assert_obj_arrays_equal([albion], assigns(:matches))

      # Should match against albion.
      requires_login(:new, where: "Albion, CA")
      assert_obj_arrays_equal([albion], assigns(:others))

      # Should match against albion.
      requires_login(:new, where: "Albion Field Station, CA")
      assert_obj_arrays_equal([albion], assigns(:others))

      # Shouldn't match anything.
      requires_login(:new, where: "Somewhere out there")
      assert_obj_arrays_equal([], assigns(:others))
    end
  end
end
