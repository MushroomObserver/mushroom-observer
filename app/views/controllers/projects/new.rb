# frozen_string_literal: true

module Views
  module Controllers
    module Projects
      # Phlex view for the new project form page.
      # Replaces new.html.erb.
      class New < Views::Base
        register_output_helper :add_new_title
        register_output_helper :add_context_nav
        register_value_helper :project_form_new_tabs

        def initialize(project:, dates_any:, upload_params:)
          super()
          @project = project
          @dates_any = dates_any
          @upload_params = upload_params
        end

        def view_template
          add_new_title(:create_object, :PROJECT)
          add_context_nav(project_form_new_tabs)

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
