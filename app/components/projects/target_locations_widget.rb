# frozen_string_literal: true

module Components
  module Projects
    # Inline form for adding target locations to a Project. Posts a
    # list of location names (textarea, newline-separated) to
    # `project_target_locations_path` via Turbo, so the surrounding
    # locations table re-renders without a full page reload.
    #
    # Replaces app/views/controllers/projects/target_locations/
    # _widget.html.erb.
    class TargetLocationsWidget < Components::Base
      include Phlex::Rails::Helpers::FormWith

      register_output_helper :autocompleter_field, mark_safe: true

      prop :project, Project

      def view_template
        div(id: "target_locations_widget") do
          form_with(url: project_target_locations_path(project_id: @project.id),
                    method: :post,
                    class: "form-inline mb-3",
                    data: { turbo: true }) do |f|
            autocompleter_field(form: f, field: :locations,
                                type: :location,
                                textarea: true,
                                separator: "\n",
                                label: "#{:LOCATIONS.t}:")
            f.submit(:project_target_location_add.t,
                     class: "btn btn-default ml-2 mt-2")
          end
        end
      end
    end
  end
end
