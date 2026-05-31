# frozen_string_literal: true

module Views::Controllers::Projects::AdminRequests
  # Phlex view for the admin request form page.
  # Replaces admin_requests/new.html.erb.
  class New < Views::Base
    def initialize(project:)
      super()
      @project = project
    end

    def view_template
      add_page_title(
        :admin_request_title.t(title: @project.title)
      )

      render(Views::Controllers::Projects::AdminRequests::Form.new(
               FormObject::EmailRequest.new,
               project: @project
             ))
    end
  end
end
