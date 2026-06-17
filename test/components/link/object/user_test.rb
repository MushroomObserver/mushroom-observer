# frozen_string_literal: true

require("test_helper")

class UserLinkTest < ComponentTestCase
  def test_renders_anchor_to_user_show_with_unique_text_name
    rolf = users(:rolf)
    html = render(Components::Link::Object::User.new(user: rolf))

    # Behavior pinned: where it links + the selector class. Each
    # attribute asserted separately so attribute order can drift
    # without churning these tests.
    assert_html(html, "a[href='#{routes.user_path(rolf)}']",
                text: rolf.unique_text_name)
    assert_html(html, "a.user_link_#{rolf.id}")
  end

  def test_name_override_replaces_default_label
    rolf = users(:rolf)
    html = render(Components::Link::Object::User.new(user: rolf, name: "RS"))

    assert_html(html, "a.user_link_#{rolf.id}", text: "RS")
  end

  def test_integer_id_renders_synthetic_user_label
    # Some callers (translations versions, comments author lookup)
    # only have the user id at hand. Fall back to "User #<id>"
    # rather than blowing up trying to `unique_text_name` an integer.
    html = render(Components::Link::Object::User.new(user: 42))

    assert_html(html, "a[href='#{routes.user_path(42)}']",
                text: "#{:USER.t} #42")
    assert_html(html, "a.user_link_42")
  end

  def test_integer_id_with_name_uses_name
    html = render(Components::Link::Object::User.new(user: 42, name: "rolf"))

    assert_html(html, "a.user_link_42", text: "rolf")
  end

  def test_nil_user_renders_unknown_label_no_anchor
    # Matches the legacy helper's "unknown user" fallback so
    # callers (e.g. ip_stats with a missing User row) can pass nil
    # without conditional logic.
    html = render(Components::Link::Object::User.new(user: nil))

    assert_no_html(html, "a")
    assert_includes(html, :unknown_user_name.t)
  end

  def test_attributes_passed_through_with_class_merged
    rolf = users(:rolf)
    html = render(Components::Link::Object::User.new(
                    user: rolf,
                    attributes: { id: "my_link", class: "extra" }
                  ))

    # Caller's class merges with the auto `user_link_<id>`; the
    # caller's `id:` flows through unchanged.
    assert_html(html, "a#my_link")
    assert_html(html, "a.user_link_#{rolf.id}")
    assert_html(html, "a.extra")
  end
end
