# frozen_string_literal: true

require "test_helper"

class UserBonusesFormTest < UnitTestCase
  include ComponentTestHelper

  def setup
    super
    @user = users(:rolf)
    @val = "10\n20\n30"
    @help_text = "Test help text"
    controller.request = ActionDispatch::TestRequest.create
  end

  def test_renders_form_with_help_text
    form = render_form

    assert_includes(form, @help_text)
  end

  def test_renders_form_with_val_textarea
    form = render_form

    assert_includes(form, 'name="user[val]"')
    assert_includes(form, "rows=\"5\"")
    assert_includes(form, @val)
  end

  def test_renders_submit_button
    form = render_form

    assert_includes(form, :SAVE_EDITS.l)
    assert_includes(form, "center-block")
  end

  private

  def render_form
    form = Components::UserBonusesForm.new(
      @user,
      val: @val,
      help_text: @help_text,
      action: "/test_action",
      id: "user_bonuses_form"
    )
    render(form)
  end
end
