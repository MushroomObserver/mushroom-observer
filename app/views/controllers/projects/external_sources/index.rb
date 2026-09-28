# frozen_string_literal: true

# The Sources sub-tab of the project Admin tab (#5416): the project's
# iNaturalist source, the two things MO may do with it, and where its
# approval stands.
module Views::Controllers::Projects::ExternalSources
  class Index < Views::FullPageBase
    prop :project, ::Project
    prop :source, ::ProjectExternalSource
    prop :user, ::User

    def view_template
      add_project_banner(@project)
      add_page_title(:project_sources_title.l)
      container_class(:wide)

      render(Views::Controllers::Projects::AdminSubtabs.new(
               project: @project, current_subtab: "sources"
             ))
      p(class: "mt-3") { :project_sources_intro.t }
      render_approval_panel
      render(Form.new(@source, project: @project))
    end

    private

    def render_approval_panel
      Panel(panel_class: panel_class,
            panel_id: "project_source_approval") do |panel|
        panel.with_heading { strong { :project_sources_approval.l } }
        panel.with_body do
          render_approval_state
          render_import_limit
          render_approval_button if in_admin_mode?
        end
      end
    end

    def panel_class
      @source.approved? ? "panel-default mt-3" : "panel-warning mt-3"
    end

    def render_approval_state
      p { approval_state_text }
    end

    def approval_state_text
      return :project_sources_unapproved.t unless @source.approved?

      :project_sources_approved.t(user: @source.approved_by&.login.to_s,
                                  date: @source.approved_at.web_date)
    end

    # A project admin cannot move the ceiling, so state it for them
    # rather than showing a field they may not change.
    def render_import_limit
      return if in_admin_mode?

      p do
        :project_sources_import_limit_shown.t(limit: @source.import_limit)
      end
    end

    def render_approval_button
      return if @source.new_record?

      if @source.approved?
        Button(type: :patch, target: revoke_path,
               name: :project_sources_revoke.l, class: "mt-2")
      else
        Button(type: :patch, target: approve_path,
               name: :project_sources_approve.l, class: "mt-2")
      end
    end

    def approve_path
      approve_project_external_source_path(project_id: @project.id,
                                           id: @source.id)
    end

    def revoke_path
      revoke_project_external_source_path(project_id: @project.id,
                                          id: @source.id)
    end
  end
end
