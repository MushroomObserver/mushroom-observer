# frozen_string_literal: true

require("test_helper")

class CrudButtonTest < ComponentTestCase
  def test_basic_post_button
    html = render(Components::CrudButton.new(
                    name: "Submit",
                    target: "/some/path",
                    method: :post
                  ))

    assert_html(html, "form[action='/some/path'][data-turbo='true']")
    assert_html(html, "button", text: "Submit")
    assert_no_html(html, "[data-turbo-confirm]")
  end

  def test_patch_button_with_confirm
    html = render(Components::CrudButton.new(
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
    html = render(Components::CrudButton.new(
                    name: "Destroy",
                    target: herbarium,
                    method: :delete,
                    action: :destroy,
                    confirm: "Are you sure?"
                  ))

    # Should build path from model
    assert_html(html,
                "form[action='#{view_context.herbarium_path(herbarium)}']")
    assert_html(html, "input[name='_method'][value='delete']")
    # Should build identifier class from action and model
    assert_html(html, ".destroy_herbarium_link_#{herbarium.id}")
    assert_html(html, "[data-turbo-confirm='Are you sure?']")
  end

  def test_button_with_icon
    html = render(Components::CrudButton.new(
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
    html = render(Components::CrudButton.new(
                    name: "Submit",
                    target: "/path",
                    method: :post,
                    class: "btn btn-primary"
                  ))

    assert_html(html, "button.btn.btn-primary")
  end

  def test_button_with_model_target_builds_path_and_identifier
    herbarium = herbaria(:nybg_herbarium)
    html = render(Components::CrudButton.new(
                    name: "Update",
                    target: herbarium,
                    method: :patch
                  ))

    # Should build path: herbarium_path(herbarium.id) - method is separate
    assert_html(html,
                "form[action='#{view_context.herbarium_path(herbarium)}']")
    # Should build identifier from method: patch_herbarium_link_123
    assert_html(html, ".patch_herbarium_link_#{herbarium.id}")
  end

  def test_button_with_confirm_shows_title_and_button_name
    html = render(Components::CrudButton.new(
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

  # GET method emits a plain `<a>` (link_to), not a `<form><button>`
  # (button_to). GET is idempotent so the form wrapper is overkill —
  # the anchor lets right-click "save link as" / "open in new tab"
  # work and keeps the element inline. Same html_options shape (class,
  # title, tooltip data) as the form-button branch.
  def test_get_method_emits_link_not_form
    html = render(Components::CrudButton.new(
                    name: "Download",
                    target: "/items/1/download",
                    method: :get,
                    icon: :download
                  ))

    assert_html(html, "a[href='/items/1/download']")
    assert_no_html(html, "form")
    assert_no_html(html, "button")
    assert_html(html, "a[title='Download']")
    assert_html(html, "a[data-toggle='tooltip']")
    assert_html(html, "a[data-placement='top']")
    assert_html(html, "a span.sr-only", text: "Download")
    assert_html(html, "a span.glyphicon-download-alt")
  end

  # GET branch without an icon: no tooltip data attrs. Tooltip is the
  # accessible label for icon-only buttons; for text-only links the
  # tooltip would just duplicate the visible label, so we skip it.
  def test_get_method_without_icon_skips_tooltip
    html = render(Components::CrudButton.new(
                    name: "Map",
                    target: "/map",
                    method: :get
                  ))

    assert_html(html, "a[href='/map']", text: "Map")
    assert_no_html(html, "a[data-toggle='tooltip']")
    assert_no_html(html, "a[title]")
    assert_no_html(html, "span.sr-only")
    assert_no_html(html, "span.glyphicon")
  end

  # `btn:` is an opt-in class-prepend for caller-side button styling.
  # Callers that want a `btn btn-default` link pass
  # `btn: "btn btn-default"` without having to spell out the full
  # `class:`. Caller's `class:` layers on top for sizing/spacing.
  def test_get_method_btn_kwarg_prepends_classes
    html = render(Components::CrudButton.new(
                    name: "Map",
                    target: "/map",
                    method: :get,
                    btn: "btn btn-default",
                    class: "btn-lg"
                  ))

    assert_html(html, "a.btn.btn-default.btn-lg[href='/map']")
    assert_no_html(html, "a[btn]")
  end
end

class LinkHelperButtonTest < ComponentTestCase
  # Test the helper wrappers that delegate to the component

  def test_destroy_button_helper
    herbarium = herbaria(:nybg_herbarium)
    html = view_context.destroy_button(target: herbarium)

    assert_html(html,
                "form[action='#{view_context.herbarium_path(herbarium)}']")
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

  # Default icon. `CrudButton::Delete` auto-applies `icon: :delete`,
  # which renders the remove-circle glyphicon + sr-only label wrapper.
  def test_destroy_button_default_icon
    herbarium = herbaria(:nybg_herbarium)
    html = view_context.destroy_button(target: herbarium)

    assert_html(html, "button span.glyphicon-remove-circle")
    assert_html(html, "button span.sr-only")
  end

  # Opt out of the default icon by passing `icon: nil`. Used by the
  # context-nav `[ DESTROY ]` text-link rendering path.
  def test_destroy_button_icon_nil_opts_out
    herbarium = herbaria(:nybg_herbarium)
    html = view_context.destroy_button(target: herbarium, icon: nil)

    assert_no_html(html, "button span.glyphicon")
    assert_no_html(html, "button span.sr-only")
    # button still renders the destroy machinery
    assert_html(html, "input[name='_method'][value='delete']")
    assert_html(html, ".text-danger")
  end

  # Explicit icon override (e.g. `:remove`) wins over the default.
  def test_destroy_button_icon_override
    herbarium = herbaria(:nybg_herbarium)
    html = view_context.destroy_button(target: herbarium, icon: :remove)

    assert_html(html, "button span.glyphicon-remove-circle")
  end

  # Default btn frame. `CrudButton::Delete` auto-applies
  # `btn: "btn btn-outline-default"` for a consistent outline frame
  # across destroy buttons.
  def test_destroy_button_default_btn_frame
    herbarium = herbaria(:nybg_herbarium)
    html = view_context.destroy_button(target: herbarium)

    assert_html(html, "button.btn.btn-outline-default")
  end

  # Opt out of the btn frame via `btn: nil` — icon-only inline
  # destroys in dense table cells / list rows.
  def test_destroy_button_btn_nil_opts_out_of_frame
    herbarium = herbaria(:nybg_herbarium)
    html = view_context.destroy_button(target: herbarium, btn: nil)

    assert_no_html(html, "button.btn-outline-default")
    assert_no_html(html, "button.btn")
    assert_html(html, "input[name='_method'][value='delete']")
    assert_html(html, ".text-danger")
    assert_html(html, "button span.glyphicon-remove-circle")
  end

  # Caller `class:` layers on top of the `btn:` default — e.g.
  # `btn-sm` combines with the outline frame.
  def test_destroy_button_class_layered_on_btn_default
    herbarium = herbaria(:nybg_herbarium)
    html = view_context.destroy_button(target: herbarium, class: "btn-sm")

    assert_html(html, "button.btn.btn-outline-default.btn-sm")
  end

  # Edit-button default: GET + edit_<type>_path + icon :edit.
  def test_edit_button_helper_defaults
    herbarium = herbaria(:nybg_herbarium)
    html = view_context.edit_button(target: herbarium)

    assert_html(html,
                "a[href='#{view_context.edit_herbarium_path(herbarium)}']")
    assert_no_html(html, "form")
    assert_html(html, ".edit_herbarium_link_#{herbarium.id}")
    assert_html(html, "a span.glyphicon-edit")
    assert_html(html, "a span.sr-only")
    assert_html(html, "a[data-toggle='tooltip']")
  end

  # `icon: nil` opt-out for text-only edit links.
  def test_edit_button_icon_nil_opts_out
    herbarium = herbaria(:nybg_herbarium)
    html = view_context.edit_button(target: herbarium, icon: nil)

    path = view_context.edit_herbarium_path(herbarium)
    assert_html(html, "a[href='#{path}']",
                text: :edit_object.t(type: :herbarium))
    assert_no_html(html, "a span.glyphicon")
    assert_no_html(html, "a span.sr-only")
    assert_no_html(html, "a[data-toggle='tooltip']")
  end

  # Edit shares Delete's btn-frame default (`btn btn-outline-default`).
  def test_edit_button_default_btn_frame
    herbarium = herbaria(:nybg_herbarium)
    html = view_context.edit_button(target: herbarium)

    assert_html(html, "a.btn.btn-outline-default")
  end

  # `btn: nil` opt-out — icon-only inline edits in dense table rows.
  def test_edit_button_btn_nil_opts_out_of_frame
    herbarium = herbaria(:nybg_herbarium)
    html = view_context.edit_button(target: herbarium, btn: nil)

    assert_no_html(html, "a.btn-outline-default")
    assert_no_html(html, "a.btn")
    assert_html(html, "a span.glyphicon-edit")
  end

  # Download-button default: GET + explicit path + icon :download.
  def test_download_button_helper_defaults
    species_list = species_lists(:first_species_list)
    html = view_context.download_button(target: species_list)

    path = view_context.new_download_species_list_path(id: species_list.id)
    assert_html(html, "a[href='#{path}']")
    assert_no_html(html, "form")
    assert_html(html, "a span.glyphicon-download-alt")
    assert_html(html, "a span.sr-only")
  end
end

# Parity spot checks: verify the new component subclass output
# matches the contract LinkHelper used to produce. Each test renders
# through `view_context.<helper>` and asserts the structural pieces
# (path, method, identifier class, body content) that downstream
# templates / styles / Stimulus controllers depend on.
class CrudButtonParityTest < ComponentTestCase
  # destroy_button with a model target: form action is bare
  # `<resource>_path` (no `destroy_` prefix), `_method=delete`, the
  # identifier class is `destroy_<type>_link_<id>`, text-danger is
  # applied, the default delete icon renders.
  def test_destroy_button_model_target_parity
    herbarium = herbaria(:nybg_herbarium)
    html = view_context.destroy_button(
      target: herbarium, name: "Destroy"
    )

    assert_html(html,
                "form[action='#{view_context.herbarium_path(herbarium)}']")
    assert_html(html, "input[name='_method'][value='delete']")
    assert_html(html, ".destroy_herbarium_link_#{herbarium.id}")
    assert_html(html, ".text-danger")
    assert_html(html, "[data-turbo-confirm]")
    assert_html(html, "button span.glyphicon-remove-circle")
    assert_html(html, "button span.sr-only", text: "Destroy")
  end

  # destroy_button with a String target: caller controls the path
  # entirely, no identifier class is built, but delete-action defaults
  # (text-danger, confirm, icon) still apply.
  def test_destroy_button_string_target_parity
    html = view_context.destroy_button(
      target: "/items/42", name: "Destroy"
    )

    assert_html(html, "form[action='/items/42']")
    assert_html(html, "input[name='_method'][value='delete']")
    assert_html(html, ".text-danger")
    assert_no_html(html, ".destroy_link_")
    assert_html(html, "button span.glyphicon-remove-circle")
  end

  # edit_button with model target: link to `edit_<resource>_path`,
  # identifier class `edit_<type>_link_<id>`, edit-icon glyph + sr-only
  # label, tooltip data attrs.
  def test_edit_button_model_target_parity
    herbarium = herbaria(:nybg_herbarium)
    html = view_context.edit_button(target: herbarium)

    assert_html(html,
                "a[href='#{view_context.edit_herbarium_path(herbarium)}']")
    assert_no_html(html, "form")
    assert_html(html, ".edit_herbarium_link_#{herbarium.id}")
    assert_html(html, "a span.glyphicon-edit")
    assert_html(html, "a span.sr-only",
                text: :edit_object.t(type: :herbarium))
  end

  # edit_button with String target + explicit `class:` override.
  def test_edit_button_string_target_with_class_parity
    html = view_context.edit_button(
      target: "/items/42/edit", name: "Edit it", class: "btn btn-link"
    )

    assert_html(html, "a.btn.btn-link[href='/items/42/edit']")
    assert_html(html, "a span.glyphicon-edit")
    assert_html(html, "a span.sr-only", text: "Edit it")
  end

  # post_button: form, no `_method` field (POST is default), no
  # confirm, button body is the name verbatim.
  def test_post_button_parity
    html = view_context.post_button(name: "Create", path: "/items")

    assert_html(html, "form[action='/items'][data-turbo='true']")
    assert_no_html(html, "input[name='_method']")
    assert_no_html(html, "[data-turbo-confirm]")
    assert_html(html, "button", text: "Create")
  end

  # put_button + confirm: form action, _method=put, turbo-confirm
  # title and button data, body text.
  def test_put_button_with_confirm_parity
    html = view_context.put_button(
      name: "Replace", path: "/items/1", confirm: "Sure?"
    )

    assert_html(html, "form[action='/items/1']")
    assert_html(html, "input[name='_method'][value='put']")
    assert_html(html, "[data-turbo-confirm='Sure?']")
    assert_html(html, "[data-turbo-confirm-title='Sure?']")
    assert_html(html, "[data-turbo-confirm-button='Replace']")
    assert_html(html, "button", text: "Replace")
  end

  # patch_button with custom class: form, _method=patch, class
  # applied to the button.
  def test_patch_button_with_class_parity
    html = view_context.patch_button(
      name: "Update", path: "/items/1", class: "btn btn-primary"
    )

    assert_html(html, "form[action='/items/1']")
    assert_html(html, "input[name='_method'][value='patch']")
    assert_html(html, "button.btn.btn-primary", text: "Update")
  end
end
