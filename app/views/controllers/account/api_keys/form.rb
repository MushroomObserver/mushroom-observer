# frozen_string_literal: true

module Views::Controllers::Account::APIKeys
  # Form for creating or editing an API key. Only used by the
  # api_keys controller — its three callers are `table.rb` (inline
  # create + inline edit), `new.rb` (standalone create), and
  # `edit.rb` (standalone edit).
  #
  # Four layouts:
  # - Standalone edit (persisted, no cancel_target): metadata table +
  #   notes + Update / Cancel link. Used by `edit.rb` (no-JS
  #   fallback).
  # - Inline edit (persisted + cancel_target): input-group with cancel
  #   icon + notes input + Save button. Used by the JS-driven per-row
  #   notes editor on the index page.
  # - Inline create (new + cancel_target): input-group with cancel
  #   icon + notes input + Create button. Used by the JS-driven inline
  #   create UI on the index page (collapse toggle to dismiss).
  # - Standalone create (new, no cancel_target): notes input + centered
  #   Create button. Used by `new.rb` (no-JS fallback).
  class Form < ::Components::ApplicationForm
    def initialize(model, cancel_target: nil, cancel_parent: nil, **)
      @cancel_target = cancel_target
      @cancel_parent = cancel_parent
      super(model, **)
    end

    def view_template
      if model.persisted?
        @cancel_target ? render_inline_edit_layout : render_edit_layout
      elsif @cancel_target
        render_table_layout
      else
        render_standalone_layout
      end
    end

    private

    def render_table_layout
      label(for: field(:notes).dom.id) { :account_api_keys_notes_label.t }

      InputGroup do
        render_cancel_button if @cancel_target

        text_field(:notes, label: false, size: 40,
                           class: "form-control border-none")

        render(Components::InputGroup::Addon.new) do
          submit(:CREATE.l, submits_with: submits_text)
        end
      end
    end

    # Per-row inline edit: no label (the read-only notes line above
    # the form serves as the visual label), Save button instead of
    # Create. The notes input gets a per-key id so multiple inline
    # forms on the same page don't collide (Superform's default id is
    # class-based, not record-based).
    def render_inline_edit_layout
      InputGroup do
        render_cancel_button

        text_field(:notes, label: false,
                           id: "api_key_#{model.id}_notes",
                           class: "form-control border-none")

        render(Components::InputGroup::Addon.new) do
          submit(:SAVE.l, submits_with: submits_text)
        end
      end
    end

    def render_cancel_button
      render(Components::InputGroup::Addon.new) do
        Link(type: :collapse_toggle,
             target_id: @cancel_target,
             collapsed: false,
             icon: :cancel,
             icon_title: :CANCEL.l,
             button: :default,
             data: { parent: "##{@cancel_parent}" })
      end
    end

    def render_standalone_layout
      text_field(:notes, label: :account_api_keys_notes_label,
                         wrap_class: "mt-3")

      submit(submit_text, center: true, submits_with: submits_text,
                          id: "create_button")
    end

    def render_edit_layout
      render_metadata_table
      text_field(:notes, label: :NOTES, wrap_class: "mt-3")
      div(class: "text-center mt-3") do
        submit(:UPDATE.l)
        # A plain link (not a submit button) — Cancel should navigate
        # back without submitting the form.
        Button(
          type: :get,
          name: :CANCEL.l,
          target: account_api_keys_path,
          class: "ml-3"
        )
      end
    end

    def render_metadata_table
      table do
        metadata_row(:CREATED.t, model.created_at.web_date)
        metadata_row(:account_api_keys_last_used_column_label.t,
                     last_used_value)
        metadata_row(:account_api_keys_num_uses_column_label.t,
                     num_uses_value)
        metadata_row(:API_KEY.t, model.key)
      end
    end

    def last_used_value
      model.last_used&.web_date || "--"
    end

    def num_uses_value
      model.num_uses.positive? ? model.num_uses.to_s : "--"
    end

    def metadata_row(label_text, value)
      tr do
        td { plain("#{label_text}: ") }
        td { plain(value) }
      end
    end

    def submit_text
      :account_api_keys_create_button.l
    end

    def submits_text
      :SAVING.l
    end
  end
end
