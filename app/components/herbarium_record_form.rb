# frozen_string_literal: true

# Form for creating or editing herbarium records attached to observations
class Components::HerbariumRecordForm < Components::ApplicationForm
  def initialize(model, observation: nil, back: nil, **)
    @observation = observation || model.observations.first
    @back = back
    super(model, **)
  end

  def view_template
    render_multiple_observations_warning if model.observations.size > 1
    render_herbarium_name_field
    render_initial_det_field
    render_accession_number_field
    render_accession_help
    render_notes_field
    submit(submit_text, center: true)
  end

  private

  def render_multiple_observations_warning
    Alert(
      message: :edit_affects_multiple_observations.t(
        type: :herbarium_record
      ),
      level: :warning,
      class: "multiple-observations-warning"
    )
  end

  def render_herbarium_name_field
    render(
      field(:herbarium_name).autocompleter(
        type: :herbarium,
        wrapper_options: {
          label: :NAME.l,
          between: :required
        }
      )
    )
  end

  def render_initial_det_field
    render(
      field(:initial_det).text(
        wrapper_options: {
          label: :herbarium_record_initial_det.l,
          between: :optional
        }
      )
    )
  end

  def render_accession_number_field
    render(
      field(:accession_number).text(
        wrapper_options: {
          label: :herbarium_record_accession_number.l,
          between: :required
        }
      )
    )
  end

  def render_accession_help
    help_block_with_arrow("up") do
      :create_herbarium_record_accession_number_help.t
    end
  end

  def render_notes_field
    render(
      field(:notes).textarea(
        rows: 6,
        wrapper_options: {
          label: :NOTES.l,
          between: :optional
        }
      )
    )
  end

  def submit_text
    model.persisted? ? :SAVE.l : :ADD.l
  end

  def form_action
    if model.persisted?
      url_params = { action: :update, id: model.id }
      url_params[:back] = @back if @back.present?
      url_for(
        controller: "herbarium_records",
        **url_params,
        only_path: true
      )
    else
      url_for(
        controller: "herbarium_records",
        action: :create,
        observation_id: @observation.id,
        only_path: true
      )
    end
  end
end
