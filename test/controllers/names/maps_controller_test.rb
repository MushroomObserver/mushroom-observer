# frozen_string_literal: true

require("test_helper")
require("set")

module Names
  class MapsControllerTest < FunctionalTestCase
    include ObjectLinkHelper
    # ----------------------------
    #  Maps
    # ----------------------------

    # name with Observations that have Locations
    def test_map
      login
      get(:show, params: { id: names(:agaricus_campestris).id })
      assert_template("names/maps/show")
    end

    # name with Observations that don't have Locations
    def test_map_no_loc
      login
      get(:show, params: { id: names(:coprinus_comatus).id })
      assert_template("names/maps/show")
    end

    # name with no Observations
    def test_map_no_obs
      login
      get(:show, params: { id: names(:conocybe_filaris).id })
      assert_template("names/maps/show")
    end
  end
end
