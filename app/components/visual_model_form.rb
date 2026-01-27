# frozen_string_literal: true

# Form for creating or editing visual models.
# Visual models are used to organize visual groups for image classification.
class Components::VisualModelForm < Components::ApplicationForm
  def view_template
    super do
      render_errors if model.errors.any?
      render_name_field
      submit(:SUBMIT.t, center: true)
    end
  end

  private

  def render_errors
    count = pluralize(model.errors.count, :error.l, plural: :errors.l)

    Alert(level: :danger, id: "error_explanation") do
      h2 { "#{count} #{:visual_model_errors.l}:" }
      ul do
        model.errors.each do |error|
          li { error.full_message }
        end
      end
    end
  end

  def render_name_field
    div(class: "form-group field") do
      render(field(:name).text(class: "form-control"))
      whitespace
      plain(:VISUAL_MODEL.t)
    end
  end
end
