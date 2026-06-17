# frozen_string_literal: true

require("test_helper")

class Components::ExportStatusControlsTest < ComponentTestCase
  def setup
    super
    controller.define_singleton_method(:reviewer?) { true }
  end

  def test_no_render_for_non_reviewer
    controller.define_singleton_method(:reviewer?) { false }
    html = render(Components::Image::ExportStatusControls.new(
                    object: names(:fungi)
                  ))

    assert_equal("", html)
  end

  def test_ok_for_export_true_bolds_current_state
    name = names(:fungi)
    name.update_attribute(:ok_for_export, true)
    html = render(Components::Image::ExportStatusControls.new(object: name))

    # Current state ("OK to export") is bold; the flip target
    # ("Don't export") renders as a link with `value: 0`.
    assert_html(html, "b", text: :review_ok_for_export.t)
    assert_html(html, "a", text: :review_no_export.t)
  end

  def test_ok_for_export_false_renders_flip_link
    # Lines 56 + 64 fire when `ok_for_export` is false:
    # the current state ("OK to export") becomes a link and the
    # flip target ("Don't export") becomes bold.
    name = names(:fungi)
    name.update_attribute(:ok_for_export, false)
    html = render(Components::Image::ExportStatusControls.new(object: name))

    assert_html(html, "a", text: :review_ok_for_export.t)
    assert_html(html, "b", text: :review_no_export.t)
  end

  def test_diagnostic_flag_for_image
    image = images(:in_situ_image)
    image.update_attribute(:diagnostic, true)
    html = render(
      Components::Image::ExportStatusControls.new(object: image,
                                                  flag: :diagnostic)
    )

    assert_html(html, "b", text: :review_diagnostic.t)
    assert_html(html, "a", text: :review_non_diagnostic.t)
  end
end
