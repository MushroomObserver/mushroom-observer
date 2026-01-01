# frozen_string_literal: true

require "test_helper"

class VisualModelFormTest < ComponentTestCase

  def setup
    super
    @visual_model = VisualModel.new
    @html = render_form
  end

  def test_renders_form_with_name_field
    assert_html(@html, "input[name='visual_model[name]']")
    assert_html(@html, "body", text: :VISUAL_MODEL.l)
  end

  def test_renders_submit_button
    assert_html(@html, "input[type='submit'][value='#{:SUBMIT.t}']")
    assert_html(@html, ".center-block")
  end

  def test_renders_errors_when_model_has_errors
    @visual_model.errors.add(:name, "can't be blank")
    html = render_form

    assert_html(html, "#error_explanation")
    assert_html(html, "h2")
    assert_html(html, "li")
    assert_match(/1 #{:error.t}/, html)
    assert_match(/#{:visual_model_errors.t}/, html)
    assert_match(/Name can.{1,6}t be blank/, html)
  end

  private

  def render_form
    form = Components::VisualModelForm.new(
      @visual_model,
      action: "/test_action",
      id: "visual_model_form"
    )
    render(form)
  end
end
