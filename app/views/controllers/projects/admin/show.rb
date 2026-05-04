# frozen_string_literal: true

module Views
  module Controllers
    module Projects
      module Admin
        # Admin tab default landing (Details sub-tab). Renders the
        # project edit form for in-place edits, plus a Danger Zone
        # section with the Delete Project action. Sub-tabs sit above
        # the form so the user can swap to Members or Aliases without
        # leaving the Admin context.
        class Show < Views::Base
          register_output_helper :add_project_banner
          register_output_helper :add_page_title
          register_output_helper :destroy_button, mark_safe: true
          register_value_helper :container_class

          def initialize(project:, user:, dates_any:, upload_params:)
            super()
            @project = project
            @user = user
            @dates_any = dates_any
            @upload_params = upload_params
          end

          def view_template
            add_project_banner(@project)
            add_page_title(:show_project_admin_title.l)
            container_class(:wide)

            render(Components::Projects::AdminSubtabs.new(
                     project: @project, current_subtab: "details"
                   ))
            render_form
            render_danger_zone
          end

          private

          def render_form
            render(Components::ProjectForm.new(
                     @project,
                     enctype: "multipart/form-data",
                     dates_any: @dates_any,
                     upload_params: @upload_params,
                     dirty_form: true
                   ))
          end

          def render_danger_zone
            render(Components::Panel.new(
                     panel_class: "panel-danger mt-4",
                     panel_id: "project_danger_zone"
                   )) do |panel|
              panel.with_heading do
                strong { plain(:show_project_admin_danger_zone.l) }
              end
              panel.with_body { render_destroy }
            end
          end

          def render_destroy
            p { plain(:show_project_admin_destroy_help.l) }
            # The destroy_button helper auto-applies text-danger, which
            # provides the red color cue against a default button bg.
            destroy_button(
              target: @project,
              name: :destroy_object.t(type: :project),
              class: "btn btn-default btn-lg"
            )
          end
        end
      end
    end
  end
end
