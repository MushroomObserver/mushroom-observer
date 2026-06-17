# frozen_string_literal: true

require("test_helper")

# Tests the bare `Components::Carousel` primitive — the Bootstrap-3
# carousel skeleton with the A-pattern (`c.item(...) { … }` /
# `c.thumb(...) { … }`) registration API. The full read-only and
# form variants are tested in their consumer-level component tests
# (`ImageGalleryTest`, `Form::UploadGalleryTest`); this file focuses on
# the skeleton's own contract.
class CarouselTest < ComponentTestCase
  # The slot blocks run inside the primitive's render — `plain` and the
  # rest of the Phlex DOM helpers need a view scope, so the test
  # registers items via a tiny `Harness` Phlex view rather than calling
  # `render(Components::Carousel.new(...)) { ... }` directly from the
  # test class.
  class Harness < Components::Base
    prop :carousel_args, ::Hash
    prop :slides, ::Array, default: -> { [] }
    prop :thumbs, ::Array, default: -> { [] }

    def view_template
      render(Components::Carousel.new(**@carousel_args)) do |c|
        @slides.each do |slide|
          c.item(**slide.except(:content)) { plain(slide[:content]) }
        end
        @thumbs.each do |thumb|
          c.thumb(**thumb.except(:content)) { plain(thumb[:content]) }
        end
      end
    end
  end

  # Slides are rendered inside `.carousel-inner`; thumbs inside the
  # indicator `<ol>`. First registration of each gets `.active`.
  def test_renders_slides_and_thumbs_in_their_wrappers
    html = render(Harness.new(
                    carousel_args: { carousel_id: "test_carousel" },
                    slides: [{ id: "slide_1", content: "SLIDE_ONE" },
                             { id: "slide_2", content: "SLIDE_TWO" }],
                    thumbs: [{ id: "thumb_1", content: "THUMB_ONE" },
                             { id: "thumb_2", content: "THUMB_TWO" }]
                  ))

    assert_html(html, "div.carousel.slide[id='test_carousel']" \
                      "[data-ride='false'][data-interval='false']")
    assert_html(html, "div.carousel-inner.bg-light[role='listbox'] " \
                      "div.item.active[id='slide_1']", text: "SLIDE_ONE")
    assert_html(html, "div.carousel-inner div.item[id='slide_2']",
                text: "SLIDE_TWO")
    assert_html(html, "ol.carousel-indicators " \
                      "li.carousel-indicator.active[id='thumb_1']" \
                      "[data-target='#test_carousel'][data-slide-to='0']",
                text: "THUMB_ONE")
    assert_html(html, "ol.carousel-indicators li.carousel-indicator" \
                      "[id='thumb_2'][data-slide-to='1']",
                text: "THUMB_TWO")
  end

  # `class:` on item / thumb is composed onto the wrapper's class list.
  def test_item_and_thumb_classes_are_composed
    html = render(Harness.new(
                    carousel_args: { carousel_id: "c" },
                    slides: [{ class: "carousel-item", content: "S" }],
                    thumbs: [{ class: "mr-2", content: "T" }]
                  ))

    assert_html(html, "div.item.carousel-item.active", text: "S")
    assert_html(html, "li.carousel-indicator.mx-1.mr-2.active", text: "T")
  end

  # Caller-supplied `data:` merges with the primitive's auto-filled
  # `data-target` / `data-slide-to`.
  def test_thumb_data_merges_with_auto_target_and_slide_to
    html = render(Harness.new(
                    carousel_args: { carousel_id: "c" },
                    thumbs: [{ data: { form_images_target: "thumbnail",
                                       image_uuid: "42" },
                               content: "T" }]
                  ))

    assert_html(html, "li.carousel-indicator[data-target='#c']" \
                      "[data-slide-to='0']" \
                      "[data-form-images-target='thumbnail']" \
                      "[data-image-uuid='42']")
  end

  # `wrapper_class` is appended to the outer div's class. `inner_id` /
  # `inner_class_extra` decorate the `.carousel-inner` div. `indicators_id`
  # / `indicators_class_extra` decorate the indicator `<ol>`.
  def test_id_and_class_extras_are_applied
    html = render(Harness.new(
                    carousel_args: {
                      carousel_id: "obs_carousel",
                      wrapper_class: "image-form-carousel",
                      inner_id: "added_images",
                      inner_class_extra: "form-inner",
                      indicators_id: "added_thumbnails",
                      indicators_class_extra: "d-none"
                    },
                    slides: [{ content: "s" }],
                    thumbs: [{ content: "t" }]
                  ))

    assert_html(html, "div.carousel.slide.image-form-carousel")
    assert_html(html, "div.carousel-inner.bg-light.form-inner" \
                      "[id='added_images']")
    assert_html(html, "ol.carousel-indicators.d-none" \
                      "[id='added_thumbnails']")
  end

  # `extra_data` merges into the outer div's `data-*` attributes,
  # alongside the always-emitted `data-ride` / `data-interval` pair.
  def test_extra_data_merges_into_outer_data_attributes
    html = render(Harness.new(
                    carousel_args: {
                      carousel_id: "wire_test",
                      extra_data: { form_images_target: "carousel" }
                    },
                    slides: [{ content: "s" }]
                  ))

    assert_html(html, "div.carousel[data-form-images-target='carousel']")
  end

  # `show_controls: true` (default) renders the prev/next Controls
  # subcomponent at the bottom of `.carousel-inner`. The
  # `controls_wrap_class` prop, when set, wraps Controls in a div with
  # that class (Form::UploadGallery uses `carousel-control-wrap row`).
  def test_controls_render_inline_by_default
    html = render(Harness.new(carousel_args: { carousel_id: "c" },
                              slides: [{ content: "s" }]))

    assert_html(html, "div.carousel-inner a.left.carousel-control")
    assert_html(html, "div.carousel-inner a.right.carousel-control")
    assert_no_html(html, ".carousel-control-wrap")
  end

  def test_controls_can_be_wrapped_in_a_named_div
    html = render(Harness.new(
                    carousel_args: {
                      carousel_id: "c",
                      controls_wrap_class: "carousel-control-wrap row"
                    },
                    slides: [{ content: "s" }]
                  ))

    assert_html(html, "div.carousel-inner " \
                      "div.carousel-control-wrap.row " \
                      "a.left.carousel-control")
  end

  # `show_controls: false` suppresses the prev/next strip entirely
  # (`ImageGallery` passes this when there's only one image).
  def test_show_controls_false_suppresses_controls
    html = render(Harness.new(
                    carousel_args: { carousel_id: "c", show_controls: false },
                    slides: [{ content: "s" }]
                  ))

    assert_no_html(html, "a.carousel-control")
  end

  # `show_indicators: false` suppresses the indicator `<ol>` entirely.
  # Registered thumbs are silently dropped (the matrix-box carousel
  # uses this — no thumbnail strip per-box).
  def test_show_indicators_false_suppresses_indicator_strip
    html = render(Harness.new(
                    carousel_args: { carousel_id: "c",
                                     show_indicators: false },
                    slides: [{ content: "s" }],
                    thumbs: [{ content: "ignored" }]
                  ))

    assert_no_html(html, "ol.carousel-indicators")
    assert_not_includes(html, "ignored")
  end
end
