# frozen_string_literal: true

require "test_helper"

class InteractiveImageTest < ComponentTestCase
  def setup
    super
    @user = users(:rolf)
    @image = images(:connected_coprinus_comatus_image)
  end

  def test_renders_with_valid_image
    html = render_image

    assert_includes(html, "image-sizer")
    assert_includes(html, "image_#{@image.id}")
    assert_includes(html, "interactive_image_#{@image.id}")
    # Should have the lazy loading image with the image_X class
    assert_html(html, "img.image_#{@image.id}")
  end

  def test_renders_with_custom_size
    html = render_image(size: :huge)

    assert_includes(html, "image-sizer")
  end

  # The vote section is rendered by `BaseImage#render_image_vote_section`,
  # which dispatches to `Components::ImageVoteInterface`. Verify the
  # dispatch actually happens (the previous version of this test only
  # asserted the unrelated `image-sizer` and missed a regression where
  # the sub-component call was malformed and silently no-op'd).
  def test_renders_with_votes_enabled
    html = render_image(votes: true)

    assert_includes(html, "image-sizer")
    assert_html(html, "div.vote-section#image_vote_#{@image.id}")
    assert_html(html, ".vote-meter.progress")
    assert_html(html, ".vote-buttons")
    assert_html(html, ".image-vote-links#image_vote_links_#{@image.id}")
  end

  def test_renders_with_votes_disabled
    html = render_image(votes: false)

    assert_includes(html, "image-sizer")
    # No vote section at all when votes: false.
    assert_no_html(html, ".vote-section")
    assert_no_html(html, ".vote-meter")
  end

  def test_renders_with_custom_link
    html = render_image(image_link: "/custom/path")

    assert_includes(html, "/custom/path")
  end

  def test_does_not_render_for_upload_with_nil_image
    html = render_image(image: nil, upload: true)

    # Should return early and render nothing
    assert_equal("", html)
  end

  def test_theater_button_has_data_sub_html_with_image_links
    html = render_image

    # Should have theater button with data-sub-html attribute
    assert_html(html, "a.theater-btn[data-sub-html]")

    # The data-sub-html should contain the image links from LightboxCaption
    sub_html = Nokogiri::HTML(html).at_css("a.theater-btn")["data-sub-html"]
    assert_includes(sub_html, "caption-image-links")
    assert_includes(sub_html, "/images/#{@image.id}/original")
    assert_includes(sub_html, "/images/#{@image.id}/exif")
    assert_includes(sub_html, "lightbox_link")
  end

  private

  def render_image(image: @image, size: :medium, votes: false,
                   image_link: nil, upload: false)
    render(Components::InteractiveImage.new(
             user: @user,
             image: image,
             size: size,
             votes: votes,
             image_link: image_link,
             upload: upload
           ))
  end
end
