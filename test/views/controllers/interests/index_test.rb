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

    private

    def render_index(types:, selected_type:, interests: [])
      render(Index.new(
               interests: interests,
               types: types,
               selected_type: selected_type,
               pagination_data: PaginationData.new
             ))
    end
  end
end
