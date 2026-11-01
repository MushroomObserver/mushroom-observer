# frozen_string_literal: true

require("test_helper")

# Tests for Components::ApplicationForm::ButtonStyleRadio — the
# button-styled radio component used by Form::UploadGallery and elsewhere.
# Unlike RadioField, this component is standalone (no Field/FieldProxy)
# and has NO `.radio` div wrap.
class ButtonStyleRadioTest < ComponentTestCase
  def test_renders_radio_zone_and_label_zone_as_siblings
    html = render_radio(
      name: "obs[thumb]", value: "42", id: "thumb_42"
    ) { "Pick this" }

    # <div class="radio-zone"><input type="radio" ...><label for=.../></div>
    # <div class="label-zone">Pick this</div>
    assert_html(html, ".radio-zone > input[type='radio']" \
                      "[name='obs[thumb]'][value='42'][id='thumb_42']")
    assert_html(html, ".radio-zone > label[for='thumb_42']")
    assert_html(html, ".label-zone", text: "Pick this")
    # No `.radio` div wrap — that's intentional.
    assert_no_html(html, ".radio")
  end

  def test_checked_true_sets_input_attr
    html = render_radio(name: "n", value: "1", id: "x", checked: true)

    assert_html(html, "input[type='radio'][checked]")
  end

  def test_checked_default_false_omits_attr
    html = render_radio(name: "n", value: "1", id: "x")

    assert_html(html, "input[type='radio']:not([checked])")
  end

  def test_label_attrs_applied_to_wrapper
    html = render_radio(
      name: "n", value: "1", id: "x",
      label: { class: "thumb_img_btn",
               data: { action: "click->form-images#set" } }
    )

    assert_html(html, ".thumb_img_btn[data-action='click->form-images#set']")
  end

  def test_input_attrs_passed_through_via_splat
    html = render_radio(
      name: "n", value: "1", id: "x",
      class: "form-control",
      data: { thumb_id: "1" }
    )

    assert_html(html, "input[type='radio'].form-control" \
                      "[data-thumb-id='1']")
  end

  def test_renders_without_block_content
    html = render_radio(name: "n", value: "1", id: "x")

    assert_html(html, ".radio-zone > input[type='radio']")
    assert_html(html, ".label-zone")
  end

  private

  def render_radio(**, &block)
    render(Components::ApplicationForm::ButtonStyleRadio.new(**), &block)
  end
end
