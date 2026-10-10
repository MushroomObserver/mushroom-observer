# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Locations::Undefined
  class IndexTest < ComponentTestCase
    def setup
      super
      @user = users(:rolf)
      controller.instance_variable_set(:@user, @user)
    end

    def test_renders_help_text
      html = render_index

      assert_html(html, "#undefined_locations_help",
                  text: :list_place_names_undef_help.l.as_displayed)
      assert_html(html, "#undefined_locations_help",
                  text: :list_place_names_parenthetical.l.as_displayed)
    end

    def test_renders_item_with_location_link_merge_and_define_links
      obs = observations(:minimal_unknown_obs)
      location_name = obs[:where]
      html = render_index(undef_data: [[obs, 3]])

      assert_html(html,
                  "a[href='#{routes.observations_path(where: location_name)}']")

      merge_target = routes.matching_locations_for_observations_path(
        where: location_name
      )
      merge_title = :list_place_names_undef_merge_tooltip.t
      assert_html(html, "a[href='#{merge_target}'][title='#{merge_title}']")

      define_target = routes.new_location_path(where: location_name)
      define_title = :list_place_names_undef_define_tooltip.t
      assert_html(html, "a[href='#{define_target}'][title='#{define_title}']")

      # `.list-group-item` is the Bootstrap structural class the
      # ListGroup wrapper itself depends on -- scoping the count to one
      # row this way avoids matching against the whole rendered page.
      assert_html(html, ".list-group-item", text: "(3)")
    end

    private

    def render_index(undef_data: [], pagination_data: PaginationData.new)
      render(Index.new(undef_data: undef_data,
                       pagination_data: pagination_data))
    end
  end
end
