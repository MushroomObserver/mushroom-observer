# frozen_string_literal: true

require("test_helper")

# Pre-refactor legend toggle in
# `Views::Controllers::Contributors::Index::Legend`.
# Old: `Components::Button` with a block (a `<button>`).
# New: `Link::CollapseToggle` (an `<a role="button">`).
class OldLegendToggle < Components::Base
  def view_template
    render(::Components::Button.new(
             variant: :btn_link, size: :xs,
             data: { toggle: "collapse",
                     target: "#contribution_legend" },
             aria: { expanded: "false",
                     controls: "contribution_legend" }
           )) do
      render(::Components::Icon.new(type: :info_circle))
    end
  end
end

# Documents the migration of the legend toggle in
# `Views::Controllers::Contributors::Index::Legend` to
# `Link::CollapseToggle`.
#
# Intentional change: element type `<button>` → `<a role="button">`,
# and `data-target` → `href`. Collapse wiring and icon are preserved.
module Views::Controllers::Contributors
  class Index::LegendParityTest < ComponentTestCase
    def test_legend_toggle_preserves_behavioral_wiring
      old_html = render(OldLegendToggle.new)
      new_html = render(Components::Link::CollapseToggle.new(
                          target_id: "contribution_legend",
                          icon: :info_circle,
                          button: :btn_link,
                          size: :xs
                        ))

      # Collapse wiring + ARIA in both.
      assert_html(old_html,
                  "button[data-toggle='collapse']" \
                  "[aria-controls='contribution_legend']" \
                  "[aria-expanded='false']")
      assert_html(new_html,
                  "a[data-toggle='collapse']" \
                  "[aria-controls='contribution_legend']" \
                  "[aria-expanded='false']")

      # Info-circle icon subtree is identical (no title in either).
      assert_html(old_html, "span.glyphicon-info-sign")
      assert_html(new_html, "span.glyphicon-info-sign")
      assert_html_element_equivalent(old_html, new_html,
                                     selector: "span.glyphicon",
                                     label: "legend_icon")

      # Intentional change: element type and collapse pointer.
      assert_html(old_html,
                  "button[data-target='#contribution_legend']")
      assert_html(new_html,
                  "a[href='#contribution_legend'][role='button']")
      assert_no_html(new_html, "button")
    end
  end
end
