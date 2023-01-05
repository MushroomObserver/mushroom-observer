# frozen_string_literal: true

require("test_helper")
require("set")

module Locations::Descriptions
  class MergesControllerTest < FunctionalTestCase
    include ObjectLinkHelper

  def test_list_merge_options
    albion = locations(:albion)

    # Full match with albion.
    requires_login(:list_merge_options, where: albion.display_name)
    assert_obj_arrays_equal([albion], assigns(:matches))

    # Should match against albion.
    requires_login(:list_merge_options, where: "Albion, CA")
    assert_obj_arrays_equal([albion], assigns(:matches))

    # Should match against albion.
    requires_login(:list_merge_options, where: "Albion Field Station, CA")
    assert_obj_arrays_equal([albion], assigns(:matches))

    # Shouldn't match anything.
    requires_login(:list_merge_options, where: "Somewhere out there")
    assert_nil(assigns(:matches))
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
    requires_login(:add_to_location, params)
    assert_redirected_to(action: :list_locations)
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
    requires_login(:add_to_location, params, "roy")
    assert_redirected_to(action: :list_locations)
    assert_not_nil(obs.reload.location)
    assert_equal(albion, obs.location)
  end
  end
end
