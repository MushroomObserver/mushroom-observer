# frozen_string_literal: true

require "test_helper"

class ImageFragmentLazyVoteInterfaceTest < ComponentTestCase
  def setup
    super
    @image = images(:connected_coprinus_comatus_image)
  end

  def test_renders_lazy_turbo_frame_for_overlay_context
    html = render(Components::ImageFragment::LazyVoteInterface.new(
                    image: @image
                  ))

    assert_html(html, "turbo-frame#image_vote_#{@image.id}" \
                      "[loading='lazy'][src]")
    frame_src = Nokogiri::HTML5.fragment(html).at_css("turbo-frame")["src"]
    assert_includes(frame_src, "/images/#{@image.id}/vote")
    assert_includes(frame_src, "context=overlay")
  end

  def test_renders_lazy_turbo_frame_for_lightbox_context
    html = render(Components::ImageFragment::LazyVoteInterface.new(
                    image: @image, context: :lightbox
                  ))

    assert_html(html, "turbo-frame#lightbox_image_vote_#{@image.id}" \
                      "[loading='lazy']")
    frame_src = Nokogiri::HTML5.fragment(html).at_css("turbo-frame")["src"]
    assert_includes(frame_src, "context=lightbox")
  end
end
