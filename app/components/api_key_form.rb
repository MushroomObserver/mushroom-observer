# frozen_string_literal: true

# Form for creating API keys
class Components::APIKeyForm < Components::ApplicationForm
  def initialize(model, cancel_button: nil, **)
    @cancel_button = cancel_button
    super(model, **)
  end

  def view_template
    if @cancel_button
      render_table_layout
    else
      render_standalone_layout
    end
  end

  private

  def render_table_layout
    label(for: "new_api_key_notes") { :account_api_keys_notes_label.t }

    div(class: "input-group") do
      # rubocop:disable Lint/Void
      @cancel_button
      # rubocop:enable Lint/Void

      render(field(:notes).text(
               size: 40,
               id: "new_api_key_notes",
               class: "form-control border-none"
             ))

      span(class: "input-group-btn") do
        submit(:CREATE.l, submits_with: submits_text)
      end
    end
  end

  def render_standalone_layout
    text_field(:notes, label: :account_api_keys_notes_label.t,
                       class: "mt-3", id: "new_api_key_notes")

    submit(submit_text, center: true, submits_with: submits_text,
                        id: "create_button")
  end

  def submit_text
    :account_api_keys_create_button.l
  end

  def submits_text
    :show_namings_saving.l
  end
end
