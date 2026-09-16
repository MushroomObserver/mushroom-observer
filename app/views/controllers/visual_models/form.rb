# frozen_string_literal: true

module Views::Controllers::VisualModels
  # Form for creating or editing visual models. Visual models are
  # used to organize visual groups for image classification.
  # Rendered directly by the visual_models controller's
  # `new.rb`.
  class Form < ::Components::ApplicationForm
    def view_template
      super do
        render(Components::Form::Errors.new(model: model))
        render_name_field
        submit(:submit.ti, center: true)
      end
    end

    private

    def render_name_field
      div(class: "form-group field") do
        text_field(:name, class: "form-control", label: false)
        whitespace
        plain(:visual_model.ti)
      end
    end
  end
end
