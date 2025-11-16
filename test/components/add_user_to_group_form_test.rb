# frozen_string_literal: true

require "test_helper"

class AddUserToGroupFormTest < UnitTestCase
  include ComponentTestHelper

  def setup
    @model = Struct.new(:user_name, :group_name).new("test_user", "test_group")
    controller.request = ActionDispatch::TestRequest.create
  end

  def test_renders_form_with_user_name_field
    form = render_form

    assert_includes(form, :add_user_to_group_user.t)
    assert_includes(form, 'name="user_name"')
    assert_includes(form, 'value="test_user"')
    assert_includes(form, "data-autofocus")
  end

  def test_renders_form_with_group_name_field
    form = render_form

    assert_includes(form, :add_user_to_group_group.t)
    assert_includes(form, 'name="group_name"')
    assert_includes(form, 'value="test_group"')
  end

  def test_renders_submit_button
    form = render_form

    assert_includes(form, :ADD.t)
    assert_includes(form, "btn btn-default")
    assert_includes(form, "center-block my-3")
    assert_includes(form, "data-turbo-submits-with")
  end

  def test_form_has_correct_attributes
    form = render_form

    assert_includes(form, 'action="/test_action"')
    assert_includes(form, 'method="post"')
    assert_includes(form, 'id="add_user_to_group_form"')
  end

  private

  def render_form
    form = Components::AddUserToGroupForm.new(
      @model,
      action: "/test_action",
      id: "add_user_to_group_form"
    )
    render(form)
  end
end
