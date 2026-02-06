# frozen_string_literal: true

# Confirmation form for iNat import.
# Shows estimated import count and Proceed/Go Back buttons.
# Hidden fields carry form data through the confirmation step.
class Components::InatImportConfirmForm < Components::ApplicationForm
  def initialize(model, estimate: nil, **)
    @estimate = estimate
    super(model, **)
  end

  def view_template
    render_estimate
    p { plain(:inat_import_confirm_prompt.l) }
    render_hidden_fields
    render_buttons
  end

  def form_action
    inat_imports_path
  end

  private

  def render_estimate
    render(Components::Panel.new) do |panel|
      panel.with_body do
        b { plain(:inat_import_confirm_estimate_caption.l) }
        plain(": ")
        plain(estimated_count)
      end
    end
  end

  def estimated_count
    @estimate&.to_s || :inat_import_confirm_estimate_unavailable.l
  end

  def render_hidden_fields
    hidden_field(:inat_username)
    hidden_field(:inat_ids)
    hidden_field(:import_all)
    hidden_field(:consent)
  end

  def render_buttons
    div(class: "mt-3") do
      proceed_button
      whitespace
      go_back_button
    end
  end

  def proceed_button
    button(name: "confirmed", value: "1",
           type: "submit", class: "btn btn-default") do
      plain(:inat_import_confirm_proceed.l)
    end
  end

  def go_back_button
    button(name: "go_back", value: "1",
           type: "submit", class: "btn btn-default") do
      plain(:inat_import_confirm_go_back.l)
    end
  end
end
