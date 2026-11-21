# frozen_string_literal: true

require "test_helper"

module Views::Controllers::Locations
  class Show
    class AltDescriptionsPanelTest < ComponentTestCase
      def test_renders_panel_id
        html = render(new_panel)

        assert_html(html, "#alt_descriptions")
      end

      def test_renders_heading_link
        location = locations(:gualala)
        html = render(new_panel(object: location))

        assert_html(
          html,
          "#alt_descriptions .card-header-links a[href='" \
          "#{routes.new_location_description_path(location_id: location.id)}']"
        )
      end

      def test_renders_descriptions_list
        html = render(new_panel)

        # Embeds `Views::Controllers::Descriptions::List`, which emits
        # `description_link_<id>` for visible descriptions.
        desc = location_descriptions(:user_public_location_desc)
        assert_html(html, "a.description_link_#{desc.id}")
      end

      private

      def new_panel(object: locations(:gualala), user: users(:rolf))
        AltDescriptionsPanel.new(object: object, user: user)
      end
    end
  end
end
