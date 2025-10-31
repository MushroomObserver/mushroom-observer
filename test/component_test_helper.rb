# frozen_string_literal: true

# Helper module for testing Phlex components
# Based on https://www.phlex.fun/components/testing.html
module ComponentTestHelper
  # Render a Phlex component with proper Rails view context
  delegate :render, to: :view_context

  # Get the Rails view context needed for components to access helpers
  delegate :view_context, to: :controller

  # Create a test controller instance
  def controller
    @controller ||= ActionView::TestCase::TestController.new
  end

  # Render a component and return the HTML string
  def render_component(component, &block)
    if block
      render(component, &block)
    else
      render(component)
    end
  end

  # Parse rendered HTML as a Nokogiri fragment for advanced assertions
  def render_fragment(component)
    html = render(component)
    Nokogiri::HTML5.fragment(html)
  end

  # Parse rendered HTML as a Nokogiri document for full HTML structures
  def render_document(component)
    html = render(component)
    Nokogiri::HTML5(html)
  end

  # Assert HTML contains a specific CSS selector with optional text
  def assert_html(html, selector, text: nil)
    doc = Nokogiri::HTML(html)
    element = doc.at_css(selector)
    assert element, "Expected to find element matching '#{selector}'"
    assert_includes(element.text, text) if text
  end
end
