# frozen_string_literal: true

require("test_helper")

class ButtonCRUDBaseTest < ComponentTestCase
  def test_basic_post_button
    html = render(Components::Button::CRUDBase.new(
                    name: "Submit",
                    target: "/some/path",
                    method: :post
                  ))

    assert_html(html, "form[action='/some/path']")
    assert_html(html, "button", text: "Submit")
    assert_no_html(html, "[data-turbo-confirm]")
  end

  def test_patch_button_with_confirm
    html = render(Components::Button::CRUDBase.new(
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
    html = render(Components::Button::CRUDBase.new(
                    name: "Destroy",
                    target: herbarium,
                    method: :delete,
                    action: :destroy,
                    confirm: "Are you sure?"
                  ))

    # Should build path from model
    assert_html(html,
                "form[action='#{routes.herbarium_path(herbarium)}']")
    assert_html(html, "input[name='_method'][value='delete']")
    # Should build identifier class from action and model
    assert_html(html, ".destroy_herbarium_link_#{herbarium.id}")
    assert_html(html, "[data-turbo-confirm='Are you sure?']")
  end

  def test_button_with_icon
    html = render(Components::Button::CRUDBase.new(
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

  def test_raises_on_btn_class_in_class_kwarg
    assert_raises(ArgumentError) do
      render(Components::Button::CRUDBase.new(
               name: "Submit",
               target: "/path",
               method: :post,
               class: "btn btn-primary"
             ))
    end
  end

  def test_button_with_model_target_builds_path_and_identifier
    herbarium = herbaria(:nybg_herbarium)
    html = render(Components::Button::CRUDBase.new(
                    name: "Update",
                    target: herbarium,
                    method: :patch
                  ))

    # Should build path: herbarium_path(herbarium.id) - method is separate
    assert_html(html,
                "form[action='#{routes.herbarium_path(herbarium)}']")
    # Should build identifier from method: patch_herbarium_link_123
    assert_html(html, ".patch_herbarium_link_#{herbarium.id}")
  end

  def test_button_with_confirm_shows_title_and_button_name
    html = render(Components::Button::CRUDBase.new(
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

# `Components::Button::CRUDBase` subclasses (`Delete`, `Edit`, `Download`,
# `Post`, `Put`, `Patch`) — verify each subclass's destroy / edit /
# fetch defaults stack correctly on top of the base `Button::CRUDBase`
# rendering.
class ButtonSubclassesTest < ComponentTestCase
  def test_delete_with_model_target
    herbarium = herbaria(:nybg_herbarium)
    html = render(Components::Button::Delete.new(target: herbarium))

    assert_html(html,
                "form[action='#{routes.herbarium_path(herbarium)}']")
    assert_html(html, "input[name='_method'][value='delete']")
    assert_html(html, ".destroy_herbarium_link_#{herbarium.id}")
    assert_html(html, ".text-danger")
    assert_html(html, "[data-turbo-confirm]")
  end

  def test_delete_with_custom_name
    herbarium = herbaria(:nybg_herbarium)
    html = render(
      Components::Button::Delete.new(target: herbarium, name: "Delete it")
    )

    assert_html(html, "button", text: "Delete it")
  end

  # Default icon. `Delete` auto-applies `icon: :delete`, which
  # renders the remove-circle glyphicon + sr-only label wrapper.
  def test_delete_default_icon
    herbarium = herbaria(:nybg_herbarium)
    html = render(Components::Button::Delete.new(target: herbarium))

    assert_html(html, "button span.glyphicon-remove-circle")
    assert_html(html, "button span.sr-only")
  end

  # Opt out of the default icon by passing `icon: nil`. Used by the
  # context-nav `[ DESTROY ]` text-link rendering path.
  def test_delete_icon_nil_opts_out
    herbarium = herbaria(:nybg_herbarium)
    html = render(
      Components::Button::Delete.new(target: herbarium, icon: nil)
    )

    assert_no_html(html, "button span.glyphicon")
    assert_no_html(html, "button span.sr-only")
    assert_html(html, "input[name='_method'][value='delete']")
    assert_html(html, ".text-danger")
  end

  # Explicit icon override (e.g. `:remove`) wins over the default.
  def test_delete_icon_override
    herbarium = herbaria(:nybg_herbarium)
    html = render(
      Components::Button::Delete.new(target: herbarium, icon: :remove)
    )

    assert_html(html, "button span.glyphicon-remove-circle")
  end

  # Default renders the standard btn-default frame.
  def test_delete_default_btn_frame
    herbarium = herbaria(:nybg_herbarium)
    html = render(Components::Button::Delete.new(target: herbarium))

    assert_html(html, "button.btn.btn-default")
    assert_html(html, "input[name='_method'][value='delete']")
    assert_html(html, ".text-danger")
  end

  # `variant: :outline` produces the outline button frame — the common
  # choice for CRUD index rows.
  def test_delete_outline_variant
    herbarium = herbaria(:nybg_herbarium)
    html = render(
      Components::Button::Delete.new(target: herbarium, variant: :outline)
    )

    assert_html(html, "button.btn.btn-outline-default")
  end

  # `variant: :strip` is explicit bare — icon-only inline destroys in
  # dense table cells / list rows.
  def test_delete_strip_variant
    herbarium = herbaria(:nybg_herbarium)
    html = render(
      Components::Button::Delete.new(target: herbarium, variant: :strip)
    )

    assert_no_html(html, "button.btn-outline-default")
    assert_no_html(html, "button.btn")
    assert_html(html, "input[name='_method'][value='delete']")
    assert_html(html, ".text-danger")
    assert_html(html, "button span.glyphicon-remove-circle")
  end

  # `size: :sm` + `variant: :outline` — the typical index-row
  # delete button shape.
  def test_delete_size_kwarg
    herbarium = herbaria(:nybg_herbarium)
    html = render(
      Components::Button::Delete.new(target: herbarium,
                                     variant: :outline, size: :sm)
    )

    assert_html(html, "button.btn.btn-outline-default.btn-sm")
  end

  # Delete with a String target: caller controls the path entirely,
  # no identifier class is built, but delete-action defaults
  # (text-danger, confirm, icon) still apply. `default_name` falls
  # back to `:destroy.ti` since there's no type to interpolate.
  def test_delete_with_string_target
    html = render(
      Components::Button::Delete.new(target: "/items/42", name: "Destroy")
    )

    assert_html(html, "form[action='/items/42']")
    assert_html(html, "input[name='_method'][value='delete']")
    assert_html(html, ".text-danger")
    assert_no_html(html, ".destroy_link_")
    assert_html(html, "button span.glyphicon-remove-circle")
  end

  # Edit default: GET + `edit_<type>_path` + icon `:edit`.
  def test_edit_with_model_target
    herbarium = herbaria(:nybg_herbarium)
    html = render(Components::Button::Edit.new(target: herbarium))

    assert_html(html,
                "a[href='#{routes.edit_herbarium_path(herbarium)}']")
    assert_no_html(html, "form")
    assert_html(html, ".edit_herbarium_link_#{herbarium.id}")
    assert_html(html, "a span.glyphicon-edit")
    assert_html(html, "a span.sr-only",
                text: :edit_object.t(type: :herbarium))
    assert_html(html, "a[data-trigger='tooltip']")
  end

  # `icon: nil` opt-out for text-only edit links.
  def test_edit_icon_nil_opts_out
    herbarium = herbaria(:nybg_herbarium)
    html = render(
      Components::Button::Edit.new(target: herbarium, icon: nil)
    )

    path = routes.edit_herbarium_path(herbarium)
    assert_html(html, "a[href='#{path}']",
                text: :edit_object.t(type: :herbarium))
    assert_no_html(html, "a span.glyphicon")
    assert_no_html(html, "a span.sr-only")
    assert_no_html(html, "a[data-trigger='tooltip']")
  end

  # Default renders the standard btn-default frame.
  def test_edit_default_btn_frame
    herbarium = herbaria(:nybg_herbarium)
    html = render(Components::Button::Edit.new(target: herbarium))

    assert_html(html, "a.btn.btn-default")
  end

  # `variant: :outline` produces the outline button frame — the common
  # choice for CRUD index rows.
  def test_edit_outline_variant
    herbarium = herbaria(:nybg_herbarium)
    html = render(
      Components::Button::Edit.new(target: herbarium, variant: :outline)
    )

    assert_html(html, "a.btn.btn-outline-default")
  end

  # `variant: :strip` opt-out — icon-only inline edits in dense table rows.
  def test_edit_strip_variant
    herbarium = herbaria(:nybg_herbarium)
    html = render(
      Components::Button::Edit.new(target: herbarium, variant: :strip)
    )

    assert_no_html(html, "a.btn-outline-default")
    assert_no_html(html, "a.btn")
    assert_html(html, "a span.glyphicon-edit")
  end

  # Edit with String target + explicit `class:` override.
  def test_edit_with_string_target_and_class
    html = render(Components::Button::Edit.new(
                    target: "/items/42/edit", name: "Edit it",
                    variant: :link
                  ))

    assert_html(html, "a.btn.btn-link[href='/items/42/edit']")
    assert_html(html, "a span.glyphicon-edit")
    assert_html(html, "a span.sr-only", text: "Edit it")
  end

  # String / Hash targets have no recoverable type, so `default_name`
  # falls back to the generic `:edit.ti` instead of
  # `:edit_object.t(type: …)`.
  def test_edit_with_string_target_default_name
    html = render(
      Components::Button::Edit.new(target: "/items/42/edit")
    )

    assert_html(html, "a span.sr-only", text: :edit.ti)
  end

  # New: GET + explicit path + icon `:add`. Always pass an explicit
  # string path — new-form routes often require extra params
  # (e.g. `observation_id:`) that a model-instance target can't
  # express. The default name is the generic `:add.ti`; callers
  # should pass an explicit `name:`.
  def test_new_with_string_target_and_icon
    path = routes.new_herbarium_path
    html = render(Components::Button::New.new(
                    target: path,
                    name: :new_object.t(type: :herbarium)
                  ))

    assert_html(html, "a[href='#{path}']")
    assert_no_html(html, "form")
    assert_html(html, "a span.glyphicon-plus")
    assert_html(html, "a span.sr-only",
                text: :new_object.t(type: :herbarium))
    assert_html(html, "a[data-trigger='tooltip']")
  end

  # `icon: nil` opt-out: text-only new links.
  def test_new_icon_nil_opts_out
    path = routes.new_herbarium_path
    html = render(
      Components::Button::New.new(
        target: path, name: "New Herbarium", icon: nil
      )
    )

    assert_html(html, "a[href='#{path}']", text: "New Herbarium")
    assert_no_html(html, "a span.glyphicon")
    assert_no_html(html, "a span.sr-only")
    assert_no_html(html, "a[data-trigger='tooltip']")
  end

  # Default renders the standard btn-default frame.
  def test_new_default_btn_frame
    html = render(
      Components::Button::New.new(target: routes.new_herbarium_path)
    )

    assert_html(html, "a.btn.btn-default")
  end

  # `variant: :outline` produces the outline button frame.
  def test_new_outline_variant
    html = render(
      Components::Button::New.new(
        target: routes.new_herbarium_path,
        variant: :outline
      )
    )

    assert_html(html, "a.btn.btn-outline-default")
  end

  # Generic `:add.ti` fallback when no `name:` is supplied.
  def test_new_default_name_add_l
    html = render(
      Components::Button::New.new(target: routes.new_herbarium_path)
    )

    assert_html(html, "a span.sr-only", text: :add.ti)
  end

  # Download: GET + explicit path + icon `:download`. The species
  # list controller's named route is `new_download_species_list_path`,
  # which doesn't match the standard `download_<resource>_path`
  # shape that `target: model` would auto-resolve to — callers
  # therefore pass an explicit path String. (The
  # `LinkHelper#download_button` helper does the path-resolution
  # for ERB callers; Phlex callers go through this path directly.)
  def test_download_with_explicit_path
    species_list = species_lists(:first_species_list)
    path = routes.new_download_species_list_path(id: species_list.id)
    html = render(Components::Button::Download.new(target: path))

    assert_html(html, "a[href='#{path}']")
    assert_no_html(html, "form")
    assert_html(html, "a span.glyphicon-download-alt")
    assert_html(html, "a span.sr-only")
  end

  # Post: form, no `_method` field (POST is default), no confirm,
  # button body is the name verbatim.
  def test_post
    html = render(
      Components::Button::Post.new(name: "Create", target: "/items")
    )

    assert_html(html, "form[action='/items']")
    assert_no_html(html, "input[name='_method']")
    assert_no_html(html, "[data-turbo-confirm]")
    assert_html(html, "button", text: "Create")
  end

  # Put + confirm: form action, `_method=put`, turbo-confirm title
  # and button data, body text.
  def test_put_with_confirm
    html = render(Components::Button::Put.new(
                    name: "Replace", target: "/items/1", confirm: "Sure?"
                  ))

    assert_html(html, "form[action='/items/1']")
    assert_html(html, "input[name='_method'][value='put']")
    assert_html(html, "[data-turbo-confirm='Sure?']")
    assert_html(html, "[data-turbo-confirm-title='Sure?']")
    assert_html(html, "[data-turbo-confirm-button='Replace']")
    assert_html(html, "button", text: "Replace")
  end

  # Post defaults to `btn btn-default`.
  def test_post_default_btn_frame
    html = render(
      Components::Button::Post.new(name: "Submit", target: "/items")
    )

    assert_html(html, "button.btn.btn-default")
  end

  # Explicit `variant:` overrides the default.
  def test_post_variant_override
    html = render(
      Components::Button::Post.new(name: "Submit", target: "/items",
                                   variant: :primary)
    )

    assert_html(html, "button.btn.btn-primary")
    assert_no_html(html, "button.btn-default")
  end

  # `variant: :strip` suppresses the frame entirely (icon-only inline buttons).
  def test_post_variant_nil_suppresses_frame
    html = render(
      Components::Button::Post.new(name: "Submit", target: "/items",
                                   variant: :strip)
    )

    assert_no_html(html, "button.btn")
  end

  # Patch defaults to `btn btn-default`.
  def test_patch_default_btn_frame
    html = render(
      Components::Button::Patch.new(name: "Update", target: "/items/1")
    )

    assert_html(html, "button.btn.btn-default")
  end

  # `variant: :strip` suppresses the frame (icon-only / inline patches).
  def test_patch_strip_suppresses_frame
    html = render(
      Components::Button::Patch.new(name: "Update", target: "/items/1",
                                    variant: :strip)
    )

    assert_no_html(html, "button.btn")
  end

  # Put defaults to `btn btn-default`.
  def test_put_default_btn_frame
    html = render(
      Components::Button::Put.new(name: "Replace", target: "/items/1")
    )

    assert_html(html, "button.btn.btn-default")
  end

  # `variant: :strip` suppresses the frame (icon-only / inline puts).
  def test_put_strip_suppresses_frame
    html = render(
      Components::Button::Put.new(name: "Replace", target: "/items/1",
                                  variant: :strip)
    )

    assert_no_html(html, "button.btn")
  end

  # Patch with `variant:` override: form, `_method=patch`, variant applied.
  def test_patch_with_variant_override
    html = render(Components::Button::Patch.new(
                    name: "Update", target: "/items/1",
                    variant: :primary
                  ))

    assert_html(html, "form[action='/items/1']")
    assert_html(html, "input[name='_method'][value='patch']")
    assert_html(html, "button.btn.btn-primary", text: "Update")
    assert_no_html(html, "button.btn-default")
  end

  # --- Button::Get --------------------------------------------------

  def test_get_button_renders_anchor_with_btn_default
    herbarium = herbaria(:nybg_herbarium)
    html = render(Components::Button::Get.new(
                    name: "View",
                    target: herbarium
                  ))

    expected_href = routes.herbarium_path(herbarium)
    assert_html(html, "a.btn.btn-default[href='#{expected_href}']",
                text: "View")
    assert_no_html(html, "form")
  end

  def test_get_button_with_string_target
    html = render(Components::Button::Get.new(
                    name: "Merge",
                    target: routes.herbaria_path(merge: 42),
                    variant: :strip
                  ))

    # `variant: :strip` → no btn classes; still an anchor with the path
    assert_html(html, "a[href*='merge=42']", text: "Merge")
    assert_no_html(html, "a.btn-default")
  end

  def test_get_button_accepts_size
    html = render(Components::Button::Get.new(
                    name: "Edit",
                    target: "/foo",
                    size: :sm
                  ))

    assert_html(html, "a.btn-sm[href='/foo']")
  end

  # --- Button::ModalToggle ------------------------------------------

  def test_modal_toggle_renders_anchor_with_stimulus_data
    html = render(Components::Button::ModalToggle.new(
                    name: "Open Trust Settings",
                    target: "/trust/path",
                    modal_id: "trust_settings"
                  ))

    assert_html(html,
                "a[data-controller='modal-toggle']" \
                "[data-action='modal-toggle#showModal:prevent']" \
                "[data-modal='modal_trust_settings']" \
                "[href='/trust/path']")
    assert_html(html, "a.btn.btn-default", text: "Open Trust Settings")
  end

  def test_modal_toggle_plain_text_style
    html = render(Components::Button::ModalToggle.new(
                    name: "Edit",
                    target: "/edit/path",
                    modal_id: "comment",
                    variant: :strip
                  ))

    assert_html(html, "a[data-controller='modal-toggle'][href='/edit/path']")
    assert_no_html(html, "a.btn-default")
  end

  # --- Button::CollapseToggle -------------------------------------------

  def test_collapse_toggle_renders_button_with_state_spans
    html = render(Components::Button::CollapseToggle.new(
                    target_id: "map_div",
                    open_text: "Hide Map",
                    closed_text: "Open Map",
                    collapsed: true
                  ))

    assert_html(html, "button[type='button'][data-toggle='collapse']" \
                      "[data-target='#map_div']")
    assert_html(html, "button.collapsed")
    assert_html(html, "button span.collapse-toggle-open", text: "Hide Map")
    assert_html(html,
                "button span.collapse-toggle-closed", text: "Open Map")
  end

  def test_collapse_toggle_accepts_extra_class
    html = render(Components::Button::CollapseToggle.new(
                    target_id: "map_div",
                    class: "map-toggle"
                  ))

    assert_html(html, "button.map-toggle")
  end

  # `params:` threads hidden fields into the generated form so callers
  # can dispatch multiple actions to one endpoint without separate routes.
  def test_params_adds_hidden_fields_to_form
    html = render(Components::Button::Put.new(
                    name: "Exclude",
                    target: "/projects/1/violations",
                    params: { project: { do: "exclude", obs_id: 42 } }
                  ))

    assert_html(html, "form input[name='project[do]'][value='exclude']")
    assert_html(html, "form input[name='project[obs_id]'][value='42']")
  end
end
