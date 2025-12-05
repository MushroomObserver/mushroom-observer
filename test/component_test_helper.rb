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
                      # Include Queries module for add_q_param method
                      ctrl.class.include(ApplicationController::Queries)
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

  # Assert HTML contains a specific CSS selector with optional checks
  # @param html [String] The HTML to search
  # @param selector [String] CSS selector to find the element
  # @param text [String] Optional text content to find in element.text
  # @param count [Integer] Optional exact count of matching elements
  # @param classes [String] Optional CSS class name to check (without dot)
  # @param attribute [Hash] Optional attribute to check, e.g., { name: "value" }
  def assert_html(html, selector, **options)
    text = options[:text]
    count = options[:count]
    classes = options[:classes]
    attribute = options[:attribute]

    doc = Nokogiri::HTML(html)

    if count
      elements = doc.css(selector)
      assert_equal(
        count, elements.size,
        "Expected #{count} element(s) matching '#{selector}', " \
        "found #{elements.size}"
      )
      return if count.zero?

      element = elements.first
    else
      element = doc.at_css(selector)
      assert(element, "Expected to find element matching '#{selector}'")
    end

    assert_includes(element.text, text) if text

    if classes
      element_classes = element["class"]&.split || []
      assert_includes(
        element_classes, classes,
        "Expected element to have class '#{classes}'"
      )
    end

    return unless attribute

    attribute.each do |attr_name, expected_value|
      actual_value = element[attr_name.to_s]
      assert_equal(
        expected_value, actual_value,
        "Expected #{attr_name}='#{expected_value}', " \
        "got #{attr_name}='#{actual_value}'"
      )
    end
  end

  # Assert that a child selector is nested within a parent selector.
  # If text is provided, searches ALL matching children for one containing
  # that text, not just the first match.
  def assert_nested(html, parent_selector:, child_selector:, text: nil)
    doc = Nokogiri::HTML(html)
    parent = doc.at_css(parent_selector)
    assert(
      parent,
      "Expected to find parent element matching '#{parent_selector}'"
    )

    children = parent.css(child_selector)
    assert(
      children.any?,
      "Expected to find child element '#{child_selector}' " \
      "within parent '#{parent_selector}'"
    )

    return children.first unless text

    # Find a child that contains the specified text
    matching_child = children.find { |c| c.text.include?(text) }
    assert(
      matching_child,
      "Expected a '#{child_selector}' within '#{parent_selector}' " \
      "to contain '#{text}', but none did. " \
      "Found: #{children.map(&:text).inspect}"
    )
    matching_child
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
