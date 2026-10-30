# frozen_string_literal: true

require "test_helper"

module Components
  class TypeFiltersTest < ComponentTestCase
    # ---- multiple: true (Activity Logs) ----
    # ---- Two forms, one per breakpoint ----

    def test_renders_both_forms
      html = render_multi(nil, ["all"])

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
      html = render_multi(nil, ["all"], position: :bottom)

      assert_html(html, "form#log_filter_form_dropdown_bottom")
      assert_html(html, "form#log_filter_form_bar_bottom")
      assert_no_html(html, "#log_filter_form_dropdown_top")
      assert_no_html(html, "#log_filter_form_bar_top")
    end

    def test_renders_hidden_fields_in_both_forms
      html = render_multi(nil, ["all"])

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

    def test_renders_hidden_fields_for_other_active_query_filters
      log = rss_logs(:minimal_unknown_obs_rss_log)
      query = Query.lookup(:RssLog, types: ["observation"],
                                    id_in_set: [log.id])
      html = render_multi(query, ["observation"])

      # :types must not round-trip as a hidden field -- the visible
      # checkboxes/links already control it.
      assert_no_html(html, "#log_filter_form_dropdown_top " \
                           "input[name='q[types]']")
      assert_no_html(html, "#log_filter_form_dropdown_top " \
                           "input[name='q[type]']")
      assert_html(
        html, "#log_filter_form_dropdown_top " \
              "input[type='hidden'][name='q[id_in_set]'][value='#{log.id}']"
      )
    end

    def test_renders_hidden_fields_for_multi_value_query_filter
      log1 = rss_logs(:minimal_unknown_obs_rss_log)
      log2 = rss_logs(:detailed_unknown_obs_rss_log)
      query = Query.lookup(:RssLog, types: ["observation"],
                                    id_in_set: [log1.id, log2.id])
      html = render_multi(query, ["observation"])

      # A multi-value filter stays an Array after index_filter -- each
      # value needs a separate "[]"-named hidden input so params
      # round-trip as an array instead of overwriting each other.
      assert_html(
        html, "#log_filter_form_dropdown_top " \
              "input[type='hidden'][name='q[id_in_set][]'][value='#{log1.id}']"
      )
      assert_html(
        html, "#log_filter_form_dropdown_top " \
              "input[type='hidden'][name='q[id_in_set][]'][value='#{log2.id}']"
      )
    end

    # ---- Bar (xl+) ----

    def test_bar_renders_show_label
      html = render_multi(nil, ["all"])

      assert_html(html, "#log_filter_form_bar_top span", text: :rss_show.t)
    end

    def test_bar_renders_everything_active_when_all_types
      html = render_multi(nil, ["all"])

      assert_html(html, "#log_filter_form_bar_top .active",
                  text: :rss_all.t)
    end

    def test_bar_renders_everything_as_link_when_not_all
      html = render_multi(nil, ["observation"])

      assert_html(html, "#log_filter_form_bar_top a.filter-only",
                  text: :rss_all.t)
    end

    def test_bar_renders_checkbox_for_each_type
      html = render_multi(nil, ["all"])

      RssLog::ALL_TYPE_TAGS.each do |type|
        type_str = type.to_s
        assert_html(html, "#log_filter_form_bar_top " \
                          "input[type='checkbox'][name='q[types][]']" \
                          "[value='#{type_str}'][id='type_#{type_str}_top']" \
                          "[aria-label='#{:"rss_one_#{type}".t}']")
      end
    end

    def test_bar_checkboxes_checked_when_all_types
      html = render_multi(nil, ["all"])

      RssLog::ALL_TYPE_TAGS.each do |type|
        assert_html(html, "#log_filter_form_bar_top " \
                          "input[type='checkbox'][value='#{type}'][checked]")
      end
    end

    def test_bar_only_selected_type_checked
      html = render_multi(nil, ["observation"])

      assert_html(html, "#log_filter_form_bar_top input[type='checkbox']" \
                        "[value='observation'][checked]")
      assert_no_html(html, "#log_filter_form_bar_top input[type='checkbox']" \
                           "[value='name'][checked]")
    end

    def test_bar_type_filter_link_present_when_not_selected
      html = render_multi(nil, ["observation"])

      assert_html(html, "#log_filter_form_bar_top a.filter-only[href*='types']",
                  text: :rss_one_name.t)
    end

    def test_bar_renders_submit_button
      html = render_multi(nil, ["all"])

      assert_html(html, "#log_filter_form_bar_top button[type='submit']",
                  text: :apply.ti)
    end

    def test_bar_no_save_default_button_without_user
      html = render_multi(nil, ["observation"])

      assert_no_html(html, "#log_filter_form_bar_top button[formaction]")
    end

    def test_bar_no_save_default_button_when_types_match_default
      user = users(:rolf)
      user.update!(default_rss_type: "observation")

      html = render_multi(nil, ["observation"], user: user)

      assert_no_html(html, "#log_filter_form_bar_top button[formaction]")
    end

    def test_bar_save_default_button_when_types_differ_from_default
      user = users(:rolf)
      user.update!(default_rss_type: "all")

      html = render_multi(nil, ["observation"], user: user)

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
      html = render_multi(nil, ["all"])

      assert_html(html, "#log_filter_toggle_top", text: :rss_all.t)
    end

    def test_dropdown_toggle_label_single_type
      html = render_multi(nil, ["observation"])

      assert_html(html, "#log_filter_toggle_top", text: :rss_one_observation.t)
    end

    def test_dropdown_toggle_label_multiple_types
      html = render_multi(nil, %w[observation name])

      assert_html(html, "#log_filter_toggle_top", text: :rss_selected.t)
    end

    # RssLogsController's sentinel for "no valid type survived" --
    # has no `rss_one_none` tag, so it must not hit that branch.
    def test_dropdown_toggle_label_none
      html = render_multi(nil, ["none"])

      assert_html(html, "#log_filter_toggle_top", text: :rss_selected.t)
    end

    def test_dropdown_menu_has_no_leading_spacer
      html = render_multi(nil, ["all"])

      assert_html(html, "#log_filter_menu_top .dropdown-item:first-child",
                  text: :rss_all.t)
    end

    def test_dropdown_apply_starts_disabled
      html = render_multi(nil, ["all"])

      assert_html(
        html, "#log_filter_menu_top button[type='submit'][disabled]" \
              "[data-type-filters-target='submit']"
      )
      assert_html(
        html, "#log_filter_menu_top " \
              "div[data-type-filters-target='submitItem'].disabled"
      )
    end

    def test_dropdown_checkbox_has_type_filters_target
      html = render_multi(nil, ["all"])

      assert_html(
        html, "#log_filter_menu_top " \
              "input[type='checkbox'][value='observation']" \
              "[data-type-filters-target='checkbox']"
      )
    end

    def test_dropdown_renders_everything_row
      html = render_multi(nil, ["all"])

      assert_html(html, "#log_filter_menu_top .dropdown-item.active",
                  text: :rss_all.t)
    end

    def test_dropdown_renders_checkbox_for_each_type
      html = render_multi(nil, ["all"])

      RssLog::ALL_TYPE_TAGS.each do |type|
        type_str = type.to_s
        assert_html(
          html, "#log_filter_menu_top " \
                "input[type='checkbox'][name='q[types][]']" \
                "[value='#{type_str}'][id='type_#{type_str}_dropdown_top']" \
                "[aria-label='#{:"rss_one_#{type}".t}']"
        )
      end
    end

    def test_dropdown_only_selected_type_checked
      html = render_multi(nil, ["observation"])

      assert_html(html, "#log_filter_menu_top input[type='checkbox']" \
                        "[value='observation'][checked]")
      assert_no_html(html, "#log_filter_menu_top input[type='checkbox']" \
                           "[value='name'][checked]")
    end

    def test_dropdown_type_filter_link_present_when_not_selected
      html = render_multi(nil, ["observation"])

      assert_html(
        html, "#log_filter_menu_top .label-zone a.filter-only[href*='types']",
        text: :rss_one_name.t
      )
    end

    def test_dropdown_renders_submit_button
      html = render_multi(nil, ["all"])

      assert_html(html, "#log_filter_menu_top button[type='submit']",
                  text: :apply.ti)
    end

    def test_dropdown_no_save_default_row_without_user
      html = render_multi(nil, ["observation"])

      assert_no_html(html, "#log_filter_menu_top button[formaction]")
    end

    def test_dropdown_save_default_row_when_types_differ_from_default
      user = users(:rolf)
      user.update!(default_rss_type: "all")

      html = render_multi(nil, ["observation"], user: user)

      assert_html(
        html,
        "#log_filter_menu_top button[type='submit']" \
        "[formaction='#{routes.account_preferences_path}']" \
        "[formmethod='post'][data-turbo='true']",
        text: :rss_make_default.t
      )
    end

    def test_dropdown_position_suffixes_menu_and_toggle_ids
      html = render_multi(nil, ["all"], position: :bottom)

      assert_html(html, "#log_filter_toggle_bottom")
      assert_html(html, "#log_filter_menu_bottom")
      assert_no_html(html, "#log_filter_toggle_top")
      assert_no_html(html, "#log_filter_menu_top")
    end

    # ---- multiple: false (Interests) ----
    # ---- Bar (xl+) ----

    def test_single_bar_renders_show_label
      html = render_single(["all"])

      assert_html(html, ".filter-form-bar span", text: :rss_show.t)
    end

    def test_single_bar_everything_active_when_all
      html = render_single(["all"])

      assert_html(html, ".filter-form-bar .active", text: :rss_all.l)
    end

    def test_single_bar_active_item_has_no_link
      html = render_single(["Observation"])

      assert_html(html, ".filter-form-bar .active", text: "Observations")
      assert_no_html(html, ".filter-form-bar a[href*='type=observation']")
    end

    def test_single_bar_inactive_item_links_to_type
      html = render_single(["Observation"])

      assert_html(html, ".filter-form-bar a[href*='type=name']",
                  text: "Names")
    end

    def test_single_bar_no_checkboxes_or_submit
      html = render_single(["all"])

      assert_no_html(html, ".filter-form-bar input[type='checkbox']")
      assert_no_html(html, ".filter-form-bar button[type='submit']")
    end

    # ---- Dropdown (below the 1500px cutoff) ----

    def test_single_dropdown_toggle_label_all
      html = render_single(["all"])

      assert_html(html, "#type_filter_toggle_type_top", text: :rss_all.l)
    end

    def test_single_dropdown_toggle_label_selected_type
      html = render_single(["Observation"])

      assert_html(html, "#type_filter_toggle_type_top", text: "Observations")
    end

    def test_single_dropdown_active_item_has_no_link
      html = render_single(["Observation"])

      assert_html(html, ".dropdown-item.active", text: "Observations")
      assert_no_html(html, ".dropdown-item a[href*='type=observation']")
    end

    def test_single_dropdown_inactive_item_links_to_type
      html = render_single(["Observation"])

      assert_html(html, "a.dropdown-item[href*='type=name']", text: "Names")
    end

    def test_single_position_suffixes_toggle_id
      html = render_single(["all"], position: :bottom)

      assert_html(html, "#type_filter_toggle_type_bottom")
      assert_no_html(html, "#type_filter_toggle_type_top")
    end

    private

    def render_multi(query, types, user: nil, position: :top)
      render(TypeFilters.new(
               multiple: true, filterable_types: RssLog::ALL_TYPE_TAGS,
               query:, types:, user:, position:
             ))
    end

    def render_single(types, position: :top)
      render(TypeFilters.new(
               multiple: false,
               filterable_types: %w[Observation Name].map(&:to_sym),
               types:, position:,
               type_label: ->(type) { type.to_s.pluralize },
               path_for: lambda do |type|
                 type ? "/interests?type=#{type.to_s.downcase}" : "/interests"
               end
             ))
    end
  end
end
