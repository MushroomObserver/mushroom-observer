# frozen_string_literal: true

require("test_helper")

# Unit tests for Components::Collapsible.
class CollapsibleTest < ComponentTestCase
  def test_collapse_classes_class_method_matches_instance_rendering
    assert_equal("collapse", Components::Collapsible.collapse_classes)
    assert_equal("collapse in",
                 Components::Collapsible.collapse_classes(expanded: true))
    assert_equal("collapse panel-collapse",
                 Components::Collapsible.collapse_classes(panel: true))
    assert_equal("collapse in panel-collapse custom-class",
                 Components::Collapsible.collapse_classes(
                   expanded: true, panel: true, html_class: "custom-class"
                 ))
  end

  def test_closed_by_default
    html = render(Components::Collapsible.new(id: "foo"))

    assert_html(html, "div.collapse#foo")
    assert_no_html(html, "div.in")
    assert_no_html(html, "div.panel-collapse")
  end

  def test_expanded_adds_in_class
    html = render(Components::Collapsible.new(id: "foo", expanded: true))

    assert_html(html, "div.collapse.in#foo")
  end

  def test_panel_adds_panel_collapse_class
    html = render(Components::Collapsible.new(id: "foo", panel: true))

    assert_html(html, "div.collapse.panel-collapse#foo")
    assert_no_html(html, "div.in")
  end

  def test_expanded_panel_with_class
    html = render(Components::Collapsible.new(
                    id: "foo", expanded: true, panel: true,
                    class: "custom-class"
                  ))

    assert_html(html, "div.collapse.in.panel-collapse.custom-class#foo")
  end

  def test_nil_id_omits_id_attr
    html = render(Components::Collapsible.new)

    assert_html(html, "div.collapse")
    assert_no_html(html, "div[id]")
  end

  def test_extra_attrs_forwarded
    html = render(Components::Collapsible.new(
                    id: "geo",
                    data: { form_exif_target: "collapseFields" }
                  ))

    assert_html(html,
                "div.collapse#geo[data-form-exif-target='collapseFields']")
  end

  def test_id_kwarg_always_wins_over_any_other_id_source
    # `id:` is an explicit prop, so it always claims that keyword --
    # there's no bucket a caller could stash a conflicting id in.
    html = render(Components::Collapsible.new(id: "real", data: { foo: "bar" }))

    assert_html(html, "div.collapse#real[data-foo='bar']")
  end

  def test_element_kwarg_renders_alternate_tag
    html = render(Components::Collapsible.new(id: "foo", element: :tbody))

    assert_html(html, "tbody.collapse#foo")
    assert_no_html(html, "div.collapse")
  end

  def test_yields_content
    html = render(phlex_wrapper do
      render(Components::Collapsible.new(id: "foo")) { plain("hello") }
    end)

    assert_html(html, "div.collapse#foo", text: "hello")
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
