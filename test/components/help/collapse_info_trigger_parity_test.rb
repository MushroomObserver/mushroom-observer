# frozen_string_literal: true

require("test_helper")

# Old `CollapseInfoTrigger` rendered a hand-rolled `<a>` with collapse
# attributes set explicitly. After this PR it delegates to
# `Link::CollapseToggle`, which manages the same attributes and adds
# the Bootstrap `.collapsed` class the old code omitted.
class OldCollapseInfoTrigger < Components::Base
  prop :target_id, String
  prop :extra_class, String, default: ""

  def view_template
    a(
      href: "##{@target_id}",
      class: class_names("info-collapse-trigger", @extra_class),
      role: "button",
      data: { toggle: "collapse" },
      aria: { expanded: "false", controls: @target_id }
    ) do
      render(::Components::Icon.new(type: :question))
    end
  end
end

class Components::Help::CollapseInfoTriggerParityTest < ComponentTestCase
  def test_parity
    old_html = render(OldCollapseInfoTrigger.new(
                        target_id: "help_text_1"
                      ))
    new_html = render(Components::Help::CollapseInfoTrigger.new(
                        target_id: "help_text_1"
                      ))

    # Behavioral wiring preserved in both.
    [old_html, new_html].each do |html|
      assert_html(html, "a[href='#help_text_1']" \
                        "[role='button']" \
                        "[data-toggle='collapse']" \
                        "[aria-expanded='false']" \
                        "[aria-controls='help_text_1']")
    end

    # Old had no .collapsed — the help pane starts hidden but Bootstrap
    # `.collapsed` was never added. New adds it via the component default.
    assert_html(old_html, "a.info-collapse-trigger")
    assert_no_html(old_html, "a.collapsed")
    assert_html(new_html, "a.info-collapse-trigger.collapsed")

    # Icon subtree identical.
    assert_html_element_equivalent(
      old_html, new_html,
      selector: "span.glyphicon",
      label: "collapse_info_trigger_icon"
    )
  end

  def test_parity_with_extra_class
    old_html = render(OldCollapseInfoTrigger.new(
                        target_id: "custom_target",
                        extra_class: "my-trigger"
                      ))
    new_html = render(Components::Help::CollapseInfoTrigger.new(
                        target_id: "custom_target",
                        extra_class: "my-trigger"
                      ))

    [old_html, new_html].each do |html|
      assert_html(html, "a[href='#custom_target']" \
                        "[data-toggle='collapse']" \
                        "[aria-controls='custom_target']")
      assert_html(html, "a.info-collapse-trigger.my-trigger")
    end

    assert_no_html(old_html, "a.collapsed")
    assert_html(new_html, "a.collapsed")
  end
end
