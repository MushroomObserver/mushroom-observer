# frozen_string_literal: true

require("test_helper")

module Projects
  class LocationsTableTest < ComponentTestCase
    def test_renders_table_with_locations
      html = render_table(user: users(:rolf))

      assert_html(html, "#locations_table")
      assert_html(html, "table.table")
      assert_includes(html, :LOCATION.l)
      assert_includes(html, :PROJECT_ALIASES.l)
      # Burbank is a target location
      assert_includes(html, locations(:burbank).display_name)
    end

    def test_admin_sees_target_column_and_remove_button
      html = render_table(user: users(:rolf))

      assert_includes(html, :project_target_locations_title.l)
      # Burbank is a target, should have remove button
      assert_html(html, "form[action*='target_location']")
      assert_html(html, ".glyphicon-remove")
    end

    def test_non_admin_sees_no_target_column
      html = render_table(user: users(:mary))

      assert_not_includes(html, :project_target_locations_title.l)
      assert_no_html(html, "form[action*='target_location']")
    end

    def test_non_target_location_has_no_remove_button
      # Add albion as a non-target observed location
      project.add_observation(observations(:minimal_unknown_obs))
      locs = [locations(:burbank), locations(:albion)]
      html = render_table(user: users(:rolf), locations: locs)

      # Burbank (target) should have remove button
      burbank_id = locations(:burbank).id
      assert_html(
        html,
        "form[action*='target_location'][action*='#{burbank_id}']"
      )
      # Albion (not a target) should not
      albion_id = locations(:albion).id
      assert_no_html(
        html,
        "form[action*='target_location'][action*='#{albion_id}']"
      )
    end

    private

    def project
      projects(:rare_fungi_project)
    end

    def render_table(user:, locations: [locations(:burbank)])
      render(Components::Projects::LocationsTable.new(
               project: project, locations: locations, user: user
             ))
    end
  end
end
