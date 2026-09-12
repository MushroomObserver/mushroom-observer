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
    assert_equal("d-none d-sm-block",
                 Components::Column.classes_for(hide_at: :xs, show_at: :sm))
    assert_equal("d-block d-sm-none",
                 Components::Column.classes_for(show_at: :xs, hide_at: :sm))
    assert_equal("d-md-none",
                 Components::Column.classes_for(hide_at: :md))
    assert_equal("d-lg-block",
                 Components::Column.classes_for(show_at: :lg))
  end

  def test_visibility_classes_display_kwarg
    assert_equal(%w[d-inline d-sm-none],
                 Components::Column.visibility_classes(
                   show_at: :xs, hide_at: :sm, display: :inline
                 ))
    assert_equal(%w[d-inline-block d-sm-none],
                 Components::Column.visibility_classes(
                   show_at: :xs, hide_at: :sm, display: :"inline-block"
                 ))
  end

  def test_visibility_classes_rejects_unknown_breakpoint
    assert_raises(ArgumentError) do
      Components::Column.visibility_classes(show_at: :xxl, hide_at: :sm)
    end
    assert_raises(ArgumentError) do
      Components::Column.visibility_classes(show_at: :xs, hide_at: :xxl)
    end
  end

  def test_visibility_classes_rejects_unknown_display
    assert_raises(ArgumentError) do
      Components::Column.visibility_classes(show_at: :xs, display: :foo)
    end
  end

  def test_mobile_hide_classes_shorthand
    assert_equal(%w[d-none d-sm-block],
                 Components::Column.mobile_hide_classes)
  end

  def test_mobile_hide_classes_shorthand_display_override
    assert_equal(%w[d-none d-sm-inline],
                 Components::Column.mobile_hide_classes(display: :inline))
  end

  def test_mobile_only_classes_shorthand
    assert_equal(%w[d-block d-sm-none],
                 Components::Column.mobile_only_classes)
  end

  def test_mobile_only_classes_shorthand_display_override
    assert_equal(%w[d-inline-block d-sm-none],
                 Components::Column.mobile_only_classes(
                   display: :"inline-block"
                 ))
  end

  def test_default_renders_div_with_no_width_classes
    html = render_column

    assert_html(html, "div[class='']")
  end

  def test_single_breakpoint
    html = render_column(sm: 6)

    assert_html(html, "div.col-sm-6")
  end

  def test_multiple_breakpoints
    html = render_column(xs: 12, sm: 6, md: 4, lg: 3)

    assert_html(html, "div.col-xs-12.col-sm-6.col-md-4.col-lg-3")
  end

  def test_offset_xs
    html = render_column(xs: 4, offset_xs: 4)

    assert_html(html, "div.col-xs-4.col-xs-offset-4")
  end

  def test_col_flag_adds_bare_col_class
    html = render_column(col: true, sm: 4)

    assert_html(html, "div.col.col-sm-4")
  end

  def test_hide_at_and_show_at_pair
    html = render_column(sm: 6, hide_at: :xs, show_at: :sm)

    assert_html(html, "div.col-sm-6.d-none.d-sm-block")
  end

  def test_show_at_xs_hide_at_sm
    html = render_column(show_at: :xs, hide_at: :sm)

    assert_html(html, "div.d-block.d-sm-none")
  end

  def test_hide_at_alone
    html = render_column(md: 6, hide_at: :md)

    assert_html(html, "div.col-md-6.d-md-none")
  end

  def test_extra_class_merges_with_width_classes
    html = render_column(sm: 6, class: "text-center")

    assert_html(html, "div.col-sm-6.text-center")
  end

  def test_element_override
    html = render_column(element: :nav, xs: 8, sm: 2)

    assert_html(html, "nav.col-xs-8.col-sm-2")
    assert_no_html(html, "div")
  end

  def test_other_attributes_pass_through
    html = render_column(sm: 6, id: "foo", data: { turbo: "true" })

    assert_html(html, "div.col-sm-6#foo[data-turbo='true']")
  end

  def test_yields_block_content
    html = render_column(sm: 6) { "hi" }

    assert_includes(html, "hi")
  end

  private

  def render_column(**, &block)
    render(Components::Column.new(**), &block)
  end
end
