# frozen_string_literal: true

require "test_helper"

class MarkAsReviewedToggleTest < UnitTestCase
  include ComponentTestHelper

  def test_renders_with_default_parameters
    html = render_component(Components::MarkAsReviewedToggle.new(obs_id: 123))

    assert_includes(html, "caption_reviewed_toggle_123")
    assert_includes(html, "caption_reviewed_123")
    assert_includes(html, "observation_view")
    assert_includes(html, "Mark as reviewed")
  end

  def test_renders_with_custom_selector
    html = render_component(Components::MarkAsReviewedToggle.new(
                              obs_id: 456,
                              selector: "box_reviewed"
                            ))

    assert_includes(html, "box_reviewed_toggle_456")
    assert_includes(html, "box_reviewed_456")
  end

  def test_renders_with_label_class
    html = render_component(Components::MarkAsReviewedToggle.new(
                              obs_id: 789,
                              label_class: "stretched-link"
                            ))

    assert_includes(html, "stretched-link")
    assert_includes(html, "caption-reviewed-link")
  end

  def test_renders_with_reviewed_true
    html = render_component(Components::MarkAsReviewedToggle.new(
                              obs_id: 111,
                              reviewed: true
                            ))

    assert_includes(html, "Marked as reviewed")
    assert_includes(html, "checked")
  end

  def test_renders_with_reviewed_false
    html = render_component(Components::MarkAsReviewedToggle.new(
                              obs_id: 222,
                              reviewed: false
                            ))

    assert_includes(html, "Mark as reviewed")
    assert_not_includes(html, "checked")
  end

  def test_renders_with_reviewed_nil
    html = render_component(Components::MarkAsReviewedToggle.new(
                              obs_id: 333,
                              reviewed: nil
                            ))

    assert_includes(html, "Mark as reviewed")
  end

  def test_includes_turbo_data_attributes
    html = render_component(Components::MarkAsReviewedToggle.new(obs_id: 444))

    assert_includes(html, "data-turbo=\"true\"")
    assert_includes(html, "data-controller=\"reviewed-toggle\"")
    assert_includes(html, "data-reviewed-toggle-target=\"toggle\"")
    assert_includes(html, "data-action=\"reviewed-toggle#submitForm\"")
  end

  def test_form_uses_put_method
    html = render_component(Components::MarkAsReviewedToggle.new(obs_id: 555))

    assert_includes(html, "method=\"post\"")
    assert_includes(html, "_method")
    assert_includes(html, "put")
  end

  def test_checkbox_has_correct_css_classes
    html = render_component(Components::MarkAsReviewedToggle.new(obs_id: 666))

    assert_includes(html, "d-inline")
    assert_includes(html, "form-group")
    assert_includes(html, "form-inline")
    assert_includes(html, "mx-3")
  end

  def test_all_parameters_together
    html = render_component(Components::MarkAsReviewedToggle.new(
                              obs_id: 999,
                              selector: "custom_selector",
                              label_class: "custom-class",
                              reviewed: true
                            ))

    assert_includes(html, "custom_selector_toggle_999")
    assert_includes(html, "custom_selector_999")
    assert_includes(html, "custom-class")
    assert_includes(html, "Marked as reviewed")
    assert_includes(html, "checked")
  end
end
