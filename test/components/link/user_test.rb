# frozen_string_literal: true

require("test_helper")

class Components::Link::UserTest < ComponentTestCase
  def setup
    super
    @rolf = users(:rolf)
  end

  def test_renders_anchor_to_user_show_with_unique_text_name
    html = render(Components::Link::User.new(user: @rolf))

    assert_html(html, "a[href='#{routes.user_path(@rolf)}']",
                text: @rolf.unique_text_name)
    assert_html(html, "a.user_link_#{@rolf.id}")
  end

  def test_name_override_replaces_default_label
    html = render(Components::Link::User.new(user: @rolf, name: "RS"))

    assert_html(html, "a.user_link_#{@rolf.id}", text: "RS")
  end

  def test_integer_id_renders_user_number_label
    html = render(Components::Link::User.new(user: 42))

    assert_html(html, "a[href='#{routes.user_path(42)}']",
                text: "#{:USER.t} #42")
    assert_html(html, "a.user_link_42")
  end

  def test_integer_id_with_name_uses_name
    html = render(Components::Link::User.new(user: 42, name: "custom"))

    assert_html(html, "a.user_link_42", text: "custom")
  end

  def test_nil_user_renders_unknown_label_no_anchor
    html = render(Components::Link::User.new(user: nil))

    assert_no_html(html, "a")
    assert_includes(html, :unknown_user_name.t)
  end

  def test_attributes_passed_through_with_class_merged
    html = render(Components::Link::User.new(
                    user: @rolf,
                    attributes: { id: "my_link", class: "extra" }
                  ))

    assert_html(html, "a#my_link")
    assert_html(html, "a.user_link_#{@rolf.id}")
    assert_html(html, "a.extra")
  end

  def test_button_styling_added_alongside_identifier_class
    html = render(Components::Link::User.new(user: @rolf, button: :btn_link))

    assert_html(html, "a.btn.btn-link.user_link_#{@rolf.id}")
  end
end
