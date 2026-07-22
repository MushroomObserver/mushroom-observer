# frozen_string_literal: true

require "test_helper"

module Views::Controllers::RssLogs
  class TypeFiltersTest < ComponentTestCase
    def test_renders_form_with_get_method
      html = render_component(nil, ["all"])

      assert_html(html, "form[method='get']")
      assert_html(html, "form[action='/activity_logs']")
      assert_html(html, "form#log_filter_form")
      assert_html(html, "form.filter-form")
    end

    def test_renders_show_label
      html = render_component(nil, ["all"])

      # Was styled as a disabled btn-default — misleading affordance.
      # Now a plain `text-muted` span: visibly a label, not a button.
      assert_html(html, "span.text-muted", text: :rss_show.t)
    end

    def test_renders_everything_button_active_when_all_types
      html = render_component(nil, ["all"])

      # When all types, everything button should be active (no link)
      assert_html(html, "span.btn.btn-outline-default.btn-sm.active",
                  text: :rss_all.t)
    end

    def test_renders_everything_button_as_link_when_not_all
      html = render_component(nil, ["observation"])

      # When not all types, everything button should have a link
      assert_html(html, "span.btn.btn-outline-default.btn-sm a.filter-only",
                  text: :rss_all.t)
    end

    def test_renders_checkbox_for_each_type
      html = render_component(nil, ["all"])

      RssLog::ALL_TYPE_TAGS.each do |type|
        type_str = type.to_s
        # Check checkbox input exists
        assert_html(html, "input[type='checkbox'][name='q[type][]']" \
                          "[value='#{type_str}'][id='type_#{type_str}']")
        # Check label exists
        assert_html(html,
                    "label.btn.btn-outline-default.btn-sm.filter-checkbox")
      end
    end

    def test_checkboxes_checked_when_all_types
      html = render_component(nil, ["all"])

      RssLog::ALL_TYPE_TAGS.each do |type|
        assert_html(html, "input[type='checkbox'][value='#{type}'][checked]")
      end
    end

    def test_only_selected_type_checked
      html = render_component(nil, ["observation"])

      # observation should be checked
      assert_html(html, "input[type='checkbox'][value='observation'][checked]")

      # name should exist but NOT be checked
      assert_html(html, "input[type='checkbox'][value='name']")
      assert_no_html(html, "input[type='checkbox'][value='name'][checked]")
    end

    def test_selected_type_checkbox_drives_active_state_via_css
      html = render_component(nil, ["observation"])

      # No server-side `.active` class anymore — the CSS rule
      # `.filter-checkbox:has(input[type="checkbox"]:checked)` paints
      # the "pressed" visual using theme-aware custom properties.
      # The structural check: selected type's checkbox is checked
      # inside a `.filter-checkbox` label; unselected isn't. CSS
      # handles the visual.
      assert_html(html,
                  "label.filter-checkbox " \
                  "input[type='checkbox'][value='observation'][checked]")
      assert_no_html(html,
                     "label.filter-checkbox " \
                     "input[type='checkbox'][value='name'][checked]")
    end

    def test_type_filter_link_present_when_not_selected
      html = render_component(nil, ["observation"])

      # Name filter should have a link (since it's not the only selected type)
      assert_html(html, "label a.filter-only[href*='type']",
                  text: :rss_one_name.t)
    end

    def test_renders_submit_button
      html = render_component(nil, ["all"])

      # "Apply" reads better than "Submit" for a filter-narrowing
      # action. Filter buttons use `.btn-outline-default` (subtle);
      # the Apply button uses solid `.btn-default` so it stands out
      # as the commit action.
      assert_html(html, "button[type='submit']", text: :apply.ti)
    end

    # NOTE: Testing with a real query requires the controller to have q_param
    # helper available. The integration test in rss_logs_controller_test.rb
    # covers the query param preservation functionality.

    def test_no_hidden_fields_without_query
      html = render_component(nil, ["all"])

      assert_html(html, "input[type='hidden']", count: 0)
    end

    private

    def render_component(query, types)
      component = TypeFilters.new(query:, types:)
      render(component)
    end
  end
end
