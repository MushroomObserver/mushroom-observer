# frozen_string_literal: true

#  ==== Where a project's observations may come from, and what MO may
#  do about them (#5416)
#
#  index::    the configuration page, under the project Admin tab
#  create::   first save, which is what brings the row into being
#  update::   later saves
#  approve::  site admin lets the project act on its source
#  revoke::   site admin withdraws that
#
#  Only iNaturalist is offered. The model holds a row per site so that a
#  second site can be added without re-shaping the table, but MyCoPortal
#  exchanges files rather than answering queries (#5422), so there is
#  nothing for a project to configure about it yet.
module Projects
  class ExternalSourcesController < ApplicationController
    before_action :login_required

    # Sources live under the project Admin tab.
    def active_project_tab
      "admin"
    end
    helper_method :active_project_tab

    def index
      return unless find_project_as_admin!

      render_index_view
    end

    def create
      return unless find_project_as_admin!

      @source = @project.project_external_sources.new(
        source_params.merge(external_site: ExternalSite.inaturalist)
      )
      save_source
    end

    def update
      return unless find_project_as_admin!
      return unless source_found?

      @source.assign_attributes(source_params)
      save_source
    end

    def approve
      return unless find_project_as_site_admin!
      return unless source_found?

      @source.approve(@user)
      flash_notice(:project_sources_approve_success.t)
      redirect_to_index
    end

    def revoke
      return unless find_project_as_site_admin!
      return unless source_found?

      @source.revoke
      flash_notice(:project_sources_revoke_success.t)
      redirect_to_index
    end

    private

    def save_source
      if @source.save
        flash_notice(:project_sources_updated.t)
        redirect_to_index
      else
        flash_object_errors(@source)
        render_index_view_invalid
      end
    end

    def render_index_view(status: :ok, **render_opts)
      render(Views::Controllers::Projects::ExternalSources::Index.new(
               project: @project, source: @source, user: @user
             ),
             status: status, **render_opts)
    end

    # The form posts back to the page it was rendered on, so a
    # validation failure has to answer non-2xx or Turbo Drive treats
    # the redisplay as a successful visit.
    def render_index_view_invalid(**)
      render_index_view(**)
      self.status = :unprocessable_content
    end

    def redirect_to_index
      redirect_to(project_external_sources_path(project_id: @project.id))
    end

    def find_project!
      @project = Project.safe_find(params[:project_id].to_s) ||
                 flash_error_and_goto_index(Project, params[:project_id].to_s)
    end

    def find_project_as_admin!
      return nil unless find_project!
      return nil unless project_admin?

      @source ||= source_for_project
      @project
    end

    def find_project_as_site_admin!
      return nil unless find_project!
      return nil unless site_admin?

      @project
    end

    # Approval and the settings form act on the same row, so both find
    # it by id and check it belongs to the project in the URL.
    def source_found?
      @source = @project.project_external_sources.find_by(id: params[:id])
      return true if @source

      flash_error(:runtime_object_not_found.t(type: :project, id: params[:id]))
      redirect_to_index
      false
    end

    # An unsaved row rather than nil, so the form has something to draw
    # and `create` is the natural first save.
    def source_for_project
      @project.project_external_sources.
        find_by(external_site: ExternalSite.inaturalist) ||
        @project.project_external_sources.new(
          external_site: ExternalSite.inaturalist
        )
    end

    # A project admin configures the source. A site admin can reach
    # the page too, since approval is theirs to give and they are not
    # ordinarily a member of the project.
    def project_admin?
      return true if @project.is_admin?(@user) || in_admin_mode?

      deny_access
      false
    end

    def site_admin?
      return true if in_admin_mode?

      deny_access
      false
    end

    def deny_access
      flash_error(:permission_denied.t)
      redirect_to(project_path(@project.id))
    end

    # A project admin configures the source; only a site admin moves the
    # ceiling, which is why `import_limit` is permitted conditionally
    # rather than rendered read-only and trusted.
    def source_params
      permitted = [:remote_project_id, :use_criteria, :alerting, :importing]
      permitted << :import_limit if in_admin_mode?
      params.require(:project_external_source).permit(*permitted)
    end
  end
end
