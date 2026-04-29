# frozen_string_literal: true

module Components
  module Projects
    # Inline form for adding target names to a Project. Posts a list
    # of names (textarea, newline-separated) to
    # `project_target_names_path` via Turbo, so the surrounding
    # checklist re-renders without a full page reload.
    #
    # Replaces app/views/controllers/projects/target_names/
    # _widget.html.erb.
    class TargetNamesWidget < Components::Base
      include Phlex::Rails::Helpers::FormWith

      register_output_helper :autocompleter_field, mark_safe: true

      prop :project, Project

      def view_template
        div(id: "target_names_widget") do
          form_with(url: project_target_names_path(project_id: @project.id),
                    method: :post,
                    class: "form-inline mb-3",
                    data: { turbo: true }) do |f|
            autocompleter_field(form: f, field: :names,
                                type: :name,
                                textarea: true,
                                separator: "\n",
                                label: :project_target_names_to_add_label.t)
            f.submit(:project_target_name_add.t,
                     class: "btn btn-default ml-2 mt-2")
          end
        end
      end
    end
  end
end
