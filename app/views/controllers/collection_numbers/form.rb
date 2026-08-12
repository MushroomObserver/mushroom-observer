# frozen_string_literal: true

module Views::Controllers::CollectionNumbers
  # Form for creating or editing collection numbers. Collection
  # numbers are specimen identifiers assigned by collectors.
  # Rendered directly by the collection_numbers controller's
  # `new.rb` and `edit.rb`, and dynamically by
  # `Components::Modal::TurboForm` via `form_component_class_for`.
  class Form < ::Components::ApplicationForm
    prop :observation, ::Observation
    prop :back, _Nilable(String), default: nil

    def initialize(model, observation: nil, **)
      super(model, observation: observation || model.observations.first, **)
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
      text_field(:name,
                 label: :collection_number_name,
                 between: :required,
                 data: { autofocus: true })
    end

    def render_number_field
      text_field(:number,
                 label: :collection_number_number,
                 between: :required)
    end

    def submit_text
      model.persisted? ? :save.ti : :add.ti
    end

    def form_action
      if model.persisted?
        url_params = { action: :update }
        url_params[:back] = @back if @back.present?
        url_for(
          controller: "collection_numbers",
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
end
