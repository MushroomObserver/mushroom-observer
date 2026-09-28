# frozen_string_literal: true

#  ==== A project's relationship with each external site (#5416)
#
#  index::   what the project already holds from each site, plus the
#            configuration for the sites MO can act on
#  create::  first save, which is what brings the row into being
#  update::  later saves
#
#  Site admins only, which is how the issue's rollout gate is expressed:
#  a site admin creating the row is the approval, so there is no
#  separate approve step. Opening this to project admins waits until the
#  cycle has run for a while.
#
#  Only iNaturalist has anything to configure. MyCoPortal exchanges
#  files rather than answering queries (#5422), so its panel reports
#  holdings and nothing else.
module Projects
  class ExternalSitesController < ApplicationController
    before_action :login_required

    # External sites live under the project Admin tab.
    def active_project_tab
      "admin"
    end
    helper_method :active_project_tab

    def index
      return unless find_project!

      render_index_view
    end

    def create
      return unless find_project!

      @site = @project.project_external_sites.new(
        site_params.merge(external_site: ExternalSite.inaturalist)
      )
      save_site
    end

    def update
      return unless find_project!
      return unless project_site_found?

      @site.assign_attributes(site_params)
      save_site
    end

    private

    def save_site
      return render_index_view_invalid unless resolve_remote_project
      return render_index_view_invalid unless @site.save

      flash_notice(:project_site_updated.t)
      redirect_to(project_external_sites_path(project_id: @project.id))
    end

    # What the admin typed is a project id, a slug, a URL or a name; MO
    # stores the id and the title it resolved to. A value that names no
    # single iNat project is refused rather than stored, since storing
    # the wrong one would import a stranger's observations. Returns the
    # row when the value resolved (or was cleared), nil when it did not.
    def resolve_remote_project
      typed = @site.remote_project_id.to_s.strip
      return clear_remote_project if typed.blank?
      return @site if typed == @site.remote_project_id_was &&
                      @site.remote_project_name.present?

      store_resolved_project(typed)
    end

    def clear_remote_project
      @site.assign_attributes(remote_project_id: nil,
                              remote_project_name: nil)
      @site
    end

    def store_resolved_project(typed)
      lookup = Inat::ProjectLookup.new(typed)
      found = lookup.resolve
      unless found
        flash_error(lookup.error.t(project: typed))
        return nil
      end

      @site.assign_attributes(remote_project_id: found.id,
                              remote_project_name: found.title)
      @site
    end

    def render_index_view(status: :ok, **render_opts)
      render(Views::Controllers::Projects::ExternalSites::Index.new(
               project: @project, project_sites: project_sites,
               sites: sites, user: @user
             ),
             status: status, **render_opts)
    end

    # The form posts back to the page it was rendered on, so a
    # validation failure has to answer non-2xx or Turbo Drive treats
    # the redisplay as a successful visit.
    def render_index_view_invalid(**)
      flash_object_errors(@site)
      render_index_view(**)
      self.status = :unprocessable_content
    end

    # iNaturalist first, since it is the only site MO can act on; the
    # rest by name.
    def sites
      inat = ExternalSite::INATURALIST_NAME
      @sites ||= ExternalSite.order(:name).to_a.
                 partition { |site| site.name == inat }.flatten
    end

    # The saved rows, plus the unsaved one the form draws on for a site
    # with no row yet. Keyed by site id.
    def project_sites
      rows = @project.project_external_sites.index_by(&:external_site_id)
      inat = ExternalSite.inaturalist
      rows[inat.id] ||= @project.project_external_sites.new(external_site: inat)
      rows[@site.external_site_id] = @site if @site
      rows
    end

    def find_project!
      @project = Project.safe_find(params[:project_id].to_s) ||
                 flash_error_and_goto_index(Project, params[:project_id].to_s)
      return nil unless @project
      return nil unless site_admin?

      @project
    end

    def project_site_found?
      @site = @project.project_external_sites.find_by(id: params[:id])
      return true if @site

      flash_error(:runtime_object_not_found.t(type: :project, id: params[:id]))
      redirect_to(project_external_sites_path(project_id: @project.id))
      false
    end

    def site_admin?
      return true if in_admin_mode?

      flash_error(:permission_denied.t)
      redirect_to(project_path(@project.id))
      false
    end

    def site_params
      params.require(:project_external_site).
        permit(:remote_project_id, :use_constraints, :alerting, :importing,
               :import_limit)
    end
  end
end
