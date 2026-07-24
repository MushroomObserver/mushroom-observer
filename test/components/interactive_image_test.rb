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
  # which dispatches to `Components::ImageFragment::VoteInterface`. Verify
  # the dispatch actually happens (the previous version of this test only
  # asserted the unrelated `image-sizer` and missed a regression where
  # the sub-component call was malformed and silently no-op'd).
  # #4895: the vote section is a lazy-loading Turbo Frame now, not
  # rendered inline -- Matrix::Box's fragment cache has no user
  # component in its key, so rendering vote state directly here would
  # bake one viewer's votes into the shared cached HTML for everyone.
  def test_renders_with_votes_enabled
    html = render_image(votes: true)

    assert_includes(html, "image-sizer")
    assert_html(html, "turbo-frame#image_vote_#{@image.id}[loading='lazy']")
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

  # #4894: the caption is a real, hidden DOM element nested inside the
  # theater-btn (not a captured-HTML string in `data-sub-html`) -- a
  # `div`, not an `a`, since it now legally contains the caption's own
  # interactive content (vote buttons, propose-naming trigger).
  # `data-sub-html` is a plain CSS selector lightGallery resolves at
  # open time (`subHtmlSelectorRelative: true`, see
  # lightgallery_controller.js).
  def test_theater_button_has_data_sub_html_selector_with_image_links
    html = render_image

    assert_html(html, "div.theater-btn[data-sub-html='.lightbox-caption']")

    caption = Nokogiri::HTML5.fragment(html).at_css(".lightbox-caption")
    assert_equal("lightbox_caption_#{@image.id}", caption["id"])
    assert_includes(caption["class"], "d-none")
    caption_html = caption.to_html
    assert_includes(caption_html, "caption-image-links")
    assert_includes(caption_html, "/images/#{@image.id}/original")
    assert_includes(caption_html, "/images/#{@image.id}/exif")
    assert_includes(caption_html, "lightbox_link")
  end

  # #4886: `votes:` threads all the way from `InteractiveImage` through
  # `BaseImage#render_lightbox_caption` into the lightbox caption's own
  # `context: :lightbox` copy of the vote UI, nested in the theater
  # button's hidden caption element.
  def test_theater_button_caption_includes_lightbox_vote_section
    html = render_image(votes: true)

    caption_html =
      Nokogiri::HTML5.fragment(html).at_css(".lightbox-caption").to_html
    assert_includes(caption_html, "lightbox_image_vote_#{@image.id}")
    assert_includes(caption_html, "turbo-frame")
  end

  def test_theater_button_caption_omits_vote_section_when_votes_disabled
    html = render_image(votes: false)

    caption_html =
      Nokogiri::HTML5.fragment(html).at_css(".lightbox-caption").to_html
    assert_not_includes(caption_html, "turbo-frame")
  end

  # Image#broadcast_interactive_sizes renders with media_only: true so a
  # background-processing broadcast never touches page-specific link/
  # votes/overlay markup -- see the comment on Image#broadcast_interactive_
  # sizes for why. Confirms only the image container itself renders.
  def test_media_only_renders_just_the_image_container
    html = render_image(votes: true, image_link: "/custom/path",
                        media_only: true)
    media_id = "interactive_image_#{@image.id}_medium_media"

    assert_html(html, "div##{media_id}.image-lazy-sizer")
    assert_html(html, "img.image_#{@image.id}")
    assert_no_html(html, ".image-sizer")
    assert_no_html(html, "a.stretched-link")
    assert_no_html(html, ".vote-section")
    assert_not_includes(html, "/custom/path")
    # The broadcast-swapped fragment must re-trigger LazyLoad itself --
    # the layout-level lazyload controller only fires on full page
    # loads, so without this the swapped img.lazy stays on the
    # placeholder. Initial (non-media_only) renders are covered by the
    # layout and don't need it.
    assert_html(html, "div##{media_id}[data-controller='lazyload']")
    normal_html = render_image(votes: false)
    assert_no_html(normal_html, "[data-controller='lazyload']")
  end

  def test_kit_syntax_renders_same_as_direct_instantiation
    view = Class.new(Components::Base) do
      def initialize(user:, image:)
        super()
        @user = user
        @image = image
      end

      def view_template
        InteractiveImage(user: @user, image: @image, votes: false)
      end
    end

    html = render(view.new(user: @user, image: @image))
    direct_html = render(
      Components::InteractiveImage.new(
        user: @user, image: @image, votes: false
      )
    )

    assert_equal(direct_html, html)
  end

  private

  def render_image(image: @image, size: :medium, **)
    render(Components::InteractiveImage.new(
             user: @user, image: image, size: size, votes: false,
             image_link: nil, upload: false, media_only: false, **
           ))
  end
end
