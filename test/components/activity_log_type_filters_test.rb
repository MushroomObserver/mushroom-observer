# frozen_string_literal: true

require "test_helper"

class ActivityLogTypeFiltersTest < ComponentTestCase
  def test_renders_form_with_get_method
    html = render_component(nil, ["all"])

    assert_html(html, "form[method='get']")
    assert_html(html, "form[action='/activity_logs']")
    assert_html(html, "form#log_filter_form")
    assert_html(html, "form.filter-form")
  end

  def test_renders_show_label
    html = render_component(nil, ["all"])

    assert_html(html, "span.btn.btn-default.btn-sm.disabled",
                text: :rss_show.t)
  end

  def test_renders_everything_button_active_when_all_types
    html = render_component(nil, ["all"])

    # When all types, everything button should be active (no link)
    assert_html(html, "span.btn.btn-default.btn-sm.active", text: :rss_all.t)
  end

  def test_renders_everything_button_as_link_when_not_all
    html = render_component(nil, ["observation"])

    # When not all types, everything button should have a link
    assert_html(html, "span.btn.btn-default.btn-sm a.filter-only",
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
      assert_html(html, "label.btn.btn-default.btn-sm.filter-checkbox")
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

  def test_active_class_on_single_selected_type
    html = render_component(nil, ["observation"])

    # The observation label should have active class
    assert_html(html, "label.active:has(input[value='observation'])")

    # The name label should NOT have active class
    assert_html(html, "label:not(.active):has(input[value='name'])")
  end

  def test_type_filter_link_present_when_not_selected
    html = render_component(nil, ["observation"])

    # Name filter should have a link (since it's not the only selected type)
    assert_html(html, "label a.filter-only[href*='type']",
                text: :rss_one_name.t)
  end

  def test_renders_submit_button
    html = render_component(nil, ["all"])

    assert_html(html,
                "input[type='submit'][value='#{:SUBMIT.t}'].btn.btn-default")
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
    component = Components::ActivityLogTypeFilters.new(query:, types:)
    render(component)
  end
end
