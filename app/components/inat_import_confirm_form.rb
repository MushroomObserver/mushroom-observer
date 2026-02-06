# frozen_string_literal: true

# Confirmation form for iNat import.
# Shows estimated import count and Proceed/Go Back buttons.
# Hidden fields carry form data through the confirmation step.
class Components::InatImportConfirmForm < Components::ApplicationForm
  def initialize(model, estimate: nil, inat_import: nil, **)
    @estimate = estimate
    @inat_import = inat_import
    super(model, **)
  end

  def view_template
    render_estimate
    render_explanation
    render_prompt
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
        count_estimate_line
        br
        time_estimate_line
      end
    end
  end

  def count_estimate_line
    b { plain(:inat_import_confirm_estimate_caption.l) }
    plain(": ")
    plain(estimated_count)
  end

  def estimated_count
    @estimate&.to_s ||
      :inat_import_confirm_estimate_unavailable.l
  end

  def time_estimate_line
    b { plain(:inat_import_confirm_time_estimate_caption.l) }
    plain(": ")
    plain(estimated_time)
  end

  def estimated_time
    return :inat_import_confirm_time_estimate_unavailable.l unless @estimate

    seconds = @estimate * avg_import_seconds
    format_hms(seconds)
  end

  def avg_import_seconds
    @inat_import&.initial_avg_import_seconds ||
      InatImport::BASE_AVG_IMPORT_SECONDS
  end

  def format_hms(seconds)
    hours = seconds / 3600
    minutes = (seconds % 3600) / 60
    remaining = seconds % 60
    Kernel.format("%02d:%02d:%02d", hours, minutes, remaining)
  end

  def render_explanation
    p { plain(:inat_import_confirm_explanation.l) }
  end

  def render_prompt
    p { plain(:inat_import_confirm_prompt.l) }
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
