# frozen_string_literal: true

module Views
  module Controllers
    module Projects
      module AdminRequests
        # Phlex view for the admin request form page.
        # Replaces admin_requests/new.html.erb.
        class New < Views::Base
          register_output_helper :add_page_title

          def initialize(project:)
            super()
            @project = project
          end

          def view_template
            add_page_title(
              :admin_request_title.t(title: @project.title)
            )

            render(Components::ProjectAdminRequestForm.new(
                     FormObject::EmailRequest.new,
                     project: @project
                   ))
          end
        end
      end
    end
  end
end
