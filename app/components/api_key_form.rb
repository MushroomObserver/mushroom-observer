# frozen_string_literal: true

# Form for creating or editing an API key.
#
# Three layouts:
# - Edit (model persisted): metadata table + notes + Update / Cancel.
#   Used by `account/api_keys/edit.html.erb` — a no-JS fallback view.
# - Inline create (`cancel_target:` set): input-group with cancel
#   icon + notes input + Create button. Used by JS-driven inline
#   create UI (collapse toggle to dismiss).
# - Standalone create (no cancel_target, model new): notes input +
#   centered Create button. Used by `account/api_keys/new.html.erb`.
class Components::APIKeyForm < Components::ApplicationForm
  def initialize(model, cancel_target: nil, cancel_parent: nil, **)
    @cancel_target = cancel_target
    @cancel_parent = cancel_parent
    super(model, **)
  end

  def view_template
    if model.persisted?
      render_edit_layout
    elsif @cancel_target
      render_table_layout
    else
      render_standalone_layout
    end
  end

  private

  def render_table_layout
    label(for: field(:notes).dom.id) { :account_api_keys_notes_label.t }

    div(class: "input-group") do
      render_cancel_button if @cancel_target

      text_field(:notes, label: false, size: 40,
                         class: "form-control border-none")

      span(class: "input-group-btn") do
        submit(:CREATE.l, submits_with: submits_text)
      end
    end
  end

  def render_cancel_button
    span(class: "input-group-btn") do
      button(type: :button,
             class: "btn btn-default",
             aria: { expanded: "true", controls: @cancel_target },
             data: { toggle: "collapse",
                     target: "##{@cancel_target}",
                     parent: "##{@cancel_parent}" }) do
        link_icon(:cancel, title: :CANCEL.l)
      end
    end
  end

  def render_standalone_layout
    text_field(:notes, label: :account_api_keys_notes_label.t,
                       wrap_class: "mt-3")

    submit(submit_text, center: true, submits_with: submits_text,
                        id: "create_button")
  end

  def render_edit_layout
    render_metadata_table
    text_field(:notes, label: "#{:NOTES.t}:", wrap_class: "mt-3")
    div(class: "text-center mt-3") do
      submit(:UPDATE.l)
      # The original ERB layout has a 5em gap between the two
      # buttons. Preserved here.
      span(style: "margin-left:5em")
      # NOTE: Cancel is a real submit button (matches the pre-Phlex
      # ERB). Clicking it submits the form and the controller does
      # an update with current values — effectively a no-op when the
      # user hasn't changed anything. The "cancel" label is somewhat
      # misleading; cleanup is a follow-up.
      submit(:CANCEL.l)
    end
  end

  def render_metadata_table
    table do
      metadata_row(:CREATED.t, model.created_at.web_date)
      metadata_row(:account_api_keys_last_used_column_label.t,
                   last_used_value)
      metadata_row(:account_api_keys_num_uses_column_label.t, num_uses_value)
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
    :show_namings_saving.l
  end
end
