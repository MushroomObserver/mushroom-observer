# frozen_string_literal: true

require "test_helper"

class UserBonusesFormTest < UnitTestCase
  include ComponentTestHelper

  def setup
    super
    @user = users(:rolf)
    @user_stats = UserStats.find_or_create_by(user_id: @user.id)
    @user_stats.bonuses = [[10, "Test reason 1"], [20, "Test reason 2"],
                           [30, "Test reason 3"]]
    @help_text = "Test help text"
    controller.request = ActionDispatch::TestRequest.create
    @html = render_form
  end

  def test_renders_form_with_help_text
    assert_includes(@html, @help_text)
  end

  def test_renders_form_with_val_textarea
    assert_html(@html, "textarea[name='user_stats[val]']")
    assert_html(@html, "textarea[rows='5']")
    assert_includes(@html, @user_stats.formatted_bonuses)
  end

  def test_renders_submit_button
    assert_html(@html, "input[type='submit'][value='#{:SAVE_EDITS.l}']")
    assert_html(@html, ".center-block")
  end

  private

  def render_form
    form = Components::UserBonusesForm.new(
      @user_stats,
      help_text: @help_text,
      action: "/test_action",
      id: "user_bonuses_form"
    )
    render(form)
  end
end
