# frozen_string_literal: true

require "test_helper"

class APIKeyFormTest < UnitTestCase
  include ComponentTestHelper

  def setup
    @api_key = APIKey.new

    # Set up controller request context for form URL generation
    controller.request = ActionDispatch::TestRequest.create
  end

  def test_renders_standalone_layout_without_cancel_button
    form = render_form_without_cancel

    assert_includes(form, "form-group")
    assert_includes(form, :account_api_keys_notes_label.t)
    assert_includes(form, 'id="new_api_key_notes"')
    assert_includes(form, :account_api_keys_create_button.l)
  end

  def test_renders_table_layout_with_cancel_button
    form = render_form_with_cancel

    assert_includes(form, "input-group")
    assert_includes(form, :CANCEL.l)
    assert_includes(form, "input-group-btn")
    assert_includes(form, 'id="new_api_key_notes"')
    assert_includes(form, 'data-toggle="collapse"')
  end

  def test_cancel_button_has_correct_data_attributes
    form = render_form_with_cancel

    assert_includes(form, 'data-target="#test_target"')
    assert_includes(form, 'data-parent="#test_parent"')
    assert_includes(form, 'aria-controls="test_target"')
  end

  def test_cancel_button_not_rendered_when_nil
    form = render_form_without_cancel

    assert_not_includes(form, "input-group")
  end

  private

  def render_form_without_cancel
    form = Components::APIKeyForm.new(
      @api_key,
      action: "/test_api_keys_path",
      id: "new_api_key_form"
    )
    render(form)
  end

  def render_form_with_cancel
    form = Components::APIKeyForm.new(
      @api_key,
      action: "/test_api_keys_path",
      id: "new_api_key_form",
      cancel_target: "test_target",
      cancel_parent: "test_parent"
    )
    render(form)
  end
end
