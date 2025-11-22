# frozen_string_literal: true

require "test_helper"

class VisualGroupFormTest < UnitTestCase
  include ComponentTestHelper

  def setup
    super
    @visual_model = visual_models(:visual_model_one)
    @visual_group = VisualGroup.new(visual_model: @visual_model)
    controller.request = ActionDispatch::TestRequest.create
    @html = render_form
  end

  def test_renders_form_with_name_field
    assert_html(@html, "input[name='visual_group[name]']")
    assert_html(@html, "input[size='40']")
    assert_includes(@html, :VISUAL_GROUP.t)
  end

  def test_renders_form_with_description_field
    assert_includes(@html, :DESCRIPTION.t)
    assert_html(@html, "textarea[name='visual_group[description]']")
    assert_html(@html, "textarea[rows='10']")
    assert_html(@html, "textarea[cols='60']")
  end

  def test_renders_form_with_approved_checkbox
    assert_includes(@html, :APPROVED.t)
    assert_html(@html, "input[name='visual_group[approved]']")
  end

  def test_renders_submit_button
    assert_html(@html, "input[type='submit'][value='#{:SUBMIT.t}']")
    assert_html(@html, ".center-block")
  end

  private

  def render_form
    form = Components::VisualGroupForm.new(
      @visual_group,
      visual_model: @visual_model,
      action: "/test_action",
      id: "visual_group_form"
    )
    render(form)
  end
end
