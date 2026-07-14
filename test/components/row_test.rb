# frozen_string_literal: true

require("test_helper")

class RowTest < ComponentTestCase
  def test_default_is_a_plain_row_div
    html = render(Components::Row.new)

    assert_html(html, "div.row")
  end

  def test_element_renders_alternate_tag
    html = render(Components::Row.new(element: :ul))

    assert_html(html, "ul.row")
    assert_no_html(html, "div.row")
  end

  def test_extra_class_merges_with_row_class
    html = render(Components::Row.new(class: "mt-3 align-items-center"))

    assert_html(html, "div.row.mt-3.align-items-center")
  end

  def test_other_attrs_pass_through
    html = render(Components::Row.new(
                    id: "main_row", data: { controller: "foo" }
                  ))

    assert_html(html, "div.row#main_row[data-controller='foo']")
  end

  def test_yields_content
    html = render(phlex_wrapper do
      render(Components::Row.new) { plain("hello") }
    end)

    assert_html(html, "div.row", text: "hello")
  end

  private

  # Returns an anonymous Components::Base instance whose view_template
  # runs the given block in Phlex context (so `plain`, `div`, `render`
  # etc. are all available).
  def phlex_wrapper(&block)
    Class.new(Components::Base) do
      define_method(:view_template, &block)
    end.new
  end
end
