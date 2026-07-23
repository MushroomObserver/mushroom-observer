# frozen_string_literal: true

require("test_helper")

# Tests for Components::Accordion — the Bootstrap 3 multi-pane collapse
# component where exactly one pane is visible at a time.
class AccordionTest < ComponentTestCase
  def test_renders_accordion_shell_with_two_panes
    html = render_accordion do |a|
      a.with_pane(id: "view_42", expanded: true) { "VIEW_CONTENT" }
      a.with_pane(id: "edit_42") { "EDIT_CONTENT" }
    end

    assert_html(html, "div.border-none.mb-0#notes_42")
    assert_html(html, "#notes_42 div.panel.border-none.bg-none")
    assert_html(html, "#view_42.collapse.in", text: "VIEW_CONTENT")
    assert_html(html, "#edit_42.collapse", text: "EDIT_CONTENT")
    assert_no_html(html, "#edit_42.in")
  end

  def test_renders_pane_with_no_inner_block
    html = render_accordion do |a|
      a.with_pane(id: "view_42", expanded: true)
    end

    assert_html(html, "#view_42.collapse.in")
    assert_no_html(html, "#view_42 *")
  end

  def test_no_background_so_striped_rows_show_through
    html = render_accordion { |a| a.with_pane(id: "p") { "x" } }

    assert_html(html, "div.panel.bg-none")
  end

  def test_panes_fade_by_default
    html = render_accordion { |a| a.with_pane(id: "p") { "x" } }

    assert_html(html, "#p.fade-not-slide")
  end

  def test_slide_true_uses_bootstraps_default_transition
    html = render(
      Components::Accordion.new(id: "notes_42", slide: true)
    ) { |a| a.with_pane(id: "p") { "x" } }

    assert_no_html(html, "#p.fade-not-slide")
  end

  def test_extra_class_merges_onto_inner_panel_div
    html = render(
      Components::Accordion.new(id: "notes_42", class: "m-0")
    ) { |a| a.with_pane(id: "p") { "x" } }

    assert_html(html, "div.panel.border-none.bg-none.m-0")
  end

  def test_extra_data_attrs_merge_onto_inner_panel_div
    html = render(
      Components::Accordion.new(id: "notes_42", data: { foo: "bar" })
    ) { |a| a.with_pane(id: "p") { "x" } }

    assert_html(html, "#notes_42 div.panel[data-foo='bar']")
  end

  private

  def render_accordion(&block)
    render(Components::Accordion.new(id: "notes_42"), &block)
  end
end
