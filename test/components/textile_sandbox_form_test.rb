# frozen_string_literal: true

require "test_helper"

class TextileSandboxFormTest < ComponentTestCase
  # NOTE: Page title and help block are now rendered by the view
  # template (Views::Controllers::Info::TextileSandbox), not the
  # component. Those should be tested in controller/integration tests.

  def test_initial_form
    html = render_form(code: nil, show_result: false)

    # Textarea field
    assert_html(html, "textarea[name='textile_sandbox[code]']")
    assert_html(html, "textarea[id='textile_sandbox_code']")
    assert_html(html, "textarea[rows='8']")
    assert_html(html, "body", text: "#{:sandbox_enter.t}:")

    # Submit button (only Test button when no result)
    assert_html(html, "input[type='submit'][value='#{:sandbox_test.l}']")

    # No result section
    assert_no_html(html, ".sandbox")
    assert_no_html(html, ".sandbox-up-ptr")

    # Quick reference section
    assert_html(html, "body", text: "#{:sandbox_quick_ref.t}:")
    assert_html(html, "pre")
    assert_match(/&micro;/, html)
    assert_match(/&deg;/, html)

    # More help and web references
    assert_html(html, "body", text: "#{:sandbox_more_help.t}:")
    assert_html(html, "body", text: "#{:sandbox_web_refs.t}:")
    assert_html(html,
                "a[href*='docs.google.com/document']" \
                "[target='_blank'][rel='noopener noreferrer']",
                text: "MO Flavored Textile")
    assert_html(html,
                "a[href='https://hobix.com/textile']" \
                "[target='_blank'][rel='noopener noreferrer']")
    assert_html(html,
                "a[href='https://hobix.com/quick']" \
                "[target='_blank'][rel='noopener noreferrer']")
    assert_html(html,
                "a[href='https://textile-lang.com/']" \
                "[target='_blank'][rel='noopener noreferrer']")

    # Form attributes
    assert_html(html, "form[action='/info/textile_sandbox']")
    assert_html(html, "form[method='post']")
  end

  def test_form_with_result
    html = render_form(code: "test code", show_result: true,
                       submit_type: :sandbox_test.l)

    # Result section
    assert_html(html, ".sandbox")
    assert_html(html, "body", text: "#{:sandbox_look_like.t}:")
    assert_html(html, ".sandbox", text: "test code")

    # Up arrows and both submit buttons
    assert_html(html, ".sandbox-up-ptr")
    assert_html(html, "img[src*='up_arrow']", count: 2)
    assert_html(html, "input[type='submit'][value='#{:sandbox_test.l}']")
    assert_html(html, "input[type='submit'][value='#{:sandbox_test_codes.l}']")

    # Only 2 submit buttons (in up arrows section)
    assert_html(html, "input[type='submit']", count: 2)
  end

  def test_textile_renders_as_html
    html = render_form(code: "# Woof\n# Bark\n# Meow", show_result: true,
                       submit_type: :sandbox_test.l)

    # Should contain actual HTML list elements
    assert_html(html, ".sandbox ol")
    assert_html(html, ".sandbox li", count: 3)
    assert_html(html, ".sandbox li:nth-child(1)", text: "Woof")
    assert_html(html, ".sandbox li:nth-child(2)", text: "Bark")
    assert_html(html, ".sandbox li:nth-child(3)", text: "Meow")

    # Should NOT contain escaped HTML
    assert_no_match(/&lt;/, html)
  end

  def test_form_with_html_codes_result
    html = render_form(code: "# Woof\n# Bark\n# Meow", show_result: true,
                       submit_type: :sandbox_test_codes.l)

    # Should contain <code> tag with escaped HTML
    assert_html(html, "code")

    # HTML should be escaped once (not double-escaped)
    assert_match(/&lt;div class=&quot;textile&quot;&gt;/, html)
    assert_match(/&lt;ol&gt;/, html)
    assert_match(%r{&lt;li&gt;Woof&lt;/li&gt;}, html)

    # Should NOT contain double-escaped HTML
    assert_no_match(/&amp;lt;/, html)
    assert_no_match(/&amp;quot;/, html)
  end

  private

  def render_form(code:, show_result:, submit_type: nil)
    model = FormObject::TextileSandbox.new(code: code)
    render(Components::TextileSandboxForm.new(
             model,
             show_result: show_result,
             submit_type: submit_type
           ))
  end
end
