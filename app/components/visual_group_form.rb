# frozen_string_literal: true

# Form for creating or editing visual groups within a visual model.
# Visual groups are used to organize and categorize images for visual
# classification training.
class Components::VisualGroupForm < Components::ApplicationForm
  def initialize(model, visual_model:, **)
    @visual_model = visual_model
    super(model, local: true, **)
  end

  def view_template
    super do
      render_errors if model.errors.any?
      render_name_field
      textarea_field(:description, cols: 60, rows: 10,
                                   label: :DESCRIPTION.t)
      checkbox_field(:approved, label: :APPROVED.t)
      submit(:SUBMIT.t, center: true)
    end
  end

  private

  def render_errors
    count = pluralize(model.errors.count, :error.l, plural: :errors.l)

    Alert(level: :danger, id: "error_explanation") do
      h2 { "#{count} prohibited this visual_group from being saved:" }
      ul do
        model.errors.each do |error|
          li { error.full_message }
        end
      end
    end
  end

  def render_name_field
    div(class: "form-group") do
      div(class: "form-inline") do
        text_field(:name, size: 40, class: "form-control", label: false)
        span(class: "ml-3") { :VISUAL_GROUP.t }
      end
    end
  end

  def form_action
    if model.persisted?
      visual_group_path(model)
    else
      visual_model_visual_groups_path(@visual_model)
    end
  end
end
