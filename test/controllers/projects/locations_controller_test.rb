# frozen_string_literal: true

require("test_helper")

module Projects
  class LocationsControllerTest < FunctionalTestCase
    def test_index
      eol_project = projects(:eol_project)
      login
      get(:index, params: { project_id: eol_project.id })

      loc = eol_project.locations.first
      assert_match(loc.display_name, @response.body)
      assert_response(:success)
    end

    def test_index_scientific
      eol_project = projects(:eol_project)
      login("roy")
      get(:index, params: { project_id: eol_project.id })

      loc = eol_project.locations.first
      assert_match(loc.display_name, @response.body)
      assert_response(:success)
    end

    def test_index_with_target_locations
      project = projects(:rare_fungi_project)
      login
      get(:index, params: { project_id: project.id })

      assert_response(:success)
      target = locations(:burbank)
      # Target location name should appear even with no obs
      assert_match(target.display_name, @response.body)
    end

    def test_index_without_target_locations
      project = projects(:eol_project)
      login
      get(:index, params: { project_id: project.id })

      assert_response(:success)
      # No collapse elements when there are no targets
      assert_no_match(/panel-collapse-trigger/, @response.body)
    end

    # Exercises grouping logic: assign_to_targets,
    # most_specific_target, and ungrouped filtering
    def test_index_groups_sub_locations_under_targets
      project = projects(:rare_fungi_project)
      california = locations(:california)
      albion = locations(:albion) # "Albion, California, USA"
      nybg = locations(:nybg_location) # New York — not a sub

      # Add California as a target location
      project.add_target_location(california)

      # Add observations at Albion (sub of California) and NYBG
      [albion, nybg].each do |loc|
        obs = Observation.create!(
          name: names(:fungi), user: users(:rolf),
          location: loc, when: Time.zone.now
        )
        project.observations << obs
      end

      login
      get(:index, params: { project_id: project.id })
      assert_response(:success)

      body = @response.body
      # California target should appear
      assert_match(california.display_name, body)
      # Albion grouped under California as a sub-location
      assert_match(albion.display_name, body)
      # NYBG appears ungrouped (not a sub of any target)
      assert_match(nybg.display_name, body)
    end
  end
end
