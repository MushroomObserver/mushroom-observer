# frozen_string_literal: true

# Helper module for testing Phlex components
# Based on https://www.phlex.fun/components/testing.html
module ComponentTestHelper
  # Render a Phlex component with proper Rails view context
  delegate :render, to: :view_context

  # Get the Rails view context needed for components to access helpers
  delegate :view_context, to: :controller

  # Create a test controller instance with auth methods
  def controller
    @controller ||= begin
                      ctrl = ActionView::TestCase::TestController.new
                      # Include Authentication module for permission? method
                      ctrl.class.include(ApplicationController::Authentication)
                      ctrl
                    end
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
    assert(element, "Expected to find element matching '#{selector}'")
    assert_includes(element.text, text) if text
  end

  # Assert that a child selector is nested within a parent selector
  def assert_nested(html, parent_selector:, child_selector:, text: nil)
    doc = Nokogiri::HTML(html)
    parent = doc.at_css(parent_selector)
    assert(
      parent,
      "Expected to find parent element matching '#{parent_selector}'"
    )

    child = parent.at_css(child_selector)
    assert(
      child,
      "Expected to find child element '#{child_selector}' " \
      "within parent '#{parent_selector}'"
    )

    assert_includes(child.text, text) if text
    child
  end

  # Assert that text content is within a specific nested structure
  def assert_text_in_nested_selector(html, text:, parent:, child: nil)
    doc = Nokogiri::HTML(html)
    parent_element = doc.at_css(parent)
    assert(
      parent_element,
      "Expected to find parent element matching '#{parent}'"
    )

    if child
      child_element = parent_element.at_css(child)
      assert(
        child_element,
        "Expected to find child element '#{child}' within parent '#{parent}'"
      )
      assert_includes(
        child_element.text,
        text,
        "Expected '#{child}' within '#{parent}' to contain '#{text}'"
      )
    else
      assert_includes(
        parent_element.text,
        text,
        "Expected '#{parent}' to contain '#{text}'"
      )
    end
  end
end
