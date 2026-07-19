# frozen_string_literal: true

module Views::Controllers::Projects
  # Phlex view for the new project form page.
  class New < Views::FullPageBase
    def initialize(project:, dates_any:, upload_params:)
      super()
      @project = project
      @dates_any = dates_any
      @upload_params = upload_params
    end

    def view_template
      add_new_title(:create_object, :project)
      add_context_nav(::Tab::Project::FormNew.new)

      render(Views::Controllers::Projects::Form.new(
               @project,
               enctype: "multipart/form-data",
               dates_any: @dates_any,
               upload_params: @upload_params
             ))
    end
  end
end
