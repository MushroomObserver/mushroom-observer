# frozen_string_literal: true

require "test_helper"

class AlertTest < ComponentTestCase

  def test_renders_basic_alert_with_message
    html = render_component(
      Components::Alert.new(message: "Test message")
    )

    assert_html(html, "div.alert.alert-warning", text: "Test message")
  end

  def test_renders_alert_with_success_level
    html = render_component(
      Components::Alert.new(message: "Success!", level: :success)
    )

    assert_html(html, "div.alert.alert-success", text: "Success!")
  end

  def test_renders_alert_with_info_level
    html = render_component(
      Components::Alert.new(message: "Info", level: :info)
    )

    assert_html(html, "div.alert.alert-info", text: "Info")
  end

  def test_renders_alert_with_warning_level
    html = render_component(
      Components::Alert.new(message: "Warning", level: :warning)
    )

    assert_html(html, "div.alert.alert-warning", text: "Warning")
  end

  def test_renders_alert_with_danger_level
    html = render_component(
      Components::Alert.new(message: "Error!", level: :danger)
    )

    assert_html(html, "div.alert.alert-danger", text: "Error!")
  end

  def test_renders_empty_block
    component = Components::Alert.new(level: :info)
    html = render(component) { nil }

    assert_html(html, "div.alert.alert-info")
  end

  def test_renders_alert_with_custom_id
    html = render_component(
      Components::Alert.new(message: "Test", id: "custom-alert")
    )

    assert_html(html, "div#custom-alert.alert.alert-warning")
  end

  def test_renders_alert_with_custom_class
    html = render_component(
      Components::Alert.new(message: "Test", class: "my-custom-class")
    )

    assert_html(html, "div.alert.alert-warning.my-custom-class")
  end

  def test_renders_alert_with_data_attributes
    html = render_component(
      Components::Alert.new(
        message: "Test", data: { controller: "alert", target: "message" }
      )
    )

    assert_html(html, "div.alert",
                attribute: { "data-controller" => "alert",
                             "data-target" => "message" })
  end

  def test_renders_alert_with_multiple_custom_attributes
    html = render_component(
      Components::Alert.new(
        message: "Test",
        level: :info,
        id: "test-alert",
        class: "custom-class",
        data: { value: "123" }
      )
    )

    assert_html(html, "div#test-alert.alert.alert-info.custom-class",
                attribute: { "data-value" => "123" })
  end

  def test_default_level_is_warning
    html = render_component(Components::Alert.new(message: "Test"))
    assert_html(html, "div.alert.alert-warning")
  end
end
