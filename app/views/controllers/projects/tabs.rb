# frozen_string_literal: true

# Renders the project tab bar (Summary, Observations, Names, etc.).
# Extracted so it can be re-rendered independently via Turbo Stream
# (see `projects/_tab_counts_update.erb`). Rendered from
# `Components::ProjectBanner` on every project page.
module Views::Controllers::Projects
  class Tabs < Views::Base
    def initialize(project:, user: nil, current_tab: nil)
      super()
      @project = project
      @user = user
      @current_tab = current_tab
    end

    def view_template
      div(class: "col-xs-12", id: "project_tabs") do
        render(Components::NavTabs.new(current: @current_tab,
                                       link_class: "mt-3")) do |tabs|
          summary_tab(tabs)
          if @project.observations.any?
            observation_tabs(tabs)
          else
            non_observation_tabs(tabs)
          end
          admin_tab(tabs)
        end
      end
    end

    private

    def non_observation_tabs(tabs)
      species_lists_tab(tabs) if @project.species_lists.any?
      names_tab(tabs)
      locations_tab(tabs)
      update_tab(tabs)
    end

    def observation_tabs(tabs)
      observations_tab(tabs)
      species_lists_tab(tabs)
      names_tab(tabs)
      locations_tab(tabs)
      update_tab(tabs)
    end

    def admin_tab(tabs)
      return unless @project.is_admin?(@user)

      tabs.tab(*project_admin_tab(@project), key: "admin")
    end

    def summary_tab(tabs)
      tabs.tab(*project_summary_tab(@project), key: "projects")
    end

    def observations_tab(tabs)
      tabs.tab(*project_observations_tab(@project), key: "observations")
    end

    def species_lists_tab(tabs)
      tabs.tab(*project_species_lists_tab(@project), key: "species_lists")
    end

    def names_tab(tabs)
      tabs.tab(*project_names_tab(@project), key: "checklists")
    end

    def locations_tab(tabs)
      tabs.tab(*project_locations_tab(@project), key: "locations")
    end

    def update_tab(tabs)
      return unless @project.has_targets? && @project.is_admin?(@user)

      tabs.tab(*project_updates_tab(@project), key: "updates")
    end
  end
end
