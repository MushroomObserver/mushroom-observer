# frozen_string_literal: true

require "test_helper"

class VisualModelFormTest < UnitTestCase
  include ComponentTestHelper

  def setup
    super
    @visual_model = VisualModel.new
    controller.request = ActionDispatch::TestRequest.create
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
