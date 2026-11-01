# frozen_string_literal: true

require "test_helper"

class Components::ObservationListManagerTest < ComponentTestCase
  def test_renders_both_sections_with_remove_and_add_flags
    html = render_manager(belongs_to: %w[Alpha], not_contains: %w[Beta])

    assert_html(html, ".list-group", count: 2)
    assert_html(html, ".list-group-item", text: "row:Alpha:remove")
    assert_html(html, ".list-group-item", text: "row:Beta:add")
  end

  def test_omits_belongs_to_section_when_empty
    html = render_manager(belongs_to: [], not_contains: %w[Beta])

    assert_html(html, ".list-group", count: 1)
    assert_no_html(html, ".list-group-item", text: "row:Alpha:remove")
    assert_html(html, ".list-group-item", text: "row:Beta:add")
  end

  def test_omits_not_contains_section_when_empty
    html = render_manager(belongs_to: %w[Alpha], not_contains: [])

    assert_html(html, ".list-group", count: 1)
    assert_html(html, ".list-group-item", text: "row:Alpha:remove")
    assert_no_html(html, ".list-group-item", text: "row:Beta:add")
  end

  def test_renders_nothing_when_both_empty
    html = render_manager(belongs_to: [], not_contains: [])

    assert_no_html(html, ".list-group")
  end

  private

  def render_manager(belongs_to:, not_contains:)
    render(Components::ObservationListManager.new(
             belongs_to_heading: "Belongs to",
             belongs_to_items: belongs_to,
             not_contains_heading: "Does not contain",
             not_contains_items: not_contains
           )) do |item, remove, _add|
      "row:#{item}:#{remove ? "remove" : "add"}"
    end
  end
end
