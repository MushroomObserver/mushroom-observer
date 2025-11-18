# frozen_string_literal: true

require "test_helper"

class VisualModelFormTest < UnitTestCase
  include ComponentTestHelper

  def setup
    super
    @visual_model = VisualModel.new
    controller.request = ActionDispatch::TestRequest.create
  end

  def test_renders_form_with_name_field
    form = render_form

    assert_includes(form, 'name="visual_model[name]"')
    assert_includes(form, :VISUAL_MODEL.t)
  end

  def test_renders_submit_button
    form = render_form

    assert_includes(form, :SUBMIT.t)
    assert_includes(form, "center-block")
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
