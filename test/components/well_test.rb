# frozen_string_literal: true

require("test_helper")

class WellTest < ComponentTestCase
  def test_default_is_a_plain_well_div
    html = render_well

    assert_html(html, "div.well")
  end

  def test_element_renders_alternate_tag
    html = render_well(element: :span)

    assert_html(html, "span.well")
    assert_no_html(html, "div.well")
  end

  def test_extra_class_merges_with_well_class
    html = render_well(class: "help-block position-relative")

    assert_html(html, "div.well.help-block.position-relative")
  end

  def test_other_attrs_pass_through
    html = render_well(id: "main_well", data: { controller: "foo" })

    assert_html(html, "div.well#main_well[data-controller='foo']")
  end

  def test_yields_content
    html = render(phlex_wrapper do
      render(Components::Well.new) { plain("hello") }
    end)

    assert_html(html, "div.well", text: "hello")
  end

  private

  def render_well(**, &block)
    render(Components::Well.new(**), &block)
  end

  # Returns an anonymous Components::Base instance whose view_template
  # runs the given block in Phlex context (so `plain`, `div`, `render`
  # etc. are all available).
  def phlex_wrapper(&block)
    Class.new(Components::Base) do
      define_method(:view_template, &block)
    end.new
  end
end
