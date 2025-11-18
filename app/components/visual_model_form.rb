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
    render(Components::Alert.new(level: :danger,
                                 id: "error_explanation")) do
      [error_header, error_list].join.html_safe # rubocop:disable Rails/OutputSafety
    end
  end

  def error_header
    count = view_context.pluralize(model.errors.count, :error.t,
                                   plural: :errors.t)
    view_context.tag.h2("#{count} #{:visual_model_errors.t}:")
  end

  def error_list
    view_context.tag.ul do
      model.errors.each do |error|
        view_context.concat(view_context.tag.li(error.full_message))
      end
    end
  end

  def render_name_field
    div(class: "form-group field") do
      field(:name).label
      field(:name).text(class: "form-control")
      whitespace
      plain(:VISUAL_MODEL.t)
    end
  end
end
