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
    html = render_links(items: [])

    assert_equal("", html.to_s.strip)
  end

  def test_single_item_rendered_inside_inline_link_block_span
    html = render_links(items: ["<b>edit</b>".html_safe])

    assert_html(html, "span.inline-link-block.ml-3 b", text: "edit")
  end

  def test_no_separator_characters_between_items
    html = render_links(items: %w[a b c])
    text = Nokogiri::HTML(html).at_css("span.inline-link-block").text

    assert_equal("abc", text,
                 "Items should render with no nbsp/whitespace text " \
                 "nodes between them -- spacing comes from the " \
                 "wrapper's gap, not literal characters")
  end

  def test_string_items_rendered_as_trusted_html
    html = render_links(items: ["<i>archive</i>".html_safe])

    assert_html(html, "span.inline-link-block i", text: "archive")
  end

  def test_phlex_component_items_rendered
    button = Components::Button.new(name: "Edit", variant: :strip)
    html = render_links(items: [button])

    assert_html(html, "span.inline-link-block button", text: "Edit")
  end

  private

  def render_links(items:)
    render(Components::InlineLinkBlock.new(items: items))
  end
end
