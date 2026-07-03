# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Locations
  # Tests for the Locations index view. Focus: the `default_orders: true`
  # branch of `render_section_heading`, which emits the sort-order label
  # alongside the section heading. This branch is skipped when
  # `default_orders` is false (the common path when a sort is in effect).
  class IndexTest < ComponentTestCase
    def setup
      super
      @user = users(:rolf)
      controller.instance_variable_set(:@user, @user)
      controller.define_singleton_method(:index_sort_options) { {} }
    end

    def test_section_heading_includes_order_label_when_default_orders_true
      location = locations(:burbank)
      html = render_index(
        locations: [location],
        pagination_data: PaginationData.new(num_total: 1),
        default_orders: true
      )

      assert_html(html, "div.h4", text: :list_place_names_known.l.as_displayed)
      # The order label only appears when default_orders is true
      assert_html(html, "div.h4",
                  text: :list_place_names_known_order.l.as_displayed)
    end

    def test_section_heading_omits_order_label_when_default_orders_false
      location = locations(:burbank)
      html = render_index(
        locations: [location],
        pagination_data: PaginationData.new(num_total: 1),
        default_orders: false
      )

      assert_html(html, "div.h4")
      assert_no_html(html, "div.h4",
                     text: :list_place_names_known_order.l.as_displayed)
    end

    # `render_undefined_item` renders each unmatched location string with
    # a merge icon link. Drive it via `undef_data` with one obs/count pair.
    def test_renders_undefined_item_with_merge_link
      obs = observations(:minimal_unknown_obs)
      location_name = obs[:where]
      undef_pages = PaginationData.new(num_total: 1)
      html = render_index(undef_data: [[obs, 3]], undef_pages: undef_pages)

      assert_html(html, "#locations_undefined")
      expected = routes.matching_locations_for_observations_path(
        where: location_name
      )
      assert_html(html, "a[href='#{expected}']")
    end

    private

    def render_index(locations: [], pagination_data: PaginationData.new,
                     undef_pages: PaginationData.new, undef_data: [],
                     default_orders: false)
      idx = Index.new(
        query: Query.lookup_and_save(:Location),
        locations: locations,
        pagination_data: pagination_data,
        undef_pages: undef_pages,
        undef_data: undef_data,
        default_orders: default_orders
      )
      # Skip chrome registration — `Tab::Location::IndexActions` and
      # `add_sorter` need controller methods not available in component
      # test context.
      idx.define_singleton_method(:register_chrome) { nil }
      render(idx)
    end
  end
end
