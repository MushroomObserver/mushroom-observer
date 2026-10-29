# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Interests
  class IndexTest < ComponentTestCase
    def setup
      super
      controller.instance_variable_set(:@user, users(:rolf))
    end

    # When `selected_type:` is set, the filter pill strip renders.
    # The active pill is a plain `<span>` (no link); inactive pills
    # wrap a `link_to` inside a `<span>`.
    def test_filter_pills_render_with_active_and_inactive_pills
      html = render_index(
        types: %w[Observation Name],
        selected_type: "Observation"
      )

      # Inactive pill links to the Name filter URL
      assert_html(html, "a[href*='type=Name']")
      # Active pill has no link for the selected type
      assert_no_html(html, "a[href*='type=Observation']")
    end

    def test_filter_shows_all_types_link
      html = render_index(
        types: ["Observation"],
        selected_type: "Observation"
      )

      # The "All" pill links to the interests index without a type param
      assert_html(html, "a[href*='/interests']")
      assert_no_html(html, "a[href*='type=']")
    end

    def test_type_filter_hidden_when_single_type_and_no_selection
      html = render_index(types: ["Observation"], selected_type: nil)

      # `show_type_filter?` requires selection OR multi-type with >1 total
      assert_no_html(html, "a[href*='type=']")
    end

    # Was Interest#summary -- moved here (#4901) since its only
    # caller was this render.
    def test_summary_column_for_non_name_tracker_target
      interest = interests(:detailed_unknown_obs_interest)
      html = render_index(types: ["Observation"], selected_type: nil,
                          interests: [interest])

      expected = "#{:watching.ti} #{:observation.l}: " \
                 "#{interest.target_format_name}"
      assert_html(html, "table strong", text: expected.t.as_displayed)
    end

    # NameTracker#summary itself is unchanged (stays on the model --
    # it has a second, non-render caller), just confirming the render
    # still dispatches to it correctly.
    def test_summary_column_for_name_tracker_target
      interest = interests(:coprinus_comatus_name_tracker_interest)
      html = render_index(types: ["NameTracker"], selected_type: nil,
                          interests: [interest])

      assert_html(html, "table strong",
                  text: interest.target.summary.t.as_displayed)
    end

    # When `selected_state:` is set, the state-filter strip renders
    # alongside the type filter.
    def test_state_filter_renders_with_active_and_inactive_items
      html = render_index(
        types: ["Observation"], selected_type: nil,
        states: %w[Watching Ignoring], selected_state: "Watching"
      )

      assert_html(html, "a[href*='state=Ignoring']")
      assert_no_html(html, "a[href*='state=Watching']")
    end

    def test_state_filter_hidden_when_single_state_present
      html = render_index(
        types: ["Observation"], selected_type: nil,
        states: ["Watching"], selected_state: nil
      )

      assert_no_html(html, "a[href*='state=']")
    end

    private

    def render_index(types:, selected_type:, interests: [],
                     states: [], selected_state: nil)
      render(Index.new(
               interests: interests,
               types: types,
               selected_type: selected_type,
               states: states,
               selected_state: selected_state,
               pagination_data: PaginationData.new,
               query: Query.lookup(:Interest, by_users: [users(:rolf).id])
             ))
    end
  end
end
