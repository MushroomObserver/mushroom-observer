# frozen_string_literal: true

require("test_helper")

module Locations
  class ReverseNameOrderControllerTest < FunctionalTestCase
    # This is just a callback, so it can only test result
    def test_reverse_name_order
      login
      mit = locations(:mitrula_marsh)
      mit_original_name = mit.name
      # this should reverse the name
      put(:update, params: { id: mit.id })
      assert_redirected_to(location_path(mit.id))
      assert_equal(Location.reverse_name(mit_original_name), mit.reload.name)
    end
  end
end
