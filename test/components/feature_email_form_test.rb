# frozen_string_literal: true

require "test_helper"

class FeatureEmailFormTest < UnitTestCase
  include ComponentTestHelper

  def setup
    super
    @email = FormObject::FeatureEmail.new
    @users = [users(:rolf), users(:mary)]
    controller.request = ActionDispatch::TestRequest.create
  end

  def test_renders_form_with_user_count
    form = render_form

    assert_includes(form, "Sending to #{@users.length} users")
  end

  def test_renders_form_with_content_field
    form = render_form

    assert_includes(form, "Feature Email:")
    assert_includes(form, 'name="feature_email[content]"')
    assert_includes(form, "rows=\"20\"")
    assert_includes(form, "data-autofocus")
  end

  def test_renders_user_logins
    form = render_form

    assert_includes(form, :USERS.l)
    assert_includes(form, "rolf, mary")
  end

  def test_renders_submit_button
    form = render_form

    assert_includes(form, :SEND.l)
    assert_includes(form, "center-block")
  end

  private

  def render_form
    form = Components::FeatureEmailForm.new(
      @email,
      users: @users,
      action: "/test_action",
      id: "feature_email_form"
    )
    render(form)
  end
end
