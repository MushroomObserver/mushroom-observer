# frozen_string_literal: true

require "test_helper"

class VisualGroupFormTest < UnitTestCase
  include ComponentTestHelper

  def setup
    super
    @visual_model = visual_models(:visual_model_one)
    @visual_group = VisualGroup.new(visual_model: @visual_model)
    controller.request = ActionDispatch::TestRequest.create
  end

  def test_renders_form_with_name_field
    form = render_form

    assert_includes(form, 'name="visual_group[name]"')
    assert_includes(form, 'size="40"')
    assert_includes(form, :VISUAL_GROUP.t)
  end

  def test_renders_form_with_description_field
    form = render_form

    assert_includes(form, :DESCRIPTION.t)
    assert_includes(form, 'name="visual_group[description]"')
    assert_includes(form, "rows=\"10\"")
    assert_includes(form, "cols=\"60\"")
  end

  def test_renders_form_with_approved_checkbox
    form = render_form

    assert_includes(form, :APPROVED.t)
    assert_includes(form, 'name="visual_group[approved]"')
  end

  def test_renders_submit_button
    form = render_form

    assert_includes(form, :SUBMIT.t)
    assert_includes(form, "center-block")
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
