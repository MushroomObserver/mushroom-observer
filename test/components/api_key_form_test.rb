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
    html = render_form_without_cancel

    assert_html(html, ".form-group")
    assert_includes(html, :account_api_keys_notes_label.t)
    assert_html(html, "#api_key_notes")
    assert_html(
      html,
      "input[type='submit'][value='#{:account_api_keys_create_button.l}']"
    )
  end

  def test_renders_table_layout_with_cancel_button
    html = render_form_with_cancel

    assert_html(html, ".input-group")
    assert_includes(html, :CANCEL.l)
    assert_html(html, ".input-group-btn")
    assert_html(html, "#api_key_notes")
    assert_html(html, "button[data-toggle='collapse']")
  end

  def test_cancel_button_has_correct_data_attributes
    html = render_form_with_cancel

    assert_html(html, "button[data-target='#test_target']")
    assert_html(html, "button[data-parent='#test_parent']")
    assert_html(html, "button[aria-controls='test_target']")
  end

  def test_cancel_button_not_rendered_when_nil
    html = render_form_without_cancel

    assert_not_includes(html, "input-group")
  end

  def test_table_layout_has_one_label_outside_input_group
    html = render_form_with_cancel

    # Should have exactly one label
    label_count = html.scan("<label").length
    assert_equal(1, label_count, "Should have exactly one label")

    # Label should be outside input-group and have correct for attribute
    pattern = %r{<label[^>]*for="api_key_notes"[^>]*>.*?</label>.*?
                 <div\sclass="input-group">}mx
    assert_match(pattern, html)

    # Input should not be wrapped in form-group
    assert_no_match(/<div class="input-group">.*?<div class="form-group">/m,
                    html)
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
