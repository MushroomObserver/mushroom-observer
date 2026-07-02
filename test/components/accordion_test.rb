# frozen_string_literal: true

require("test_helper")

# Tests for Components::Accordion — the Bootstrap 3 two-peer-collapse
# component where exactly one pane is visible at a time.
class AccordionTest < ComponentTestCase
  def test_renders_accordion_shell_with_both_panes
    html = render_accordion do |a|
      a.with_view { "VIEW_CONTENT" }
      a.with_edit { "EDIT_CONTENT" }
    end

    assert_html(html, "div.border-none.mb-0#notes_42")
    assert_html(html, "#notes_42 div.panel.border-none.bg-none")
    # View pane is shown by default (`in`); edit pane is hidden.
    assert_html(html,
                "#view_notes_42_container.collapse.in",
                text: "VIEW_CONTENT")
    assert_html(html,
                "#edit_notes_42_container.collapse",
                text: "EDIT_CONTENT")
    assert_no_html(html, "#edit_notes_42_container.in")
  end

  def test_renders_panes_with_no_inner_content
    html = render_accordion

    assert_html(html, "#view_notes_42_container")
    assert_html(html, "#edit_notes_42_container")
    # Both pane divs render even when slots aren't given.
    assert_no_html(html, "#view_notes_42_container *")
    assert_no_html(html, "#edit_notes_42_container *")
  end

  def test_no_background_so_striped_rows_show_through
    html = render_accordion { |a| a.with_view { "x" } }

    assert_html(html, "div.panel.bg-none")
  end

  private

  def render_accordion(&block)
    render(Components::Accordion.new(
             id: "notes_42",
             view_id: "view_notes_42_container",
             edit_id: "edit_notes_42_container"
           ), &block)
  end
end
