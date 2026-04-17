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
      # Albion is a non-target observed location
      html = render_table(
        user: users(:rolf),
        ungrouped: [locations(:albion)]
      )

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

    def test_chevron_shown_for_target_with_sub_locations
      burbank = locations(:burbank)
      albion = locations(:albion)
      grouped = [{ target: burbank, sub_locations: [albion] }]
      html = render_table(
        user: users(:rolf),
        grouped: grouped,
        obs_counts: { burbank.id => 2, albion.id => 3 }
      )

      # Chevron trigger present
      assert_html(html, ".panel-collapse-trigger")
      # Collapse target for sub-locations
      assert_html(html, "#target_subs_#{burbank.id}")
      # Aggregated count: 2 + 3 = 5
      assert_includes(html, "5")
    end

    def test_no_chevron_for_target_without_sub_locations
      html = render_table(user: users(:rolf))

      assert_no_html(html, ".panel-collapse-trigger")
    end

    private

    def project
      projects(:rare_fungi_project)
    end

    def render_table(user:, grouped: nil, ungrouped: [],
                     obs_counts: {})
      grouped ||= default_grouped_data
      render(Components::Projects::LocationsTable.new(
               project: project,
               grouped_data: grouped,
               ungrouped_locations: ungrouped,
               obs_counts: obs_counts,
               user: user
             ))
    end

    def default_grouped_data
      burbank = locations(:burbank)
      [{ target: burbank, sub_locations: [] }]
    end
  end
end
