# frozen_string_literal: true

module Components
  module Projects
    # Renders the project locations table with target location
    # grouping, collapsible sub-locations, and aliases.
    class LocationsTable < Components::Base
      def initialize(project:, grouped_data:,
                     ungrouped_locations:, obs_counts:,
                     user: nil)
        super()
        @project = project
        @grouped_data = grouped_data
        @ungrouped_locations = ungrouped_locations
        @obs_counts = obs_counts
        @user = user
      end

      def view_template
        div(id: "locations_table") do
          render_target_groups if @grouped_data.any?
          render_ungrouped if @ungrouped_locations.any?
        end
      end

      private

      def admin?
        @project.is_admin?(@user)
      end

      # --- Target location groups (collapsible) ---

      def render_target_groups
        table(class: "table table-striped " \
                     "table-project-members mt-3") do
          thead { render_header }
          @grouped_data.each do |group|
            render_target_group(group)
          end
        end
      end

      def render_target_group(group)
        target = group[:target]
        subs = group[:sub_locations]
        collapse_id = "target_subs_#{target.id}"
        count = target_obs_count(target, subs)

        render_target_row(target, collapse_id, count, subs)
        render_sub_location_rows(subs, collapse_id)
      end

      def render_target_row(target, collapse_id, count, subs)
        tbody do
          tr do
            render_target_name_cell(target, collapse_id, subs)
            td(class: "align-middle") { plain(count.to_s) }
            render_aliases_cell(target)
            render_target_column(target) if admin?
          end
        end
      end

      def render_target_name_cell(target, collapse_id, subs)
        td(class: "align-middle") do
          render_chevron(collapse_id) if subs.any?
          plain(" ") if subs.any?
          link_to(
            target.display_name,
            checklist_path(project_id: @project.id,
                           location_id: target.id,
                           sub_locations: 1)
          )
        end
      end

      def render_sub_location_rows(subs, collapse_id)
        return if subs.empty?

        tbody(id: collapse_id, class: "collapse") do
          subs.each { |loc| render_sub_row(loc) }
        end
      end

      def render_sub_row(loc)
        render_location_row(loc, indent: true)
      end

      def render_chevron(collapse_id)
        link_to(
          "javascript:void(0)",
          role: :button,
          class: "panel-collapse-trigger collapsed",
          style: "text-decoration:none;outline:none",
          data: { toggle: "collapse",
                  target: "##{collapse_id}" },
          aria: { expanded: false,
                  controls: collapse_id }
        ) do
          link_icon(:chevron_down, title: :OPEN.l,
                                   class: "active-icon")
          link_icon(:chevron_up, title: :CLOSE.l)
        end
      end

      def target_obs_count(target, subs)
        count = @obs_counts[target.id] || 0
        subs.each { |loc| count += @obs_counts[loc.id] || 0 }
        count
      end

      # --- Ungrouped locations (flat table) ---

      def render_ungrouped
        table(class: "table table-striped " \
                     "table-project-members mt-3") do
          thead { render_header }
          tbody do
            @ungrouped_locations.each do |loc|
              render_ungrouped_row(loc)
            end
          end
        end
      end

      def render_ungrouped_row(loc)
        render_location_row(loc)
      end

      # --- Shared ---

      def render_location_row(loc, indent: false)
        count = @obs_counts[loc.id] || 0
        tr do
          render_location_name_cell(loc, indent: indent)
          td(class: "align-middle") { plain(count.to_s) }
          render_aliases_cell(loc)
          td { nil } if admin?
        end
      end

      def render_location_name_cell(loc, indent: false)
        style = indent ? "padding-left: 2em" : nil
        td(class: "align-middle", style: style) do
          link_to(
            loc.display_name,
            checklist_path(project_id: @project.id,
                           location_id: loc.id)
          )
        end
      end

      def render_aliases_cell(loc)
        td(class: "align-middle") do
          render(Components::ProjectAliases.new(
                   project: @project, target: loc
                 ))
        end
      end

      def render_header
        tr do
          th { :LOCATION.t }
          th { :OBSERVATIONS.t }
          th { :PROJECT_ALIASES.t }
          if admin?
            th(class: "text-center") do
              :project_target_locations_title.t
            end
          end
        end
      end

      def render_target_column(loc)
        td(class: "align-middle text-center") do
          render_remove_button(loc) if target?(loc)
        end
      end

      def target?(loc)
        @project.target_location_ids.include?(loc.id)
      end

      def render_remove_button(loc)
        button_to(
          project_target_location_path(
            project_id: @project.id, id: loc.id
          ),
          method: :delete,
          class: "btn btn-link text-danger p-0",
          form: { data: {
            turbo: true,
            turbo_confirm:
              :project_target_location_confirm_remove.t(
                name: loc.display_name
              )
          } }
        ) do
          span(class: "glyphicon glyphicon-remove")
        end
      end
    end
  end
end
