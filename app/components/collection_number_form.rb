# frozen_string_literal: true

# Form for creating or editing collection numbers.
# Collection numbers are specimen identifiers assigned by collectors.
class Components::CollectionNumberForm < Components::ApplicationForm
  def initialize(model, observation: nil, back: nil, **)
    @observation = observation || model.observations.first
    @back = back
    super(model, **)
  end

  def view_template
    render_multiple_observations_warning if show_warning?
    render_name_field
    render_number_field
    submit(submit_text, center: true)
  end

  private

  def render_multiple_observations_warning
    Alert(
      message: :edit_affects_multiple_observations.t(
        type: :collection_number
      ),
      level: :warning,
      class: "multiple-observations-warning"
    )
  end

  def show_warning?
    model.persisted? && model.observations.size > 1
  end

  def render_name_field
    render(
      field(:name).text(
        wrapper_options: {
          label: :collection_number_name.l,
          between: :required,
          data: { autofocus: true }
        }
      )
    )
  end

  def render_number_field
    render(
      field(:number).text(
        wrapper_options: {
          label: :collection_number_number.l,
          between: :required
        }
      )
    )
  end

  def submit_text
    model.persisted? ? :SAVE.l : :ADD.l
  end

  def form_action
    if model.persisted?
      url_params = { action: :update }
      url_params[:back] = @back if @back.present?
      url_for(
        controller: "collection_numbers",
        action: :update,
        id: model.id,
        **url_params,
        only_path: true
      )
    else
      url_for(
        controller: "collection_numbers",
        action: :create,
        observation_id: @observation.id,
        only_path: true
      )
    end
  end
end
