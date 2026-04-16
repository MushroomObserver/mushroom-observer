# frozen_string_literal: true

module Views
  module Controllers
    module Projects
      # Phlex view for the edit project form page.
      # Replaces edit.html.erb.
      class Edit < Views::Base
        register_output_helper :add_edit_title
        register_output_helper :add_context_nav
        register_value_helper :project_form_edit_tabs

        def initialize(project:, dates_any:, upload_params:)
          super()
          @project = project
          @dates_any = dates_any
          @upload_params = upload_params
        end

        def view_template
          add_edit_title(@project.title, @project)
          add_context_nav(
            project_form_edit_tabs(project: @project)
          )

          render(Components::ProjectForm.new(
                   @project,
                   enctype: "multipart/form-data",
                   dates_any: @dates_any,
                   upload_params: @upload_params
                 ))
        end
      end
    end
  end
end
