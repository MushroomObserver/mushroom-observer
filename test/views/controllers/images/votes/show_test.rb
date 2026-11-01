# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Images::Votes
  class ShowTest < ComponentTestCase
    def setup
      super
      @user = users(:rolf)
      @image = images(:connected_coprinus_comatus_image)
    end

    def test_renders_vote_interface_inside_matching_turbo_frame
      html = render_show

      assert_html(html, "turbo-frame#image_vote_#{@image.id}")
      assert_html(html, "turbo-frame .vote-section#image_vote_#{@image.id}")
      assert_html(html, "turbo-frame .vote-meter.progress")
    end

    def test_lightbox_context_renders_prefixed_frame_and_content
      html = render_show(context: :lightbox)

      assert_html(html, "turbo-frame#lightbox_image_vote_#{@image.id}")
      assert_html(html,
                  "turbo-frame .vote-section-lightbox" \
                  "#lightbox_image_vote_#{@image.id}")
    end

    def test_renders_for_anonymous_viewer
      html = render_show(user: nil)

      assert_html(html, "turbo-frame#image_vote_#{@image.id}")
      assert_html(html, ".vote-section.require-user")
    end

    private

    def render_show(**)
      render(Show.new(image: @image, user: @user, **))
    end
  end
end
