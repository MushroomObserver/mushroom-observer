# frozen_string_literal: true

require "test_helper"

class BaseTest < ComponentTestCase
  # Simple test component to test trusted_html method
  class TestComponent < Components::Base
    def view_template
      div do
        trusted_html("plain text")
      end
    end
  end

  # Test component that uses SafeBuffer
  class TestSafeBufferComponent < Components::Base
    def view_template
      div do
        trusted_html("safe <strong>html</strong>".html_safe)
      end
    end
  end

  def test_trusted_html_with_plain_string
    html = render_component(TestComponent.new)
    doc = Nokogiri::HTML(html)
    div = doc.at_css("div")

    assert_equal("plain text", div.text)
    # Verify no HTML tags were rendered
    assert_not(div.inner_html.include?("<"))
  end

  def test_trusted_html_with_safe_buffer
    html = render_component(TestSafeBufferComponent.new)
    doc = Nokogiri::HTML(html)
    div = doc.at_css("div")
    strong = div.at_css("strong")

    assert_not_nil(strong)
    assert_equal("html", strong.text)
    assert_equal("safe html", div.text.strip)
  end
end
