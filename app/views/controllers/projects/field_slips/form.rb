# frozen_string_literal: true

# Phlex form for creating project field slips. Rendered by
# `Projects::FieldSlipsController#new`.
module Views::Controllers::Projects::FieldSlips
  class Form < ::Components::ApplicationForm
    def initialize(model, project:, **)
      @project = project
      super(model, local: false, **)
    end

    def view_template
      super do
        number_field(:field_slips, label: :field_slips,
                                   inline: true, min: 0)
        checkbox_field(:one_per_page,
                       label: :field_slips_one_per_page)
        submit(:create.ti, class: "ml-3")
      end
    end

    private

    def form_action
      project_field_slips_path(project_id: @project.id)
    end
  end
end
