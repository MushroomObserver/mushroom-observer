# frozen_string_literal: true

# Base class for component tests that provides common setup and helpers.
# Based on https://www.phlex.fun/components/testing.html
#
# @example Usage
#   class MyComponentTest < ComponentTestCase
#     def test_renders_content
#       html = render(Components::MyComponent.new(title: "Test"))
#       assert_html(html, "h1", text: "Test")
#     end
#   end
#
class ComponentTestCase < UnitTestCase
  # Render a Phlex component with proper Rails view context
  delegate :render, to: :view_context

  # Get the Rails view context needed for components to access helpers
  delegate :view_context, to: :controller

  def setup
    super
    controller.request = ActionDispatch::TestRequest.create
  end

  # Stub in_admin_mode? to return true for testing admin-only features.
  # Sessions are disabled in component tests, so we stub the method directly.
  def stub_admin_mode!
    controller.define_singleton_method(:in_admin_mode?) { true }
  end

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

  # Assert HTML does NOT contain a specific CSS selector
  # @param html [String] The HTML to search
  # @param selector [String] CSS selector that should NOT be found
  # @param message [String] Optional custom failure message
  def assert_no_html(html, selector, message = nil)
    doc = Nokogiri::HTML(html)
    element = doc.at_css(selector)
    message ||= "Expected NOT to find element matching '#{selector}'"
    assert_nil(element, message)
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

  ##############################################################################
  #
  #  ERB vs PHLEX HTML COMPARISON UTILITY
  #
  #  IMPORTANT: When converting ERB views/partials to Phlex components, ALWAYS
  #  use this method to verify the HTML output is equivalent. DO NOT assume
  #  the HTML is "probably the same" - subtle differences can cause JavaScript
  #  to behave differently even when the HTML looks visually identical.
  #
  #  CRITICAL DIFFERENCES THAT HAVE CAUSED BUGS:
  #
  #  1. Boolean attributes: ERB renders `readonly="readonly"`, Phlex renders
  #     `readonly` or `readonly=""` depending on how you pass the value.
  #     Fix: Use `readonly: "readonly"` not `readonly: true` in Phlex.
  #
  #  2. Numeric data attributes: Phlex silently drops Float/BigDecimal values
  #     from data hashes. Only strings are rendered.
  #     Fix: Always use `.to_s` for numeric data attributes in Phlex.
  #
  #  3. Attribute ordering: ERB and Phlex may render attributes in different
  #     order. Usually harmless, but verify with actual testing.
  #
  #  4. Whitespace: ERB may include more whitespace than Phlex. Usually
  #     harmless but can affect text content comparisons.
  #
  #  HOW TO USE THIS METHOD:
  #
  #  1. Create a controller test that renders both versions:
  #
  #     class MyControllerTest < FunctionalTestCase
  #       def test_erb_vs_phlex_output
  #         login(:katrina)
  #
  #         # Render ERB version (you may need a temporary route/action)
  #         get(:my_erb_action)
  #         erb_html = @response.body
  #
  #         # Render Phlex version
  #         get(:my_phlex_action)
  #         phlex_html = @response.body
  #
  #         # Compare specific elements
  #         compare_html_elements(
  #           erb_html, phlex_html,
  #           selector: "#my_hidden_field",
  #           label: "Hidden field"
  #         )
  #       end
  #     end
  #
  #  2. Run the test and examine the output for any differences.
  #
  #  3. Fix differences in your Phlex component until the output matches.
  #
  #  4. Remove the temporary ERB route/action after migration is complete.
  #
  #  DO NOT SKIP THIS STEP. HTML differences can cause:
  #  - JavaScript controllers failing to find targets
  #  - Data attributes being empty/missing
  #  - Forms submitting incorrect values
  #  - Maps failing to initialize (InvalidValueError: not a number)
  #
  ##############################################################################

  # Compare a specific HTML element between ERB and Phlex rendered output.
  # Outputs detailed comparison for debugging ERB→Phlex migrations.
  #
  # @param erb_html [String] Full HTML from ERB rendering
  # @param phlex_html [String] Full HTML from Phlex rendering
  # @param selector [String] CSS selector to find the element to compare
  # @param label [String] Human-readable label for test output
  # @return [Hash] Comparison result with :erb, :phlex, :match keys
  #
  # @example Compare a hidden field
  #   compare_html_elements(
  #     erb_html, phlex_html,
  #     selector: "#observation_location_id",
  #     label: "Location hidden field"
  #   )
  def compare_html_elements(erb_html, phlex_html, selector:, label: nil)
    label ||= selector
    erb_doc = Nokogiri::HTML(erb_html)
    phlex_doc = Nokogiri::HTML(phlex_html)

    erb_element = erb_doc.at_css(selector)
    phlex_element = phlex_doc.at_css(selector)

    puts("\n#{"=" * 60}")
    puts("Comparing: #{label}")
    puts("Selector: #{selector}")
    puts("-" * 60)

    if erb_element.nil?
      puts("ERB: NOT FOUND")
    else
      puts("ERB:")
      puts(erb_element.to_html)
    end

    puts("-" * 60)

    if phlex_element.nil?
      puts("PHLEX: NOT FOUND")
    else
      puts("PHLEX:")
      puts(phlex_element.to_html)
    end

    puts("-" * 60)

    match = erb_element&.to_html == phlex_element&.to_html
    if match
      puts("✓ MATCH")
    else
      puts("✗ DIFFERENT - See above for details")
      if erb_element && phlex_element
        compare_attributes(erb_element,
                           phlex_element)
      end
    end

    puts("=" * 60)

    { erb: erb_element&.to_html, phlex: phlex_element&.to_html, match: match }
  end

  # Save HTML to tmp files for manual inspection.
  # Useful when you need to compare full page output.
  #
  # @param erb_html [String] Full HTML from ERB rendering
  # @param phlex_html [String] Full HTML from Phlex rendering
  # @param basename [String] Base filename (without extension)
  def save_html_for_diff(erb_html, phlex_html, basename: "form")
    erb_path = Rails.root.join("tmp/#{basename}_erb.html")
    phlex_path = Rails.root.join("tmp/#{basename}_phlex.html")

    File.write(erb_path, erb_html)
    File.write(phlex_path, phlex_html)

    puts("\n#{"=" * 60}")
    puts("HTML saved for manual diff:")
    puts("  ERB:   #{erb_path}")
    puts("  Phlex: #{phlex_path}")
    puts("")
    puts("To compare, run:")
    puts("  diff #{erb_path} #{phlex_path}")
    puts("Or use a visual diff tool:")
    puts("  code --diff #{erb_path} #{phlex_path}")
    puts("=" * 60)
  end

  private

  # Helper to compare attributes between two Nokogiri elements
  def compare_attributes(erb_el, phlex_el)
    erb_attrs = erb_el.attributes.transform_values(&:value)
    phlex_attrs = phlex_el.attributes.transform_values(&:value)

    all_keys = (erb_attrs.keys + phlex_attrs.keys).uniq.sort

    puts("\nAttribute comparison:")
    all_keys.each do |key|
      erb_val = erb_attrs[key]
      phlex_val = phlex_attrs[key]

      if erb_val == phlex_val
        puts("  #{key}: ✓ (#{erb_val.inspect})")
      elsif erb_val.nil?
        puts("  #{key}: MISSING in ERB, Phlex has #{phlex_val.inspect}")
      elsif phlex_val.nil?
        puts("  #{key}: ERB has #{erb_val.inspect}, MISSING in Phlex")
      else
        puts("  #{key}: ✗ ERB=#{erb_val.inspect} vs Phlex=#{phlex_val.inspect}")
      end
    end
  end
end
