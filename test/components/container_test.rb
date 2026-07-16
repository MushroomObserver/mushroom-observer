# frozen_string_literal: true

require("test_helper")

class ContainerTest < ComponentTestCase
  def test_class_for_known_widths
    assert_equal("container-text", Components::Container.class_for(:text))
    assert_equal("container-text-image",
                 Components::Container.class_for(:text_image))
    assert_equal("container-wide", Components::Container.class_for(:wide))
    assert_equal("container-full", Components::Container.class_for(:full))
  end

  def test_class_for_unrecognized_width_falls_back_to_full
    assert_equal("container-full", Components::Container.class_for(:double))
    assert_equal("container-full", Components::Container.class_for(nil))
  end

  def test_default_is_a_plain_div_with_no_width_class
    html = render(Components::Container.new)

    assert_html(html, "div")
    assert_no_html(html, "div[class*='container']")
  end

  def test_width_renders_matching_class
    html = render(Components::Container.new(width: :wide))

    assert_html(html, "div.container-wide")
  end

  def test_element_renders_alternate_tag
    html = render(Components::Container.new(element: :main, width: :text))

    assert_html(html, "main.container-text")
    assert_no_html(html, "div.container-text")
  end

  def test_extra_class_merges_with_width_class
    html = render(Components::Container.new(width: :text, class: "ml-4"))

    assert_html(html, "div.container-text.ml-4")
  end

  def test_extra_class_alone_with_no_width
    html = render(Components::Container.new(class: "hidden-print"))

    assert_html(html, "div.hidden-print")
    assert_no_html(html, "div.container-full")
  end

  def test_other_attrs_pass_through
    html = render(Components::Container.new(
                    id: "content", data: { controller: "lightgallery" }
                  ))

    assert_html(html, "div#content[data-controller='lightgallery']")
  end

  def test_yields_content
    html = render(phlex_wrapper do
      render(Components::Container.new(width: :text)) { plain("hello") }
    end)

    assert_html(html, "div.container-text", text: "hello")
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
