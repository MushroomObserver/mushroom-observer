# frozen_string_literal: true

module APIKeysHelper
  def api_keys_sorted(user)
    user.api_keys.sort_by do |key|
      last_use = begin
                   (Time.zone.now - key.last_used)
                 rescue StandardError
                   0
                 end
      [-key.num_uses, last_use, key.id]
    end
  end

  def api_key_id_verified_or_activate(key)
    tag.div(id: "api_key_#{key.id}") do
      if key.verified
        api_keys_dummy_verified_check_box(key)
      else
        patch_button(name: :ACTIVATE.l,
                     class: "btn btn-default",
                     id: "activate_api_key_#{key.id}",
                     path: account_activate_api_key_path(key.id))
      end
    end
  end

  # Read-only ✓ indicator shown for verified keys. Renders MO's
  # canonical `<div class="checkbox"><label><input type="checkbox"
  # checked disabled></label></div>` shape via the centralized
  # `CheckboxField` so the markup stays in lockstep with form-mode
  # checkboxes (BS3/4/5 migration changes one file, not many).
  # The `disabled:` mode skips the hidden sidecar — the input is
  # never submitted, so the sidecar would just be noise.
  def api_keys_dummy_verified_check_box(key)
    render(Components::ApplicationForm::CheckboxField.new(
             Components::ApplicationForm::FieldProxy.new(
               nil, "verified_key_#{key.id}", true
             ),
             wrapper_options: { label: false, wrap_class: "my-0" },
             disabled: true
           ))
  end

  # This table cell is operated by Bootstrap collapse.js.
  # The table at first shows the notes and an "edit" button.
  # Clicking "edit" hides the notes and shows the form within the same cell.
  # The form's "cancel" button hides the form and shows the notes. The
  # data-parent ID is necessary for this toggle behavior, called "accordion".
  # In Boostrap 3, the accordion needs the panel-group AND panel to work.
  def api_keys_notes_section(key)
    tag.div(class: "panel-group border-none mb-0", id: "notes_#{key.id}") do
      tag.div(class: "panel border-none") do
        [
          api_keys_view_notes_container(key),
          api_keys_edit_notes_container(key)
        ].safe_join
      end
    end
  end

  # CSS class "in" means this is the one that shows by default, in Bootstrap 3
  def api_keys_view_notes_container(key)
    tag.div(class: "panel-collapse collapse in no-transition",
            id: "view_notes_#{key.id}_container") do
      concat(tag.span(key.notes.t, class: "current_notes mr-4"))
      concat(button_tag(link_icon(:edit, title: :EDIT.l),
                        type: :button,
                        class: "btn btn-default collapsed",
                        aria: { expanded: "false",
                                controls: "edit_notes_#{key.id}_container" },
                        data: { toggle: "collapse", role: "edit_api_key",
                                target: "#edit_notes_#{key.id}_container",
                                parent: "#notes_#{key.id}" }))
    end
  end

  def api_keys_edit_notes_container(key)
    tag.div(class: "panel-collapse collapse no-transition",
            id: "edit_notes_#{key.id}_container") do
      form_with(model: key, url: account_api_key_path(key.id),
                method: :patch, data: { turbo: true },
                id: "edit_api_key_#{key.id}_form") do |f|
        tag.div(class: "input-group") do
          concat(
            tag.span(class: "input-group-btn") do
              tag.button(link_icon(:cancel, title: :CANCEL.l),
                         type: :button,
                         class: "btn btn-default",
                         aria: { expanded: "true",
                                 controls: "view_notes_#{key.id}_container" },
                         data: { toggle: "collapse",
                                 target: "#view_notes_#{key.id}_container",
                                 parent: "#notes_#{key.id}" })
            end
          )
          concat(f.text_field(:notes, value: key.notes,
                                      id: "api_key_#{key.id}_notes",
                                      class: "form-control border-none"))
          concat(tag.span(class: "input-group-btn") do
            f.button(:SAVE.l, type: :submit, class: "btn btn-default",
                              turbo_submits_with: :show_namings_saving.l)
          end)
        end
      end
    end
  end

  def api_keys_remove_button(key)
    destroy_button(name: :REMOVE.l, icon: :remove,
                   id: "remove_api_key_#{key.id}",
                   class: "btn btn-link text-danger",
                   target: account_api_key_path(key.id))
  end

  # Renders as a sibling block below the api_keys table (was an
  # in-table `<td colspan=7>` row when the table was built with the
  # generic `make_table` helper; the Phlex `Components::Table`
  # doesn't natively span a row, so the panel now lives just below
  # the table instead).
  def api_keys_new_form_panel
    tag.div(class: "panel-group border-none mb-0", id: "new_key_row") do
      tag.div(class: "panel border-none") do
        [
          api_keys_new_button_container,
          api_keys_new_form_container
        ].safe_join
      end
    end
  end

  def api_keys_new_button_container
    button_text = [
      link_icon(:add), :account_api_keys_create_button.l
    ].safe_join(" ")

    tag.div(class: "panel-collapse collapse in no-transition",
            id: "new_key_button_container") do
      # Rendered as a real `<a href=/new>` link so it gracefully
      # falls back to the standalone create page when JS is
      # disabled. With JS, Bootstrap collapse.js intercepts the
      # click via `data-toggle="collapse"` and prevents the
      # default navigation.
      link_to(button_text, new_account_api_key_path,
              id: "new_key_button",
              class: "btn btn-default collapsed",
              aria: { expanded: "false",
                      controls: "new_key_form_container" },
              data: { toggle: "collapse",
                      target: "#new_key_form_container",
                      parent: "#new_key_row" })
    end
  end

  def api_keys_new_form_container
    tag.div(class: "panel-collapse collapse no-transition",
            id: "new_key_form_container") do
      render(::Components::APIKeyForm.new(
               APIKey.new,
               action: account_api_keys_path,
               id: "new_api_key_form",
               data: { turbo: true },
               cancel_target: "new_key_button_container",
               cancel_parent: "new_key_row"
             ))
    end
  end
end
