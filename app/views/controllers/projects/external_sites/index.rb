# frozen_string_literal: true

# The External Sites sub-tab of the project Admin tab (#5416): one panel
# per external site, each saying what the project already holds from
# that site, and, where MO can act on it, how.
module Views::Controllers::Projects::ExternalSites
  class Index < Views::FullPageBase
    prop :project, ::Project
    prop :sites, _Array(::ExternalSite)
    prop :project_sites, Hash
    prop :counts, ::Inat::CandidateCount::Counts
    prop :user, ::User

    def view_template
      add_project_banner(@project)
      add_page_title(:project_sites_title.l)
      container_class(:wide)

      render(Views::Controllers::Projects::AdminSubtabs.new(
               project: @project, current_subtab: "external_sites"
             ))
      p(class: "mt-3") { :project_sites_intro.t }
      @sites.each { |site| render_site_panel(site) }
    end

    private

    def render_site_panel(site)
      Panel(panel_class: "panel-default mt-3",
            panel_id: "project_site_#{site.id}") do |panel|
        panel.with_heading { strong { plain(site.name) } }
        panel.with_body do
          render_holdings(site)
          render_configuration(site)
        end
      end
    end

    def render_holdings(site)
      holdings = @project.external_site_holdings(site)
      p do
        :project_sites_holdings.t(linked: holdings.linked,
                                  observations: holdings.observations,
                                  site: site.name,
                                  imported: holdings.imported)
      end
    end

    # Only iNaturalist answers queries, so it is the only site with
    # anything to configure; MyCoPortal exchanges files (#5422).
    def render_configuration(site)
      project_site = @project_sites[site.id]
      return p { :project_sites_nothing_to_configure.t } unless project_site

      render(Form.new(project_site, project: @project, counts: @counts))
    end
  end
end
