# frozen_string_literal: true

module Views::Controllers::Account::APIKeys
  # Renders the account/api_keys index page table — the list of
  # the user's keys plus the "+ Add Key" accordion below.
  # Shared between the index page render and the post-CUD
  # turbo_stream response (which replaces just this block).
  class Table < Views::Base
    def initialize(user:)
      super()
      @user = user
    end

    def view_template
      render_keys_table
      render_new_form_panel
    end

    private

    # Most-used first, then by recency of last use, then by id.
    # Last-use delta is computed in Ruby (can't sort by
    # `now - last_used` in SQL easily) so we post-fetch sort.
    def sorted_keys
      @user.api_keys.sort_by do |key|
        last_use = begin
                     (Time.zone.now - key.last_used)
                   rescue StandardError
                     0
                   end
        [-key.num_uses, last_use, key.id]
      end
    end

    def render_keys_table
      render(Components::Table.new(
               sorted_keys,
               id: "account_api_keys_table",
               class: "table-striped table-layout-fixed"
             )) do |t|
        register_table_columns(t)
      end
    end

    def register_table_columns(table)
      register_status_columns(table)
      register_usage_columns(table)
      register_action_columns(table)
    end

    def register_status_columns(table)
      table.column(:account_api_keys_active_column_label.t) do |key|
        render_verified_or_activate(key)
      end
      table.column(:CREATED.t) { |key| key.created_at.web_date }
    end

    def register_usage_columns(table)
      table.column(:account_api_keys_last_used_column_label.t) do |key|
        key.last_used ? key.last_used.web_date : "--"
      end
      table.column(:account_api_keys_num_uses_column_label.t) do |key|
        key.num_uses.positive? ? key.num_uses : "--"
      end
      table.column(:API_KEY.t, &:key)
    end

    def register_action_columns(table)
      table.column(:NOTES.t) { |key| render_notes_accordion(key) }
      table.column("") { |key| render_remove_button(key) }
    end

    def render_verified_or_activate(key)
      div(id: "api_key_#{key.id}") do
        if key.verified
          render_verified_check_box(key)
        else
          render(Components::Button.new(
                   type: :patch,
                   name: :ACTIVATE.l,
                   target: account_activate_api_key_path(key.id),
                   id: "activate_api_key_#{key.id}"
                 ))
        end
      end
    end

    # Read-only ✓ for verified keys, rendered via CheckboxField
    # so the markup stays in lockstep with form-mode checkboxes
    # (BS3/4/5 migration changes one file, not many). The
    # `disabled:` mode skips the hidden sidecar.
    def render_verified_check_box(key)
      render(Components::ApplicationForm::CheckboxField.new(
               Components::ApplicationForm::FieldProxy.new(
                 nil, "verified_key_#{key.id}", true
               ),
               wrapper_options: { label: false, wrap_class: "my-0" },
               disabled: true
             ))
    end

    def render_notes_accordion(key)
      render(Components::Form::TableAccordion.new(
               id: "notes_#{key.id}",
               view_id: "view_notes_#{key.id}_container",
               edit_id: "edit_notes_#{key.id}_container"
             )) do |accordion|
        accordion.with_view { render_view_notes(key) }
        accordion.with_edit { render_edit_notes_form(key) }
      end
    end

    def render_view_notes(key)
      span(class: "current_notes mr-4") { trusted_html(key.notes.t) }
      render(Components::Button.new(
               name: :EDIT.l,
               icon: :edit,
               class: "collapsed",
               aria: { expanded: "false",
                       controls: "edit_notes_#{key.id}_container" },
               data: { toggle: "collapse",
                       role: "edit_api_key",
                       target: "#edit_notes_#{key.id}_container",
                       parent: "#notes_#{key.id}" }
             ))
    end

    def render_edit_notes_form(key)
      render(Form.new(
               key,
               action: account_api_key_path(key.id),
               id: "edit_api_key_#{key.id}_form",
               data: { turbo: true },
               cancel_target: "view_notes_#{key.id}_container",
               cancel_parent: "notes_#{key.id}"
             ))
    end

    def render_remove_button(key)
      render(Components::Button.new(
               type: :delete,
               target: account_api_key_path(key.id),
               name: :REMOVE.l,
               variant: :outline,
               icon: :remove,
               id: "remove_api_key_#{key.id}"
             ))
    end

    def render_new_form_panel
      render(Components::Form::TableAccordion.new(
               id: "new_key_row",
               view_id: "new_key_button_container",
               edit_id: "new_key_form_container"
             )) do |accordion|
        accordion.with_view { render_new_button }
        accordion.with_edit { render_new_form }
      end
    end

    # Rendered as a real `<a href=/new>` link so it gracefully
    # falls back to the standalone create page when JS is
    # disabled. With JS, Bootstrap collapse.js intercepts the
    # click via `data-toggle="collapse"` and prevents the
    # default navigation.
    def render_new_button
      render(Components::Button.new(
               type: :get,
               name: :account_api_keys_create_button.l,
               target: new_account_api_key_path,
               id: "new_key_button",
               class: "collapsed",
               aria: { expanded: "false",
                       controls: "new_key_form_container" },
               data: { toggle: "collapse",
                       target: "#new_key_form_container",
                       parent: "#new_key_row" }
             ))
    end

    def render_new_form
      render(Form.new(
               ::APIKey.new,
               action: account_api_keys_path,
               id: "new_api_key_form",
               data: { turbo: true },
               cancel_target: "new_key_button_container",
               cancel_parent: "new_key_row"
             ))
    end
  end
end
