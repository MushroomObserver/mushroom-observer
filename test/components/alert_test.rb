# frozen_string_literal: true

require "test_helper"

class AlertTest < UnitTestCase
  include ComponentTestHelper

  def test_renders_basic_alert_with_message
    html = render_component(Components::Alert.new("Test message"))

    assert_html(html, "div.alert.alert-warning", text: "Test message")
  end

  def test_renders_alert_with_success_level
    html = render_component(Components::Alert.new("Success!", level: :success))

    assert_html(html, "div.alert.alert-success", text: "Success!")
  end

  def test_renders_alert_with_info_level
    html = render_component(Components::Alert.new("Info", level: :info))

    assert_html(html, "div.alert.alert-info", text: "Info")
  end

  def test_renders_alert_with_warning_level
    html = render_component(Components::Alert.new("Warning", level: :warning))

    assert_html(html, "div.alert.alert-warning", text: "Warning")
  end

  def test_renders_alert_with_danger_level
    html = render_component(Components::Alert.new("Error!", level: :danger))

    assert_html(html, "div.alert.alert-danger", text: "Error!")
  end

  def test_renders_empty_block
    component = Components::Alert.new(level: :info)
    html = render(component) { nil }

    assert_html(html, "div.alert.alert-info")
  end

  def test_renders_alert_with_custom_id
    html = render_component(Components::Alert.new("Test", id: "custom-alert"))

    assert_html(html, "div#custom-alert.alert.alert-warning")
  end

  def test_renders_alert_with_custom_class
    html = render_component(
      Components::Alert.new("Test", class: "my-custom-class")
    )

    assert_html(html, "div.alert.alert-warning.my-custom-class")
  end

  def test_renders_alert_with_data_attributes
    html = render_component(
      Components::Alert.new("Test", data: { controller: "alert", target: "message" })
    )

    doc = Nokogiri::HTML(html)
    div = doc.at_css("div.alert")

    assert_equal "alert", div["data-controller"]
    assert_equal "message", div["data-target"]
  end

  def test_renders_alert_with_multiple_custom_attributes
    html = render_component(
      Components::Alert.new(
        "Test",
        level: :info,
        id: "test-alert",
        class: "custom-class",
        data: { value: "123" }
      )
    )

    doc = Nokogiri::HTML(html)
    div = doc.at_css("div.alert")

    assert_equal "test-alert", div["id"]
    assert div["class"].include?("alert")
    assert div["class"].include?("alert-info")
    assert div["class"].include?("custom-class")
    assert_equal "123", div["data-value"]
  end

  def test_default_level_is_warning
    html = render_component(Components::Alert.new("Test"))

    assert_html(html, "div.alert.alert-warning")
  end
end
