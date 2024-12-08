# frozen_string_literal: true

require("test_helper")

module Observations
  class LocationsControllerTest < FunctionalTestCase
    include ObjectLinkHelper

    def test_define_location_options
      albion = locations(:albion)

      # Full match with "Albion, California, USA" should come first
      requires_login(:edit, where: albion.display_name)
      assert_equal(albion, assigns(:matches).first)

      # Should match against albion.
      requires_login(:edit, where: "Albion, CA")
      assert(assigns(:matches).include?(albion))

      # Should match against albion.
      requires_login(:edit, where: "Albion Field Station, CA")
      assert(assigns(:matches).include?(albion))

      # Shouldn't match anything.
      requires_login(:edit, where: "Somewhere out there")
      assert_empty(assigns(:matches))
    end

    def test_add_to_location
      User.current = rolf
      albion = locations(:albion)
      obs = Observation.create!(
        when: Time.zone.now,
        where: "undefined location",
        notes: "new observation"
      )
      assert_nil(obs.location)

      params = {
        where: obs.where,
        location: albion.id
      }
      put_requires_login(:update, params)
      assert_redirected_to(locations_path)
      assert_not_nil(obs.reload.location)
      assert_equal(albion, obs.location)
    end

    def test_add_to_location_scientific
      login("roy")
      albion = locations(:albion)
      obs = Observation.create!(
        when: Time.zone.now,
        where: (where = "Albion, Mendocino Co., California, USA"),
        notes: "new observation"
      )
      assert_nil(obs.location)
      assert_equal("scientific", roy.location_format)
      params = {
        where: where,
        location: albion.id
      }
      put_requires_login(:update, params, "roy")
      assert_redirected_to(locations_path)
      assert_not_nil(obs.reload.location)
      assert_equal(albion, obs.location)
    end
  end
end
