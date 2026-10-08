# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Locations
  class IndexTest < ComponentTestCase
    def setup
      super
      @user = users(:rolf)
      controller.instance_variable_set(:@user, @user)
      controller.define_singleton_method(:index_sort_options) { {} }
    end

    def test_renders_nothing_when_no_locations
      html = render_index(locations: [])

      assert_no_html(html, "button[data-controller='clipboard']")
    end

    def test_renders_known_locations_with_badge_link_and_count
      burbank = locations(:burbank)
      albion = locations(:albion)
      html = render_index(
        locations: [burbank, albion],
        observation_counts: { burbank.id => 3 }
      )

      assert_html(html, "button[data-controller='clipboard']",
                  text: burbank.id.to_s)
      assert_html(html, "button[data-controller='clipboard']",
                  text: albion.id.to_s)
      assert_includes(html, burbank.name.t.as_displayed)
      assert_includes(html, albion.name.t.as_displayed)
      assert_html(html, "a[href='#{routes.location_path(burbank.id)}']")
      # count defaults to 0 when the controller's observation_counts
      # hash has no entry for a given location.
      assert_includes(html, "(3)")
      assert_includes(html, "(0)")
    end

    private

    def render_index(locations: [], pagination_data: PaginationData.new,
                     observation_counts: {})
      idx = Index.new(
        query: Query.lookup_and_save(:Location),
        locations: locations,
        pagination_data: pagination_data,
        observation_counts: observation_counts
      )
      # Skip chrome registration — `Tab::Location::IndexActions` and
      # `add_sorter` need controller methods not available in component
      # test context.
      idx.define_singleton_method(:register_chrome) { nil }
      render(idx)
    end
  end
end
