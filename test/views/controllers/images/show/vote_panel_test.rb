# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Images
  class Show
    class VotePanelTest < ComponentTestCase
      def setup
        super
        @image = images(:peltigera_image)
        # `vote_link_args` produces a hash `{id:, vote:}` that relies on
        # the request's controller/action to resolve into `/images/:id`.
        # In ComponentTestCase the controller is the bare TestController,
        # so spoof the path params Rails' `url_for` reads.
        controller.request.path_parameters[:controller] = "images"
        controller.request.path_parameters[:action] = "show"
      end

      def test_renders_heading_for_logged_out_viewer
        controller.instance_variable_set(:@user, nil)

        html = render(VotePanel.new(image: @image))

        assert_html(html, "#image_vote_content")
        assert_html(html, "table.table-show-votes")
        assert_no_html(html, "a[data-role='image_vote']")
      end

      def test_renders_vote_grid_for_logged_in_viewer
        controller.instance_variable_set(:@user, users(:rolf))

        html = render(VotePanel.new(image: @image))

        assert_html(html, "a[data-role='image_vote']")
        assert_html(html, "table.table-show-votes")
      end

      def test_anonymous_vote_row_hides_user
        image_votes(:in_situ_image_mary_vote).update!(anonymous: true)
        controller.instance_variable_set(:@user, users(:rolf))

        html = render(VotePanel.new(image: @image))

        doc = Nokogiri::HTML.fragment(html)
        assert_includes(doc.css("table.table-show-votes td").map(&:text),
                        :anonymous.t)
        assert_no_html(html,
                       "table.table-show-votes " \
                       "a[href*='#{users(:mary).id}']")
      end
    end
  end
end
