# frozen_string_literal: true

module Components
  module Projects
    # Sub-tab navigation for the project Admin tab. Renders Details
    # / N Members / N Aliases as Bootstrap tabs, indented under the
    # main tab bar. The current sub-tab is highlighted; the main
    # Admin tab stays selected via the parent banner's current_tab.
    class AdminSubtabs < Components::Base
      def initialize(project:, current_subtab:)
        super()
        @project = project
        @current_subtab = current_subtab
      end

      def view_template
        div(class: "row") do
          div(class: "col-xs-12 pl-4 mt-2 mb-3",
              id: "project_admin_subtabs") do
            ul(class: "nav nav-tabs") do
              details_subtab
              members_subtab
              aliases_subtab
            end
          end
        end
      end

      private

      def details_subtab
        subtab_item(:show_project_admin_details_tab.l,
                    project_admin_path(project_id: @project.id),
                    "details")
      end

      def members_subtab
        count = @project.user_group.users.count
        subtab_item("#{count} #{:MEMBERS.l}",
                    project_members_path(@project.id),
                    "members")
      end

      def aliases_subtab
        count = @project.aliases.length
        subtab_item("#{count} #{:PROJECT_ALIASES.l}",
                    project_aliases_path(project_id: @project.id),
                    "aliases")
      end

      def subtab_item(text, path, key)
        li(class: "nav-item") do
          a(href: path, class: subtab_classes(key)) { plain(text) }
        end
      end

      def subtab_classes(key)
        base = "nav-link"
        "#{base} #{"active" if @current_subtab == key}"
      end
    end
  end
end
