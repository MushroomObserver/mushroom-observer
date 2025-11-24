# frozen_string_literal: true

require "test_helper"

class FeatureEmailFormTest < UnitTestCase
  include ComponentTestHelper

  def setup
    super
    @email = FormObject::FeatureEmail.new
    @users = [users(:rolf), users(:mary)]
    controller.request = ActionDispatch::TestRequest.create
    @html = render_form
  end

  def test_renders_form_with_user_count
    assert_includes(@html, "Sending to #{@users.length} users")
  end

  def test_renders_form_with_content_field
    assert_includes(@html, "Feature Email:")
    assert_html(@html, "textarea[name='feature_email[content]']")
    assert_html(@html, "textarea[rows='20']")
    assert_html(@html, "textarea[data-autofocus]")
  end

  def test_renders_submit_button
    assert_html(@html, "input[type='submit'][value='#{:SEND.l}']")
    assert_html(@html, ".center-block")
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
