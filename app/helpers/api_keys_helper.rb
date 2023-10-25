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

  # make this index_rows, and then the row is an edit form.
  def api_keys_edit_form_rows(user)
    rows = []

    api_keys_sorted(user).each do |key|
      # These are the fields in each row
      verified = if key.verified
                   api_keys_dummy_verified_check_box
                 else
                   patch_button(name: :ACTIVATE.l,
                                path: account_api_key_path(key.id))
                 end
      last_used = key.last_used ? key.last_used.web_date : "--"
      num_uses = key.num_uses.positive? ? key.num_uses : "--"
      edit_section = api_keys_notes_section(key)
      remove_button = destroy_button(name: :REMOVE.l, icon: :remove,
                                     class: "btn btn-link text-danger",
                                     target: account_api_key_path(key.id))
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
    rows
  end

  def api_keys_sorted(user)
    user.api_keys.sort_by do |key|
      last_use = (Time.zone.now - key.last_used) rescue 0
      [-key.num_uses, last_use, key.id]
    end
  end

  def api_keys_dummy_verified_check_box
    tag.div(class: "checkbox my-0") do
      tag.label(:verified) do
        concat(check_box_tag(:verified, "verified", true, disabled: true))
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
    tag.div(class: "panel-group border-none mb-0", id: "key_notes_#{key.id}") do
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
            id: "view_notes_container") do
      concat(tag.span(key.notes.t, class: "current_notes mr-4"))
      concat(button_tag(:EDIT.t,
                        type: :button,
                        class: "btn btn-default collapsed",
                        aria: { expanded: "false",
                                controls: "edit_notes_container" },
                        data: { toggle: "collapse",
                                target: "#edit_notes_container",
                                parent: "#key_notes_#{key.id}" }))
    end
  end

  def api_keys_edit_notes_container(key)
    tag.div(class: "panel-collapse collapse no-transition",
            id: "edit_notes_container") do
      form_with(model: key, url: account_api_key_path(key.id),
                method: :patch, remote: true,
                id: "edit_api_key_form") do |f|
        # concat(f.hidden_field(:id, key.id))
            # "key_notes_input_#{key.id}"
        tag.div(class: "input-group") do
          concat(
            tag.span(class: "input-group-btn") do
              button_tag(:CANCEL.l,
                         type: :button,
                         class: "btn btn-default",
                         aria: { expanded: "true",
                                 controls: "view_notes_container" },
                         data: { toggle: "collapse",
                                 target: "#view_notes_container",
                                 parent: "#key_notes_#{key.id}" })
            end
          )
          concat(f.text_field(:notes, value: key.notes,
                                      class: "form-control border-none"))
          concat(tag.span(class: "input-group-btn") do
            f.button(:SAVE.l, type: :submit, class: "btn btn-default")
          end)
        end
      end
    end
  end
end
