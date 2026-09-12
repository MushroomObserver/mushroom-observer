# frozen_string_literal: true

require("test_helper")

class HelpTooltipTest < ComponentTestCase
  def test_renders_span_with_context_help_class_and_tooltip_data
    html = render_tooltip(label: "(?)", title: "Click for explanation")

    assert_html(html, "span.context-help", text: "(?)")
    # Tooltip wiring: the tooltip Stimulus controller reads
    # `data-tooltip-target="tip"` to find triggers and activate
    # Bootstrap's tooltip plugin, which reads `title=` for the popup
    # text.
    assert_html(html, "span[title='Click for explanation']")
    assert_html(html, "span[data-tooltip-target='tip']")
  end

  def test_extra_class_appends_to_context_help
    html = render_tooltip(label: "(?)", extra_class: "filter-help")

    assert_html(html, "span.context-help.filter-help")
  end

  def test_caller_data_attrs_merge_with_tooltip_data
    html = render_tooltip(label: "(?)", data: { other: "v" })

    # Caller's custom data attrs deep-merge with the tooltip
    # wiring — both end up on the span.
    assert_html(html, "span[data-tooltip-target='tip']")
    assert_html(html, "span[data-other='v']")
  end

  private

  def render_tooltip(**)
    render(Components::Help::Tooltip.new(**))
  end
end
