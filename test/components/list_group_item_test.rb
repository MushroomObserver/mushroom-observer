# frozen_string_literal: true

require("test_helper")

class ListGroupItemTest < ComponentTestCase
  def test_default_is_div_with_list_group_item_class
    # `Components::ListGroupItem` is a Bootstrap styling abstraction
    # — the `list-group-item` class is its contract, so the class
    # name IS asserted here (rules carve-out for styling-abstraction
    # components).
    html = render_item { "hello" }

    assert_html(html, "div.list-group-item", text: "hello")
  end

  def test_ul_list_uses_li_element
    html = render_item(element: :li) { "inside" }

    assert_html(html, "li.list-group-item", text: "inside")
  end

  def test_extra_class_appended_to_list_group_item
    html = render_item(class: "comment") { "c" }

    assert_html(html, "div.list-group-item.comment", text: "c")
  end

  def test_id_set_when_provided
    # `id=` is the Turbo Stream target for `update` / `replace` /
    # `remove` actions — assert it survives to the rendered DOM.
    html = render_item(id: "comment_42") { "body" }

    assert_html(html, "div#comment_42.list-group-item")
  end

  def test_arbitrary_attributes_forwarded
    html = render_item(attributes: { data: { role: "row" } }) { "x" }

    assert_html(html, "div.list-group-item",
                attribute: { "data-role" => "row" })
  end

  def test_nested_content_rendered_inside_wrapper
    # Composition contract: the block renders inside the wrapper
    # element. The CommentRow case (ListGroupItem wrapping a
    # CommentItem) depends on this.
    html = render(Components::ListGroupItem.new(class: "comment",
                                                id: "x")) do
      render(Components::ListGroupItem.new(class: "inner")) { "hi" }
    end

    assert_html(html,
                "div#x.list-group-item.comment > div.list-group-item.inner",
                text: "hi")
  end

  private

  def render_item(element: :div, class: nil, id: nil, attributes: {}, &block)
    extra_class = binding.local_variable_get(:class)
    render(Components::ListGroupItem.new(
             element: element, class: extra_class, id: id,
             attributes: attributes
           ), &block)
  end
end
