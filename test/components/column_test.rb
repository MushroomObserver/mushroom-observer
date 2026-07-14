# frozen_string_literal: true

require("test_helper")

class ColumnTest < ComponentTestCase
  def test_classes_for_class_method
    assert_equal("", Components::Column.classes_for)
    assert_equal("col-xs-12", Components::Column.classes_for(xs: 12))
    assert_equal("col-xs-12 col-sm-9",
                 Components::Column.classes_for(xs: 12, sm: 9))
    assert_equal("col-sm-6 col-md-4 col-lg-3",
                 Components::Column.classes_for(sm: 6, md: 4, lg: 3))
    assert_equal("col-xs-4 col-xs-offset-4",
                 Components::Column.classes_for(xs: 4, offset_xs: 4))
    assert_equal("col col-sm-4",
                 Components::Column.classes_for(col: true, sm: 4))
  end

  def test_default_renders_div_with_no_width_classes
    html = render(Components::Column.new)

    assert_html(html, "div[class='']")
  end

  def test_single_breakpoint
    html = render(Components::Column.new(sm: 6))

    assert_html(html, "div.col-sm-6")
  end

  def test_multiple_breakpoints
    html = render(Components::Column.new(xs: 12, sm: 6, md: 4, lg: 3))

    assert_html(html, "div.col-xs-12.col-sm-6.col-md-4.col-lg-3")
  end

  def test_offset_xs
    html = render(Components::Column.new(xs: 4, offset_xs: 4))

    assert_html(html, "div.col-xs-4.col-xs-offset-4")
  end

  def test_col_flag_adds_bare_col_class
    html = render(Components::Column.new(col: true, sm: 4))

    assert_html(html, "div.col.col-sm-4")
  end

  def test_extra_class_merges_with_width_classes
    html = render(Components::Column.new(sm: 6, class: "text-center"))

    assert_html(html, "div.col-sm-6.text-center")
  end

  def test_element_override
    html = render(Components::Column.new(element: :nav, xs: 8, sm: 2))

    assert_html(html, "nav.col-xs-8.col-sm-2")
    assert_no_html(html, "div")
  end

  def test_other_attributes_pass_through
    html = render(Components::Column.new(sm: 6, id: "foo",
                                         data: { turbo: "true" }))

    assert_html(html, "div.col-sm-6#foo[data-turbo='true']")
  end

  def test_yields_block_content
    html = render(Components::Column.new(sm: 6)) { "hi" }

    assert_includes(html, "hi")
  end
end
