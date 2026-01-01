# frozen_string_literal: true

require "test_helper"

class TextileSandboxFormTest < ComponentTestCase

  def setup
  end

  # NOTE: Page title and help block are now rendered by the view
  # template (Views::Controllers::Info::TextileSandbox), not the
  # component. Those should be tested in controller/integration tests.

  def test_renders_textarea_field
    html = render_initial_form
    assert_html(html, "textarea[name='textile_sandbox[code]']")
    assert_html(html, "textarea[id='textile_sandbox_code']")
    assert_html(html, "textarea[rows='8']")
  end

  def test_renders_label_for_textarea
    html = render_initial_form
    assert_html(html, "body", text: "#{:sandbox_enter.t}:")
  end

  def test_renders_submit_button_when_no_result
    html = render_initial_form
    assert_html(html, "input[type='submit'][value='#{:sandbox_test.l}']")
  end

  def test_does_not_render_up_arrows_when_no_result
    html = render_initial_form

    assert_no_html(html, ".sandbox-up-ptr")
  end

  def test_does_not_render_result_section_when_no_result
    html = render_initial_form

    assert_no_html(html, ".sandbox")
  end

  def test_renders_result_section_when_showing_result
    html = render_form_with_result(:sandbox_test.l)
    assert_html(html, ".sandbox")
    assert_html(html, "body", text: "#{:sandbox_look_like.t}:")
  end

  def test_renders_rendered_html_when_test_button_clicked
    html = render_form_with_result(:sandbox_test.l)
    assert_html(html, ".sandbox", text: "test code")
  end

  def test_renders_textile_as_actual_html_not_escaped
    # Verify Textile markup renders as actual HTML elements
    model = FormObject::TextileSandbox.new(code: "# Woof\n# Bark\n# Meow")
    form = Components::TextileSandboxForm.new(
      model,
      show_result: true,
      submit_type: :sandbox_test.l
    )
    html = render(form)

    # Should contain actual HTML list elements
    assert_html(html, ".sandbox ol")
    assert_html(html, ".sandbox li", count: 3)

    # Verify individual list items contain correct text
    assert_html(html, ".sandbox li", text: "Woof")
    assert_html(html, ".sandbox li", text: "Bark")
    assert_html(html, ".sandbox li", text: "Meow")

    # Should NOT contain escaped HTML in the rendered output
    assert_no_match(/&lt;/, html)
  end

  def test_renders_escaped_html_when_test_codes_button_clicked
    html = render_form_with_result(:sandbox_test_codes.l)
    # Should contain <code> tag with escaped HTML
    assert_html(html, "code")
    # The actual escaped content will be present
    assert_match(/test code/, html)
  end

  def test_renders_html_codes_with_proper_escaping
    # Test with actual Textile markup to verify HTML is escaped once
    model = FormObject::TextileSandbox.new(code: "# Woof\n# Bark\n# Meow")
    form = Components::TextileSandboxForm.new(
      model,
      show_result: true,
      submit_type: :sandbox_test_codes.l
    )
    html = render(form)

    # Should contain HTML tags escaped once (not double-escaped)
    assert_match(/&lt;div class=&quot;textile&quot;&gt;/, html)
    assert_match(/&lt;ol&gt;/, html)
    assert_match(%r{&lt;li&gt;Woof&lt;/li&gt;}, html)

    # Should NOT contain double-escaped HTML
    assert_no_match(/&amp;lt;/, html)
    assert_no_match(/&amp;quot;/, html)
  end

  def test_renders_up_arrows_when_showing_result
    html = render_form_with_result(:sandbox_test.l)
    assert_html(html, ".sandbox-up-ptr")
    assert_html(html, "img[src*='up_arrow']", count: 2)
  end

  def test_renders_both_submit_buttons_when_showing_result
    html = render_form_with_result(:sandbox_test.l)
    assert_html(html, "input[type='submit'][value='#{:sandbox_test.l}']")
    assert_html(html,
                "input[type='submit'][value='#{:sandbox_test_codes.l}']")
  end

  def test_does_not_render_submit_button_below_textarea_when_showing_result
    html = render_form_with_result(:sandbox_test.l)

    # Count submit buttons - should be 2 (in up arrows section only)
    assert_html(html, "input[type='submit']", count: 2)
  end

  def test_renders_quick_reference_section
    html = render_initial_form
    assert_html(html, "body", text: "#{:sandbox_quick_ref.t}:")
    assert_html(html, "pre")
  end

  def test_renders_quick_reference_with_html_entities
    html = render_initial_form
    # Should contain raw HTML entities from the translation
    assert_match(/&micro;/, html)
    assert_match(/&deg;/, html)
  end

  def test_renders_more_help_section
    html = render_initial_form
    assert_html(html, "body", text: "#{:sandbox_more_help.t}:")
  end

  def test_renders_mo_flavored_textile_link
    html = render_initial_form
    assert_html(html,
                "a[href*='docs.google.com/document']" \
                "[target='_blank'][rel='noopener noreferrer']",
                text: "MO Flavored Textile")
  end

  def test_renders_web_references_section
    html = render_initial_form
    assert_html(html, "body", text: "#{:sandbox_web_refs.t}:")
  end

  def test_renders_hobix_textile_reference_link
    html = render_initial_form
    assert_html(html,
                "a[href='https://hobix.com/textile']" \
                "[target='_blank'][rel='noopener noreferrer']")
    assert_html(html, "body",
                text: :sandbox_link_hobix_textile_reference.t)
  end

  def test_renders_hobix_textile_cheatsheet_link
    html = render_initial_form
    assert_html(html,
                "a[href='https://hobix.com/quick']" \
                "[target='_blank'][rel='noopener noreferrer']")
    assert_html(html, "body",
                text: :sandbox_link_hobix_textile_cheatsheet.t)
  end

  def test_renders_textile_language_website_link
    html = render_initial_form
    assert_html(html,
                "a[href='https://textile-lang.com/']" \
                "[target='_blank'][rel='noopener noreferrer']")
    assert_html(html, "body",
                text: :sandbox_link_textile_language_website.t)
  end

  def test_form_action_points_to_textile_sandbox
    html = render_initial_form
    assert_html(html, "form[action='/info/textile_sandbox']")
  end

  def test_form_uses_post_method
    html = render_initial_form
    assert_html(html, "form[method='post']")
  end

  private

  def render_initial_form
    model = FormObject::TextileSandbox.new(code: nil)
    form = Components::TextileSandboxForm.new(
      model,
      show_result: false,
      submit_type: nil
    )
    render(form)
  end

  def render_form_with_result(submit_type)
    model = FormObject::TextileSandbox.new(code: "test code")
    form = Components::TextileSandboxForm.new(
      model,
      show_result: true,
      submit_type: submit_type
    )
    render(form)
  end
end
