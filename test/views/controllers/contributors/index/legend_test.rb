# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Contributors
  class Index::LegendTest < ComponentTestCase
    def test_renders_collapsible_panel_with_toggle
      html = render_legend

      assert_html(html, "#contribution_legend.collapse")
      assert_html(html, "strong",
                  text: :users_by_contribution_legend.l.as_displayed)
    end

    def test_toggle_link_wires_collapse_behavior
      html = render_legend

      assert_html(html,
                  "a[data-toggle='collapse']" \
                  "[href='#contribution_legend']" \
                  "[aria-controls='contribution_legend']" \
                  "[aria-expanded='false']")
      assert_html(html, "a[href='#contribution_legend'] span.glyphicon")
    end

    def test_renders_weights_table
      html = render_legend

      assert_html(html, "table")
      assert_html(html, "td", text: :users_by_contribution_2f.l.as_displayed)
    end

    private

    def render_legend
      render(Views::Controllers::Contributors::Index::Legend.new)
    end
  end
end
