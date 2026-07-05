# frozen_string_literal: true

require("test_helper")

module Observations
  class LocationsControllerTest < FunctionalTestCase
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

      # Case seen in the wild that causes error
      requires_login(:edit, where: "")
      assert(assigns(:matches).include?(albion))

      # Another case that caused an error
      requires_login(:edit, where: "CA")
      assert(assigns(:matches).include?(albion))
    end

    def test_add_to_location
      # User.current = rolf
      albion = locations(:albion)
      obs = Observation.create!(
        user: rolf,
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
        user: roy,
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

    # `update`'s `where = params[:where].strip_squeeze rescue ""`:
    # when `:where` is absent, `nil.strip_squeeze` raises
    # `NoMethodError`, rescued to `""`. `where.present?` is then
    # false, so no merge is attempted and no flash is set.
    def test_update_missing_where_param
      albion = locations(:albion)

      put_requires_login(:update, { location: albion.id })

      assert_redirected_to(locations_path)
      assert_no_flash
    end

    # `update_observations_by_where`'s `next if o.save` failure
    # branch: flashes an error (naming the observation via
    # `viewer_aware_unique_format_name`) and marks the merge
    # unsuccessful. Stub `Observation.where` to return our own
    # instance so we can force `#save` to fail on it.
    def test_update_flash_error_when_save_fails
      albion = locations(:albion)
      obs = Observation.create!(
        user: rolf,
        when: Time.zone.now,
        where: "flaky undefined location",
        notes: "flaky obs"
      )

      obs.stub(:save, false) do
        Observation.stub(:where, [obs]) do
          put_requires_login(:update,
                             { where: obs.where, location: albion.id })
        end
      end

      assert_redirected_to(locations_path)
      assert_flash_error
    end
  end
end
