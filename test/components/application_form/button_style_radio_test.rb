# frozen_string_literal: true

require("test_helper")

# Tests for Components::ApplicationForm::ButtonStyleRadio — the
# button-styled radio component used by FormCarousel and elsewhere.
# Unlike RadioField, this component is standalone (no Field/FieldProxy)
# and has NO `.radio` div wrap.
class ButtonStyleRadioTest < ComponentTestCase
  def test_renders_label_wrapping_radio_input
    html = render(klass.new(
                    name: "obs[thumb]", value: "42",
                    id: "thumb_42"
                  )) { "Pick this" }

    # <label for="thumb_42"><input type="radio" ...>Pick this</label>
    assert_html(html, "label[for='thumb_42'] > input[type='radio']" \
                      "[name='obs[thumb]'][value='42'][id='thumb_42']")
    assert_includes(html, "Pick this")
    # No `.radio` div wrap — that's intentional.
    assert_no_html(html, ".radio")
  end

  def test_checked_true_sets_input_attr
    html = render(klass.new(
                    name: "n", value: "1", id: "x", checked: true
                  ))

    assert_html(html, "input[type='radio'][checked]")
  end

  def test_checked_default_false_omits_attr
    html = render(klass.new(name: "n", value: "1", id: "x"))

    assert_html(html, "input[type='radio']:not([checked])")
  end

  def test_label_attrs_passed_through
    html = render(klass.new(
                    name: "n", value: "1", id: "x",
                    label: { class: "btn btn-default thumb_img_btn",
                             data: { action: "click->form-images#set" } }
                  ))

    assert_html(html, "label.btn.btn-default.thumb_img_btn[for='x']")
    assert_html(html, "label[data-action='click->form-images#set']")
  end

  def test_input_attrs_passed_through_via_splat
    html = render(klass.new(
                    name: "n", value: "1", id: "x",
                    class: "form-control",
                    data: { thumb_id: "1" }
                  ))

    assert_html(html, "input[type='radio'].form-control" \
                      "[data-thumb-id='1']")
  end

  def test_renders_without_block_content
    html = render(klass.new(name: "n", value: "1", id: "x"))

    # Label exists, contains the input, no extra content.
    assert_html(html, "label[for='x'] > input[type='radio']")
  end

  private

  def klass
    Components::ApplicationForm::ButtonStyleRadio
  end
end
