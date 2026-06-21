# frozen_string_literal: true

require("test_helper")

class ButtonTest < ComponentTestCase
  def test_default_styling
    html = render_button(name: "Click me")

    assert_html(html, "button[type='button']", text: "Click me")
    assert_html(html, "button.btn.btn-default")
  end

  def test_custom_variant
    html = render_button(name: "Danger", variant: :danger)

    assert_html(html, "button.btn.btn-danger")
  end

  def test_strip_variant_drops_frame
    html = render_button(name: "Bare", variant: :strip, class: "p-0")

    assert_no_html(html, "button.btn")
  end

  def test_extra_class_merged
    html = render_button(name: "Sized", size: :sm)

    assert_html(html, "button.btn.btn-default.btn-sm")
  end

  def test_icon_only_with_sr_only_name
    html = render_button(name: "Remove", icon: :x, variant: :strip,
                         class: "p-0")

    assert_html(html, "button span.sr-only", text: "Remove")
    assert_html(html, "button span.glyphicon")
  end

  def test_raises_on_btn_class_in_class_kwarg
    assert_raises(ArgumentError) do
      render_button(name: "Bad", class: "btn btn-primary")
    end
  end

  def test_data_attrs_pass_through
    html = render_button(name: "Open",
                         data: { action: "confirm-modal#open",
                                 confirm_modal_target: "trigger" })

    assert_html(html, "button[data-action='confirm-modal#open']" \
                      "[data-confirm-modal-target='trigger']")
  end

  def test_id_passes_through
    html = render_button(name: "Labeled", id: "my_button")

    assert_html(html, "button#my_button")
  end

  def test_tag_a_renders_link
    html = render_button(name: "Go", tag: :a, href: "/path", variant: :primary)

    assert_html(html, "a.btn.btn-primary[href='/path']", text: "Go")
    assert_no_html(html, "button")
  end

  private

  def render_button(name:, **)
    render(Components::Button.new(name: name, **))
  end
end
