# frozen_string_literal: true

module Views::Controllers::VisualGroups
  # Form for creating or editing visual groups within a visual model.
  # Visual groups are used to organize and categorize images for
  # visual classification training. Rendered directly by the
  # visual_groups controller's `edit.rb`.
  class Form < ::Components::ApplicationForm
    prop :visual_model, ::VisualModel

    def view_template
      super do
        render(Components::Form::Errors.new(model: model))
        render_name_field
        textarea_field(:description, cols: 60, rows: 10,
                                     label: :description.ti)
        checkbox_field(:approved, label: :approved.ti)
        submit(:submit.ti, center: true)
      end
    end

    private

    def render_name_field
      div(class: "form-group") do
        div(class: "form-inline") do
          text_field(:name, size: 40, class: "form-control", label: false)
          span(class: "ml-3") { :visual_group.ti }
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
end
