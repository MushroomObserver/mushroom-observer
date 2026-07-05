# frozen_string_literal: true

require("test_helper")

class ListGroupLinkItemTest < ComponentTestCase
  class WithClassStubView < Components::Base
    def view_template
      render(Components::ListGroup::LinkItem.new(
               class: "indent"
             )) do |css_class|
        a(href: "/x", class: css_class) { plain("hello") }
      end
    end
  end

  class NoClassStubView < Components::Base
    def view_template
      render(Components::ListGroup::LinkItem.new) do |css_class|
        a(href: "/x", class: css_class) { plain("hello") }
      end
    end
  end

  class LabelStubView < Components::Base
    def initialize(label:)
      super()
      @label = label
    end

    def view_template
      render(Components::ListGroup::LinkItem.new(
               class: "indent"
             )) do |css_class|
        a(href: "/x", class: css_class) { plain(@label) }
      end
    end
  end

  def test_yields_composed_class_no_wrapper_tag
    html = render(WithClassStubView.new)

    assert_html(html, "a.list-group-item.indent[href='/x']", text: "hello")
    assert_no_html(html, "div")
  end

  def test_no_extra_class_still_composes_bare_list_group_item
    html = render(NoClassStubView.new)

    assert_html(html, "a.list-group-item[href='/x']")
  end

  def test_preserves_caller_instance_variables
    html = render(LabelStubView.new(label: "from caller"))

    assert_html(html, "a.list-group-item.indent", text: "from caller")
  end
end
