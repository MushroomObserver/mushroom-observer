# frozen_string_literal: true

# Helper methods for modal dialogs and forms
module ModalsHelper
  # Renders either a Superform component or a legacy ERB partial for modal
  # forms. This allows gradual migration from ERB partials to Superform.
  #
  # @param form [String] The form path (e.g., "collection_numbers/form")
  # @param model [ActiveRecord::Base] The model instance for the form
  # @param observation [Observation] Optional observation instance
  # @param back [String] Optional back parameter
  # @param form_locals [Hash] Locals to pass to the form
  # @return [String] Rendered HTML
  def render_form_or_component(form, model:, observation: nil, back: nil,
                               **form_locals)
    # Map form paths to their corresponding component classes
    component_map = {
      "collection_numbers/form" => Components::CollectionNumberForm,
      "sequences/form" => Components::SequenceForm
    }

    component_class = component_map[form]

    if component_class
      render_modal_component(component_class, model, observation, back)
    else
      render(partial: form, locals: form_locals)
    end
  end

  private

  def render_modal_component(component_class, model, observation, back)
    params = build_component_params(component_class, model, observation, back)
    render(component_class.new(model, **params))
  end

  def build_component_params(component_class, model, observation, back)
    params = { local: false } # Modal forms are turbo forms
    add_observation_param(params, model, observation, component_class)
    params[:back] = back if back
    params
  end

  def add_observation_param(params, model, observation, component_class)
    case component_class.name
    when "Components::CollectionNumberForm"
      params[:observation] = observation
    when "Components::SequenceForm"
      params[:observation] = observation || model&.observation
    end
  end
end
