# frozen_string_literal: true

module Components
  module Projects
    # Renders the project tab bar (Summary, Observations, Names, etc.)
    # Extracted so it can be re-rendered independently via Turbo Stream.
    class Tabs < Components::Base
      def initialize(project:, user: nil, current_tab: nil)
        super()
        @project = project
        @user = user
        @current_tab = current_tab
      end

      def view_template
        div(class: "col-xs-12", id: "project_tabs") do
          ul(class: "nav nav-tabs") do
            summary_tab
            if @project.observations.any?
              observation_tabs
            else
              non_observation_tabs
            end
            admin_tab
          end
        end
      end

      private

      def non_observation_tabs
        species_list_tabs if @project.species_lists.any?
        names_tab
        locations_tab
        update_tab
      end

      def observation_tabs
        observations_tab
        species_lists_tab
        names_tab
        locations_tab
        update_tab
      end

      def admin_tab
        return unless @project.is_admin?(@user)

        tab_item(:show_project_admin_tab.l,
                 project_admin_path(project_id: @project.id),
                 "admin")
      end

      def summary_tab
        tab_item(:SUMMARY.t, project_path(id: @project.id),
                 "projects")
      end

      def observations_tab
        count = @project.visible_observations.count
        tab_item("#{count} #{:OBSERVATIONS.l}",
                 observations_path(project: @project),
                 "observations")
      end

      def species_lists_tab
        count = @project.species_lists.length
        tab_item("#{count} #{:SPECIES_LISTS.l}",
                 species_lists_path(project: @project),
                 "species_lists")
      end

      def names_tab
        tab_item("#{@project.name_count} #{:NAMES.l}",
                 checklist_path(project_id: @project.id),
                 "checklists")
      end

      def locations_tab
        tab_item("#{@project.location_count} #{:LOCATIONS.l}",
                 project_locations_path(project_id: @project.id),
                 "locations")
      end

      def update_tab
        return unless @project.has_targets? &&
                      @project.is_admin?(@user)

        count = @project.new_candidate_observations_count
        tab_item("#{count} #{:project_updates_title.l}",
                 project_updates_path(project_id: @project.id),
                 "updates")
      end

      def species_list_tabs
        species_lists_tab
      end

      def tab_item(text, path, tab_name)
        li(class: "nav-item") do
          a(href: path, class: tab_classes(tab_name)) { text }
        end
      end

      def tab_classes(tab_name)
        base = "mt-3 nav-link"
        "#{base} #{"active" if @current_tab == tab_name}"
      end
    end
  end
end
