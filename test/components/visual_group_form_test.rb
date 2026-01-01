# frozen_string_literal: true

require "test_helper"

class VisualGroupFormTest < ComponentTestCase

  def setup
    super
    @visual_model = visual_models(:visual_model_one)
    @visual_group = VisualGroup.new(visual_model: @visual_model)
    @html = render_form
  end

  def test_renders_form_with_name_field
    assert_html(@html, "input[name='visual_group[name]']")
    assert_html(@html, "input[size='40']")
    assert_html(@html, "body", text: :VISUAL_GROUP.l)
  end

  def test_renders_form_with_description_field
    assert_html(@html, "body", text: :DESCRIPTION.l)
    assert_html(@html, "textarea[name='visual_group[description]']")
    assert_html(@html, "textarea[rows='10']")
    assert_html(@html, "textarea[cols='60']")
  end

  def test_renders_form_with_approved_checkbox
    assert_html(@html, "body", text: :APPROVED.l)
    assert_html(@html, "input[name='visual_group[approved]']")
  end

  def test_renders_submit_button
    assert_html(@html, "input[type='submit'][value='#{:SUBMIT.t}']")
    assert_html(@html, ".center-block")
  end

  def test_auto_determines_url_for_new_visual_group
    html = render_form_without_action
    expected_action = "/visual_models/#{@visual_model.id}/visual_groups"
    assert_html(html, "form[action='#{expected_action}']")
  end

  def test_auto_determines_url_for_existing_visual_group
    @visual_group = visual_groups(:visual_group_one)
    html = render_form_without_action

    assert_html(html, "form[action='/visual_groups/#{@visual_group.id}']")
  end

  def test_renders_errors_when_model_has_errors
    @visual_group.errors.add(:name, "can't be blank")
    html = render_form

    assert_html(html, "#error_explanation")
    assert_html(html, "h2")
    assert_html(html, "li")
    assert_match(/1 #{:error.t}/, html)
    assert_match(/Name can.{1,6}t be blank/, html)
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

  def render_form_without_action
    form = Components::VisualGroupForm.new(
      @visual_group,
      visual_model: @visual_model
    )
    render(form)
  end
end
