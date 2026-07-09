# frozen_string_literal: true

require("test_helper")

module Projects
  class LocationsControllerTest < FunctionalTestCase
    def test_index
      eol_project = projects(:eol_project)
      login
      get(:index, params: { project_id: eol_project.id })

      loc = eol_project.locations.first
      assert_select("#locations_table",
                    text: /#{Regexp.escape(loc.display_name)}/)
      assert_response(:success)
    end

    def test_index_scientific
      eol_project = projects(:eol_project)
      login("roy")
      get(:index, params: { project_id: eol_project.id })

      loc = eol_project.locations.first
      assert_select("#locations_table",
                    text: /#{Regexp.escape(loc.display_name)}/)
      assert_response(:success)
    end

    def test_index_with_target_locations
      project = projects(:rare_fungi_project)
      login
      get(:index, params: { project_id: project.id })

      assert_response(:success)
      target = locations(:burbank)
      # Target location name should appear even with no obs
      assert_select("#locations_table",
                    text: /#{Regexp.escape(target.display_name)}/)
    end

    def test_index_without_target_locations
      project = projects(:eol_project)
      login
      get(:index, params: { project_id: project.id })

      assert_response(:success)
      # No collapse elements when there are no targets. Scoped to
      # #locations_table — the sidebar's language toggle is also a
      # `.panel-collapse-trigger` and renders on every page.
      assert_select("#locations_table .panel-collapse-trigger", count: 0)
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

      # California target should appear
      assert_select("a", { text: california.display_name, minimum: 1 },
                    "California target should appear as a link")
      # Albion grouped under California as a sub-location
      assert_select("a", { text: albion.display_name, minimum: 1 },
                    "Albion should appear under California")
      # NYBG appears ungrouped (not a sub of any target)
      assert_select("a", { text: nybg.display_name, minimum: 1 },
                    "NYBG should appear ungrouped")
    end
  end
end
