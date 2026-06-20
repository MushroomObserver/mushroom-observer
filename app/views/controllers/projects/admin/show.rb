# frozen_string_literal: true

module Views::Controllers::Projects::Admin
  # Admin tab default landing (Details sub-tab). Renders the
  # project edit form for in-place edits, plus a Danger Zone
  # section with the Delete Project action. Sub-tabs sit above
  # the form so the user can swap to Members or Aliases without
  # leaving the Admin context.
  class Show < Views::FullPageBase
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

      render(Views::Controllers::Projects::AdminSubtabs.new(
               project: @project, current_subtab: "details"
             ))
      render_form
      render_danger_zone
    end

    private

    def render_form
      render(Views::Controllers::Projects::Form.new(
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
      # Danger Zone overrides the default outline button entirely —
      # this is a primary, page-level destructive action and we want
      # a filled, large button. Everything goes through `style:` since
      # it's a full override of `Button::Delete`'s default.
      render(Components::Button::Delete.new(
               target: @project,
               name: :destroy_object.t(type: :project),
               style: :default, size: :lg
             ))
    end
  end
end
