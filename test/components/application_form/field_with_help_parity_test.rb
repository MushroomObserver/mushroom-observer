# frozen_string_literal: true

require("test_helper")

# Old `FieldWithHelp#render_help_icon` rendered a hand-rolled `<a>`
# inside a span wrapper. After this PR it delegates to
# `Link::CollapseToggle`. These components isolate the trigger HTML.
class OldHelpIcon < Components::Base
  def view_template
    span(class: "form-between") do
      a(
        href: "#test_field_help",
        class: "info-collapse-trigger",
        role: "button",
        data: { toggle: "collapse" },
        aria: { expanded: "false", controls: "test_field_help" }
      ) do
        render(::Components::Icon.new(type: :question))
      end
    end
  end
end

class NewHelpIcon < Components::Base
  def view_template
    span(class: "form-between") do
      render(::Components::Link::CollapseToggle.new(
               target_id: "test_field_help",
               class: "info-collapse-trigger"
             )) do
        render(::Components::Icon.new(type: :question))
      end
    end
  end
end

class Components::ApplicationForm::FieldWithHelpParityTest < ComponentTestCase
  def test_parity
    old_html = render(OldHelpIcon.new)
    new_html = render(NewHelpIcon.new)

    # Behavioral wiring preserved in both.
    [old_html, new_html].each do |html|
      assert_html(html, "a[href='#test_field_help']" \
                        "[role='button']" \
                        "[data-toggle='collapse']" \
                        "[aria-expanded='false']" \
                        "[aria-controls='test_field_help']")
      assert_html(html, "a.info-collapse-trigger")
    end

    # Old had no .collapsed — trigger started without Bootstrap's
    # closed-state class. New adds it via Link::CollapseToggle default.
    assert_no_html(old_html, "a.collapsed")
    assert_html(new_html, "a.info-collapse-trigger.collapsed")

    # Icon subtree identical.
    assert_html_element_equivalent(
      old_html, new_html,
      selector: "span.glyphicon",
      label: "field_with_help_icon"
    )
  end
end
