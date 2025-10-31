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
end
