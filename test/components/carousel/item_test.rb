# frozen_string_literal: true

require "test_helper"

class Components::Carousel::ItemTest < ComponentTestCase
  def setup
    super
    @user = users(:rolf)
    @obs = observations(:coprinus_comatus_obs)
    @image = @obs.images.first
  end

  # `object:` is Carousel::Item's own prop (any AbstractModel --
  # ImageGallery renders carousels for names/locations/users too),
  # separate from the inherited Image::Base#obs prop the lightbox
  # caption actually reads. Passing an Observation as `object:` must
  # thread through to `obs:`, or the caption silently falls back to
  # the image-only branch on every carousel-driven lightbox.
  def test_observation_object_threads_into_lightbox_caption
    html = render(Components::Carousel::Item.new(
                    user: @user, image: @image, object: @obs
                  ))

    caption = Nokogiri::HTML5.fragment(html).at_css(".lightbox-caption")
    assert_includes(caption.to_html, "obs-what")
    assert_includes(caption.to_html, "obs-when")
  end

  # A non-Observation object (e.g. a Location, on a location's own
  # image gallery) must NOT be forced into `obs:` -- Image::Base#obs
  # only accepts an Observation or a Hash.
  def test_non_observation_object_does_not_thread_into_obs
    location = locations(:burbank)

    html = render(Components::Carousel::Item.new(
                    user: @user, image: @image, object: location
                  ))

    caption = Nokogiri::HTML5.fragment(html).at_css(".lightbox-caption")
    assert_not_includes(caption.to_html, "obs-what")
  end
end
