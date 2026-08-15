# frozen_string_literal: true

require("test_helper")

class Components::Alert::LinkTest < ComponentTestCase
  def test_renders_link_with_alert_link_class
    html = render_link

    assert_html(html, "a.alert-link[href='/projects/1/admin']",
                text: "Set prefix")
  end

  def test_merges_caller_class_with_alert_link
    html = render_link(class: "my-class")

    assert_html(html, "a.alert-link.my-class[href='/projects/1/admin']")
  end

  def test_passes_extra_html_attrs_through
    html = render_link(id: "prefix-link")

    assert_html(html, "a#prefix-link.alert-link")
  end

  private

  def render_link(**)
    render(Components::Alert::Link.new(
             text: "Set prefix", href: "/projects/1/admin", **
           ))
  end
end
