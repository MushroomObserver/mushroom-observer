# frozen_string_literal: true

require("test_helper")

class AnyMethodButtonTest < ComponentTestCase
  def test_basic_post_button
    html = render(Components::AnyMethodButton.new(
                    name: "Submit",
                    target: "/some/path",
                    method: :post
                  ))

    assert_html(html, "form[action='/some/path'][data-turbo='true']")
    assert_html(html, "button", text: "Submit")
    assert_no_html(html, "[data-turbo-confirm]")
  end

  def test_patch_button_with_confirm
    html = render(Components::AnyMethodButton.new(
                    name: "Remove",
                    target: "/items/1/remove",
                    method: :patch,
                    confirm: "Are you sure?"
                  ))

    assert_html(html, "form[action='/items/1/remove']")
    assert_html(html, "input[name='_method'][value='patch']")
    assert_html(html, "form[data-turbo-confirm='Are you sure?']")
    assert_html(html, "button", text: "Remove")
  end

  def test_delete_button_with_destroy_action
    herbarium = herbaria(:nybg_herbarium)
    html = render(Components::AnyMethodButton.new(
                    name: "Destroy",
                    target: herbarium,
                    method: :delete,
                    action: :destroy,
                    confirm: "Are you sure?"
                  ))

    # Should build path from model
    assert_html(html, "form[action='/herbaria/#{herbarium.id}']")
    assert_html(html, "input[name='_method'][value='delete']")
    # Should build identifier class from action and model
    assert_html(html, ".destroy_herbarium_link_#{herbarium.id}")
    assert_html(html, "[data-turbo-confirm='Are you sure?']")
  end

  def test_button_with_icon
    html = render(Components::AnyMethodButton.new(
                    name: "Remove",
                    target: "/items/1",
                    method: :patch,
                    icon: :remove
                  ))

    # Icon should be rendered
    assert_html(html, ".glyphicon")
    # Name should be in sr-only span for accessibility
    assert_html(html, "span.sr-only", text: "Remove")
  end

  def test_button_with_custom_class
    html = render(Components::AnyMethodButton.new(
                    name: "Submit",
                    target: "/path",
                    method: :post,
                    class: "btn btn-primary"
                  ))

    assert_html(html, "button.btn.btn-primary")
  end

  def test_button_with_model_target_builds_path_and_identifier
    herbarium = herbaria(:nybg_herbarium)
    html = render(Components::AnyMethodButton.new(
                    name: "Update",
                    target: herbarium,
                    method: :patch
                  ))

    # Should build path: herbarium_path(herbarium.id) - method is separate
    assert_html(html, "form[action='/herbaria/#{herbarium.id}']")
    # Should build identifier from method: patch_herbarium_link_123
    assert_html(html, ".patch_herbarium_link_#{herbarium.id}")
  end

  def test_button_with_confirm_shows_title_and_button_name
    html = render(Components::AnyMethodButton.new(
                    name: "Remove",
                    target: "/items/1/remove",
                    method: :patch,
                    confirm: "Remove this item?"
                  ))

    # confirm becomes both the turbo-confirm trigger and the dialog title
    assert_html(html, "[data-turbo-confirm]")
    assert_html(html, "[data-turbo-confirm-title]")
    assert_html(html, "[data-turbo-confirm-button='Remove']")
  end
end

class LinkHelperButtonTest < ComponentTestCase
  # Test the helper wrappers that delegate to the component

  def test_destroy_button_helper
    herbarium = herbaria(:nybg_herbarium)
    html = view_context.destroy_button(target: herbarium)

    assert_html(html, "form[action='/herbaria/#{herbarium.id}']")
    assert_html(html, "input[name='_method'][value='delete']")
    assert_html(html, ".destroy_herbarium_link_#{herbarium.id}")
    assert_html(html, ".text-danger")
    assert_html(html, "[data-turbo-confirm]")
  end

  def test_destroy_button_with_custom_name
    herbarium = herbaria(:nybg_herbarium)
    html = view_context.destroy_button(target: herbarium, name: "Delete it")

    assert_html(html, "button", text: "Delete it")
  end

  def test_patch_button_helper
    html = view_context.patch_button(
      name: "Update",
      path: "/items/1"
    )

    assert_html(html, "form[action='/items/1']")
    assert_html(html, "input[name='_method'][value='patch']")
    assert_html(html, "button", text: "Update")
  end

  def test_patch_button_with_confirm
    html = view_context.patch_button(
      name: "Remove",
      path: "/items/1/remove",
      confirm: "Are you sure?"
    )

    assert_html(html, "[data-turbo-confirm='Are you sure?']")
  end

  def test_post_button_helper
    html = view_context.post_button(
      name: "Create",
      path: "/items"
    )

    assert_html(html, "form[action='/items']")
    assert_no_html(html, "input[name='_method']") # POST is default
    assert_html(html, "button", text: "Create")
  end

  def test_put_button_helper
    html = view_context.put_button(
      name: "Replace",
      path: "/items/1"
    )

    assert_html(html, "form[action='/items/1']")
    assert_html(html, "input[name='_method'][value='put']")
    assert_html(html, "button", text: "Replace")
  end
end
