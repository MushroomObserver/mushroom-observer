# frozen_string_literal: true

require "test_helper"

class Components::ObservationListManagerTest < ComponentTestCase
  def test_renders_both_sections_with_remove_and_add_flags
    html = render_manager(belongs_to: %w[Alpha], not_contains: %w[Beta])

    assert_html(html, "p", text: "row:Alpha:remove")
    assert_html(html, "p", text: "row:Beta:add")
  end

  def test_omits_belongs_to_section_when_empty
    html = render_manager(belongs_to: [], not_contains: %w[Beta])

    assert_no_html(html, "p", text: "row:Alpha:remove")
    assert_html(html, "p", text: "row:Beta:add")
  end

  def test_omits_not_contains_section_when_empty
    html = render_manager(belongs_to: %w[Alpha], not_contains: [])

    assert_html(html, "p", text: "row:Alpha:remove")
    assert_no_html(html, "p", text: "row:Beta:add")
  end

  def test_renders_nothing_when_both_empty
    html = render_manager(belongs_to: [], not_contains: [])

    assert_no_html(html, "p")
  end

  private

  def render_manager(belongs_to:, not_contains:)
    render(ManagerTestHost.new(belongs_to: belongs_to,
                               not_contains: not_contains))
  end
end

# Renders the manager inside a Phlex view so the yielded block's
# `self` is a Phlex component and `p`/`plain` resolve to the buffer
# the manager is writing to (matches `RowModeTestHost` in
# table_test.rb).
class ManagerTestHost < Components::Base
  def initialize(belongs_to:, not_contains:)
    super()
    @belongs_to = belongs_to
    @not_contains = not_contains
  end

  def view_template
    render(Components::ObservationListManager.new(
             belongs_to_heading: "Belongs to",
             belongs_to_items: @belongs_to,
             not_contains_heading: "Does not contain",
             not_contains_items: @not_contains
           )) do |items, _heading, remove, _add|
      p { plain("row:#{items.join(",")}:#{remove ? "remove" : "add"}") }
    end
  end
end
