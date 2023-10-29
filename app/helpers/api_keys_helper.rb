# frozen_string_literal: true

module APIKeysHelper
  def api_keys_edit_form_headers
    [
      :account_api_keys_active_column_label.t,
      :CREATED.t,
      :account_api_keys_last_used_column_label.t,
      :account_api_keys_num_uses_column_label.t,
      :API_KEY.t,
      :NOTES.t,
      ""
    ]
  end

  def api_keys_edit_form_rows(user)
    rows = []

    api_keys_sorted(user).each do |key|
      # These are the fields in each row
      verified = api_key_id_verified_or_activate(key)
      last_used = key.last_used ? key.last_used.web_date : "--"
      num_uses = key.num_uses.positive? ? key.num_uses : "--"
      edit_section = api_keys_notes_section(key)
      remove_button = api_keys_remove_button(key)
      rows << [
        verified,
        key.created_at.web_date,
        last_used,
        num_uses,
        h(key.key),
        edit_section,
        remove_button
      ]
    end
    rows << api_keys_new_form_row
    rows
  end

  def api_keys_sorted(user)
    user.api_keys.sort_by do |key|
      last_use = (Time.zone.now - key.last_used) rescue 0
      [-key.num_uses, last_use, key.id]
    end
  end

  def api_key_id_verified_or_activate(key)
    tag.div(id: "api_key_#{key.id}") do
      if key.verified
        api_keys_dummy_verified_check_box(key)
      else
        patch_button(name: :ACTIVATE.l,
                     class: "btn btn-outline-secondary",
                     id: "activate_api_key_#{key.id}",
                     path: account_activate_api_key_path(key.id))
      end
    end
  end

  def api_keys_dummy_verified_check_box(key)
    tag.div(class: "checkbox my-0", id: "verified_key_#{key.id}") do
      tag.label(:verified) do
        check_box_tag(:verified, "verified", true, disabled: true)
        # concat(:verified.l)
      end
    end
  end

  # This table cell is operated by Bootstrap collapse.js.
  # The table at first shows the notes and an "edit" button.
  # Clicking "edit" hides the notes and shows the form within the same cell.
  # The form's "cancel" button hides the form and shows the notes. The
  # data-parent ID is necessary for this toggle behavior, called "accordion".
  # In Boostrap 3, the accordion needs the panel-group AND panel to work.
  def api_keys_notes_section(key)
    tag.div(class: "accordion border-none mb-0", id: "notes_#{key.id}") do
      tag.div(class: "card border-none") do
        [
          api_keys_view_notes_container(key),
          api_keys_edit_notes_container(key)
        ].safe_join
      end
    end
  end

  # CSS class "in" means this is the one that shows by default, in Bootstrap 3
  def api_keys_view_notes_container(key)
    tag.div(class: "collapse show no-transition",
            id: "view_notes_#{key.id}_container") do
      concat(tag.span(key.notes.t, class: "current_notes mr-4"))
      concat(button_tag(link_icon(:edit, title: :EDIT.l),
                        type: :button,
                        class: "btn btn-outline-secondary collapsed",
                        aria: { expanded: "false",
                                controls: "edit_notes_#{key.id}_container" },
                        data: { toggle: "collapse", role: "edit_api_key",
                                target: "#edit_notes_#{key.id}_container",
                                parent: "#notes_#{key.id}" }))
    end
  end

  def api_keys_edit_notes_container(key)
    tag.div(class: "collapse no-transition",
            id: "edit_notes_#{key.id}_container") do
      form_with(model: key, url: account_api_key_path(key.id),
                method: :patch, local: false,
                id: "edit_api_key_#{key.id}_form") do |f|
        tag.div(class: "input-group") do
          concat(
            tag.span(class: "input-group-btn") do
              tag.button(link_icon(:cancel, title: :CANCEL.l),
                         type: :button,
                         class: "btn btn-outline-secondary",
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
            f.button(:SAVE.l, type: :submit, class: "btn btn-default")
          end)
        end
      end
    end
  end

  def api_keys_remove_button(key)
    destroy_button(name: :REMOVE.l, icon: :remove, remote: true,
                   id: "remove_api_key_#{key.id}",
                   class: "btn btn-link text-danger",
                   target: account_api_key_path(key.id))
  end

  def api_keys_new_form_row
    tag.td(colspan: 7) do
      tag.div(class: "accordion border-none mb-0", id: "new_key_row") do
        tag.div(class: "card border-none") do
          [
            api_keys_new_button_container,
            api_keys_new_form_container
          ].safe_join
        end
      end
    end
  end

  def api_keys_new_button_container
    button_text = [
      link_icon(:add), :account_api_keys_create_button.l
    ].safe_join(" ")

    tag.div(class: "collapse show no-transition",
            id: "new_key_button_container") do
      button_tag(button_text,
                 type: :button, id: "new_key_button",
                 class: "btn btn-outline-secondary collapsed",
                 aria: { expanded: "false",
                         controls: "new_key_form_container" },
                 data: { toggle: "collapse",
                         target: "#new_key_form_container",
                         parent: "#new_key_row" })
    end
  end

  def api_keys_new_form_container
    tag.div(class: "collapse no-transition",
            id: "new_key_form_container") do
      form_with(model: APIKey.new, url: account_api_keys_path,
                method: :post, local: false,
                id: "new_api_key_form") do |f|
        concat(f.label(:notes, :account_api_keys_notes_label.t))
        concat(tag.div(class: "input-group") do
          concat(
            tag.span(class: "input-group-btn") do
              tag.button(link_icon(:cancel, title: :CANCEL.l),
                         type: :button,
                         class: "btn btn-default",
                         aria: { expanded: "true",
                                 controls: "new_key_button_container" },
                         data: { toggle: "collapse",
                                 target: "#new_key_button_container",
                                 parent: "#new_key_row" })
            end
          )
          concat(f.text_field(:notes, size: 40, id: "new_api_key_notes",
                                      class: "form-control border-none"))
          concat(tag.span(class: "input-group-btn") do
            f.button(:CREATE.l, type: :submit, class: "btn btn-default")
          end)
        end)
      end
    end
  end
end
