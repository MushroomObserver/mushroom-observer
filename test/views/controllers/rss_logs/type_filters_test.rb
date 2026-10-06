# frozen_string_literal: true

require "test_helper"

module Views::Controllers::RssLogs
  class TypeFiltersTest < ComponentTestCase
    # ---- Two forms, one per breakpoint ----

    def test_renders_both_forms
      html = render_component(nil, ["all"])

      assert_html(html, "form#log_filter_form_dropdown_top" \
                        "[method='get'][action='/activity_logs']" \
                        ".filter-form.filter-form-dropdown" \
                        "[data-turbo='false']")
      assert_html(html, "form#log_filter_form_bar_top" \
                        "[method='get'][action='/activity_logs']" \
                        ".filter-form.filter-form-bar" \
                        "[data-turbo='false']")
    end

    def test_position_suffixes_form_ids
      html = render_component(nil, ["all"], position: :bottom)

      assert_html(html, "form#log_filter_form_dropdown_bottom")
      assert_html(html, "form#log_filter_form_bar_bottom")
      assert_no_html(html, "#log_filter_form_dropdown_top")
      assert_no_html(html, "#log_filter_form_bar_top")
    end

    def test_renders_hidden_fields_in_both_forms
      html = render_component(nil, ["all"])

      assert_html(
        html, "#log_filter_form_dropdown_top " \
              "input[type='hidden'][name='_method'][value='patch']"
      )
      assert_html(
        html, "#log_filter_form_dropdown_top " \
              "input[type='hidden'][name='authenticity_token']"
      )
      assert_html(
        html, "#log_filter_form_dropdown_top " \
              "input[type='hidden'][name='back'][value='rss_logs']"
      )
      assert_html(
        html, "#log_filter_form_bar_top " \
              "input[type='hidden'][name='_method'][value='patch']"
      )
    end

    # ---- Bar (xl+) ----

    def test_bar_renders_show_label
      html = render_component(nil, ["all"])

      assert_html(html, "#log_filter_form_bar_top span", text: :rss_show.t)
    end

    def test_bar_renders_everything_active_when_all_types
      html = render_component(nil, ["all"])

      assert_html(html, "#log_filter_form_bar_top span.active",
                  text: :rss_all.t)
    end

    def test_bar_renders_everything_as_link_when_not_all
      html = render_component(nil, ["observation"])

      assert_html(html, "#log_filter_form_bar_top a.filter-only",
                  text: :rss_all.t)
    end

    def test_bar_renders_checkbox_for_each_type
      html = render_component(nil, ["all"])

      RssLog::ALL_TYPE_TAGS.each do |type|
        type_str = type.to_s
        assert_html(html, "#log_filter_form_bar_top " \
                          "input[type='checkbox'][name='q[types][]']" \
                          "[value='#{type_str}'][id='type_#{type_str}_top']")
      end
    end

    def test_bar_checkboxes_checked_when_all_types
      html = render_component(nil, ["all"])

      RssLog::ALL_TYPE_TAGS.each do |type|
        assert_html(html, "#log_filter_form_bar_top " \
                          "input[type='checkbox'][value='#{type}'][checked]")
      end
    end

    def test_bar_only_selected_type_checked
      html = render_component(nil, ["observation"])

      assert_html(html, "#log_filter_form_bar_top input[type='checkbox']" \
                        "[value='observation'][checked]")
      assert_no_html(html, "#log_filter_form_bar_top input[type='checkbox']" \
                           "[value='name'][checked]")
    end

    def test_bar_type_filter_link_present_when_not_selected
      html = render_component(nil, ["observation"])

      assert_html(html, "#log_filter_form_bar_top a.filter-only[href*='types']",
                  text: :rss_one_name.t)
    end

    def test_bar_renders_submit_button
      html = render_component(nil, ["all"])

      assert_html(html, "#log_filter_form_bar_top button[type='submit']",
                  text: :apply.ti)
    end

    def test_bar_no_save_default_button_without_user
      html = render_component(nil, ["observation"])

      assert_no_html(html, "#log_filter_form_bar_top button[formaction]")
    end

    def test_bar_no_save_default_button_when_types_match_default
      user = users(:rolf)
      user.update!(default_rss_type: "observation")

      html = render_component(nil, ["observation"], user: user)

      assert_no_html(html, "#log_filter_form_bar_top button[formaction]")
    end

    def test_bar_save_default_button_when_types_differ_from_default
      user = users(:rolf)
      user.update!(default_rss_type: "all")

      html = render_component(nil, ["observation"], user: user)

      assert_html(
        html,
        "#log_filter_form_bar_top button[type='submit']" \
        "[formaction='#{routes.account_preferences_path}']" \
        "[formmethod='post'][data-turbo='true']",
        text: :rss_make_default.t
      )
    end

    # ---- Dropdown (below the 1500px cutoff) ----

    def test_dropdown_toggle_label_all
      html = render_component(nil, ["all"])

      assert_html(html, "#log_filter_toggle_top", text: :rss_all.t)
    end

    def test_dropdown_toggle_label_single_type
      html = render_component(nil, ["observation"])

      assert_html(html, "#log_filter_toggle_top", text: :rss_one_observation.t)
    end

    def test_dropdown_toggle_label_multiple_types
      html = render_component(nil, %w[observation name])

      assert_html(html, "#log_filter_toggle_top", text: :rss_selected.t)
    end

    def test_dropdown_menu_has_no_leading_spacer
      html = render_component(nil, ["all"])

      assert_no_html(html, "#log_filter_menu_top .dropdown-item.disabled")
    end

    def test_dropdown_renders_everything_row
      html = render_component(nil, ["all"])

      assert_html(html, "#log_filter_menu_top .dropdown-item.active",
                  text: :rss_all.t)
    end

    def test_dropdown_renders_checkbox_for_each_type
      html = render_component(nil, ["all"])

      RssLog::ALL_TYPE_TAGS.each do |type|
        type_str = type.to_s
        assert_html(
          html, "#log_filter_menu_top " \
                "input[type='checkbox'][name='q[types][]']" \
                "[value='#{type_str}'][id='type_#{type_str}_dropdown_top']"
        )
      end
    end

    def test_dropdown_only_selected_type_checked
      html = render_component(nil, ["observation"])

      assert_html(html, "#log_filter_menu_top input[type='checkbox']" \
                        "[value='observation'][checked]")
      assert_no_html(html, "#log_filter_menu_top input[type='checkbox']" \
                           "[value='name'][checked]")
    end

    def test_dropdown_type_filter_link_present_when_not_selected
      html = render_component(nil, ["observation"])

      assert_html(
        html, "#log_filter_menu_top .label-zone a.filter-only[href*='types']",
        text: :rss_one_name.t
      )
    end

    def test_dropdown_renders_submit_button
      html = render_component(nil, ["all"])

      assert_html(html, "#log_filter_menu_top button[type='submit']",
                  text: :apply.ti)
    end

    def test_dropdown_no_save_default_row_without_user
      html = render_component(nil, ["observation"])

      assert_no_html(html, "#log_filter_menu_top button[formaction]")
    end

    def test_dropdown_save_default_row_when_types_differ_from_default
      user = users(:rolf)
      user.update!(default_rss_type: "all")

      html = render_component(nil, ["observation"], user: user)

      assert_html(
        html,
        "#log_filter_menu_top button[type='submit']" \
        "[formaction='#{routes.account_preferences_path}']" \
        "[formmethod='post'][data-turbo='true']",
        text: :rss_make_default.t
      )
    end

    def test_dropdown_position_suffixes_menu_and_toggle_ids
      html = render_component(nil, ["all"], position: :bottom)

      assert_html(html, "#log_filter_toggle_bottom")
      assert_html(html, "#log_filter_menu_bottom")
      assert_no_html(html, "#log_filter_toggle_top")
      assert_no_html(html, "#log_filter_menu_top")
    end

    private

    def render_component(query, types, user: nil, position: :top)
      component = TypeFilters.new(query:, types:, user:, position:)
      render(component)
    end
  end
end
