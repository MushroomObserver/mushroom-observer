# frozen_string_literal: true

require("test_helper")

class HelpTooltipTest < ComponentTestCase
  def test_renders_span_with_context_help_class_and_tooltip_data
    html = render(Components::Help::Tooltip.new(
                    label: "(?)", title: "Click for explanation"
                  ))

    assert_html(html, "span.context-help", text: "(?)")
    # Tooltip wiring: tooltip_controller.js reads `data-trigger` to
    # find triggers and `title=` for the popup text.
    assert_html(html, "span[title='Click for explanation']")
    assert_html(html, "span[data-trigger='tooltip']")
  end

  def test_extra_class_appends_to_context_help
    html = render(Components::Help::Tooltip.new(
                    label: "(?)", extra_class: "filter-help"
                  ))

    assert_html(html, "span.context-help.filter-help")
  end

  def test_caller_data_attrs_merge_with_tooltip_data
    html = render(Components::Help::Tooltip.new(
                    label: "(?)", data: { other: "v" }
                  ))

    # Caller's custom data attrs deep-merge with the tooltip
    # wiring — both end up on the span.
    assert_html(html, "span[data-trigger='tooltip']")
    assert_html(html, "span[data-other='v']")
  end
end
