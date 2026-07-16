# frozen_string_literal: true

require("test_helper")

class InlineLinkBlockTest < ComponentTestCase
  def test_item_class_alone
    assert_equal("inline-icon-link",
                 Components::InlineLinkBlock.item_class)
  end

  def test_item_class_merges_existing_class
    assert_equal("inline-icon-link destroy_thing_link_1",
                 Components::InlineLinkBlock.item_class(
                   "destroy_thing_link_1"
                 ))
  end

  def test_item_class_ignores_nil_existing_class
    assert_equal("inline-icon-link",
                 Components::InlineLinkBlock.item_class(nil))
  end

  def test_renders_nothing_when_items_empty
    html = render(Components::InlineLinkBlock.new(items: []))

    assert_equal("", html.to_s.strip)
  end

  def test_single_item_rendered_inside_nowrap_span
    html = render(Components::InlineLinkBlock.new(
                    items: ["<b>edit</b>".html_safe]
                  ))

    assert_html(html, "span.text-nowrap b", text: "edit")
  end

  def test_leading_separator_is_nbsp
    html = render(Components::InlineLinkBlock.new(items: ["x"]))
    text = Nokogiri::HTML(html).at_css("span.text-nowrap").text

    assert_equal("\u00A0x", text)
  end

  def test_multiple_items_rendered_with_no_wrapper_or_divider
    html = render(Components::InlineLinkBlock.new(items: %w[a b c]))
    text = Nokogiri::HTML(html).at_css("span.text-nowrap").text

    assert_equal("\u00A0abc", text)
  end

  def test_string_items_rendered_as_trusted_html
    html = render(Components::InlineLinkBlock.new(
                    items: ["<i>archive</i>".html_safe]
                  ))

    assert_html(html, "span.text-nowrap i", text: "archive")
  end

  def test_phlex_component_items_rendered
    button = Components::Button.new(name: "Edit", variant: :strip)
    html = render(Components::InlineLinkBlock.new(items: [button]))

    assert_html(html, "span.text-nowrap button", text: "Edit")
  end
end
