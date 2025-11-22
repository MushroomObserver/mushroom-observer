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
    # Map model classes to their corresponding component classes
    component_map = {
      Comment: Components::CommentForm,
      ExternalLink: Components::ExternalLinkForm,
      HerbariumRecord: Components::HerbariumRecordForm,
      CollectionNumber: Components::CollectionNumberForm,
      Sequence: Components::SequenceForm
    }

    component_class = component_map[model.class.name.to_sym]

    if component_class
      render_modal_component(
        component_class,
        model,
        observation,
        back,
        form_locals
      )
    else
      render(partial: form, locals: form_locals)
    end
  end

  private

  def render_modal_component(component_class, model, observation, back, locals)
    params = build_component_params(
      component_class,
      model,
      observation,
      back,
      locals
    )
    render(component_class.new(model, **params))
  end

  def build_component_params(component_class, model, observation, back, locals)
    params = { local: false } # Modal forms are turbo forms
    add_observation_param(params, model, observation, component_class)
    add_form_specific_params(params, component_class, locals)
    params[:back] = back if back
    params
  end

  def add_observation_param(params, model, observation, component_class)
    case model.class.name.to_sym
    when :CollectionNumber, :HerbariumRecord, :ExternalLink
      params[:observation] = observation
    when :Sequence
      params[:observation] = observation || model&.observation
    end
  end

  def add_form_specific_params(params, component_class, locals)
    if component_class == Components::ExternalLinkForm
      params[:user] = locals[:user] if locals[:user]
      params[:sites] = locals[:sites] if locals[:sites]
      params[:site] = locals[:site] if locals[:site]
      params[:base_urls] = locals[:base_urls] if locals[:base_urls]
    end
  end
end
