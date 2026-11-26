# frozen_string_literal: true

# The External Sites sub-tab of the project Admin tab (#5416): one panel
# per external site, each saying what the project already holds from
# that site, and, where MO can act on it, how.
module Views::Controllers::Projects::ExternalSites
  class Index < Views::FullPageBase
    prop :project, ::Project
    prop :sites, _Array(::ExternalSite)
    prop :project_sites, Hash
    prop :candidates, ::Inat::CandidateCount::Candidates
    prop :user, ::User

    def view_template
      add_project_banner(@project)
      add_page_title(:project_sites_title.l)
      container_class(:wide)
      turbo_stream_from(InatTargetLookupJob.stream(@project))

      @sites.each { |site| render_site_panel(site) }
    end

    private

    def render_site_panel(site)
      Panel(class: "mt-3",
            id: "project_site_#{site.id}") do |panel|
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
      unless project_site
        return p { :project_sites_imports_not_implemented.t(site: site.name) }
      end

      render(Form.new(project_site, project: @project,
                                    candidates: @candidates))
      render_look_up_button
    end

    # Below the settings form, not in it:
    # (The button is a form; a form nested in another breaks the outer one.)
    def render_look_up_button
      return unless @candidates.incomplete?

      div(class: "mt-3", id: InatTargetLookupJob::LOOK_UP_BUTTON_ID) do
        Button(type: :post, name: :project_sites_look_up_targets.l,
               target: look_up_project_external_sites_path(
                 project_id: @project.id
               ))
      end
    end
  end
end
