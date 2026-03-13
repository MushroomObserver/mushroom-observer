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

  def test_cache_store_returns_rails_cache
    component = TestComponent.new
    assert_equal(Rails.cache, component.cache_store)
  end

  def test_before_template_adds_comment_in_development
    # Stub Rails.env.development? to return true
    Rails.env.stub(:development?, true) do
      # Create a component class that will have before_template defined
      component_class = Class.new(Components::Base) do
        # Re-define before_template since it's only defined when
        # Rails.env.development? is true at class load time
        def before_template
          comment { "Before #{self.class.name}" }
          super
        end

        def view_template
          div { "content" }
        end
      end

      html = render_component(component_class.new)

      # Should include HTML comment with class name
      assert_includes(html, "<!--")
      assert_includes(html, "Before")
      assert_includes(html, "content")
    end
  end
end
