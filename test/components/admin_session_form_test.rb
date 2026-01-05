# frozen_string_literal: true

require("test_helper")

class AdminSessionFormTest < ComponentTestCase
  def setup
    super
    @form = FormObject::AdminSession.new
  end

  def test_renders_form_structure
    html = render_form

    # Form structure
    assert_html(html, "#admin_switch_users_form")
    assert_html(html, "form[action='/admin/session']")

    # User autocompleter field
    assert_html(html, "[data-controller*='autocompleter--user']")
    assert_html(html, "[data-type='user']")

    # Label
    assert_includes(html, :LOGIN_NAME.l)

    # Submit button
    assert_html(html, "input[type='submit'][value='#{:SUBMIT.l}']")
  end

  def test_renders_with_prefilled_id
    @form = FormObject::AdminSession.new(id: "rolf")
    html = render_form

    assert_html(html, "input[value='rolf']")
  end

  private

  def render_form
    render(Components::AdminSessionForm.new(@form))
  end
end
