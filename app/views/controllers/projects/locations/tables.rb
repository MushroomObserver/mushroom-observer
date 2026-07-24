# frozen_string_literal: true

# Renders the project locations table with target location grouping,
# collapsible sub-locations, and aliases. Rendered from the
# locations index and the target_locations turbo_stream re-render.
#
module Views::Controllers::Projects::Locations
  class Tables < Views::Base
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
        render_target_summary if @grouped_data.any?
        render_target_groups if @grouped_data.any?
        render_ungrouped if @ungrouped_locations.any?
        render_target_remove_footnote if show_target_remove_footnote?
      end
    end

    private

    def admin?
      return @admin if defined?(@admin)

      @admin = @project.is_admin?(@user)
    end

    # --- Summary line above the table ---

    def render_target_summary
      total = @grouped_data.size
      with_obs = @grouped_data.count do |group|
        target_obs_count(group[:target], group[:sub_locations]).positive?
      end
      without_obs = total - with_obs

      div(class: "my-3") do
        plain(
          :project_target_locations_summary.t(
            total: total, with_obs: with_obs, without_obs: without_obs
          )
        )
      end
    end

    # --- Footnote explaining the red X (admin-only) ---

    def show_target_remove_footnote?
      @grouped_data.any? && admin?
    end

    def render_target_remove_footnote
      p(class: "mt-3") do
        Icon(type: :x, class: "text-danger")
        plain(" #{:project_target_locations_remove_footnote.l}")
      end
    end

    # --- Target location groups (collapsible) ---

    def render_target_groups
      render_locations_table do |t|
        @grouped_data.each { |group| add_group_bodies(t, group) }
      end
    end

    def add_group_bodies(tab, group)
      target = group[:target]
      subs = group[:sub_locations]
      collapse_id = "target_subs_#{target.id}"
      count = target_obs_count(target, subs)
      tab.body { render_target_row(target, collapse_id, count, subs) }
      return if subs.empty?

      tab.body(id: collapse_id,
               class: Components::Collapsible.collapse_classes) do
        subs.each { |loc| render_sub_row(loc) }
      end
    end

    def render_target_row(target, collapse_id, count, subs)
      tr do
        render_target_name_cell(target, collapse_id, subs)
        td(class: "align-middle") { plain(count.to_s) }
        render_aliases_cell(target)
        render_target_column(target) if admin?
      end
    end

    def render_target_name_cell(target, collapse_id, subs)
      td(class: "align-middle") do
        render_chevron(collapse_id) if subs.any?
        whitespace if subs.any?
        Link(
          type: :get, name: target.display_name,
          target: checklist_path(project_id: @project.id,
                                 location_id: target.id,
                                 sub_locations: 1)
        )
      end
    end

    def render_sub_row(loc)
      render_location_row(loc, indent: true)
    end

    def render_chevron(collapse_id)
      Link(type: :collapse_toggle,
           target_id: collapse_id,
           collapsed: true,
           class: "panel-collapse-trigger") do
        Icon(type: :chevron_down, title: :open.ti, class: "active-icon")
        Icon(type: :chevron_up, title: :close.ti)
      end
    end

    def target_obs_count(target, subs)
      count = @obs_counts[target.id] || 0
      subs.each { |loc| count += @obs_counts[loc.id] || 0 }
      count
    end

    # --- Ungrouped locations (flat table) ---

    def render_ungrouped
      render_locations_table(@ungrouped_locations) do |t|
        t.row { |loc| render_location_row(loc) }
      end
    end

    def render_locations_table(rows = nil, &block)
      Table(rows,
            variant: :striped, identifier: "project-members",
            class: "mt-3") do |t|
        t.column(:location.ti)
        t.column(:observations.ti)
        t.column(:project_aliases.ti)
        if admin?
          t.column(:project_target_locations_title.l,
                   class: "text-center")
        end
        yield(t)
      end
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
        Link(
          type: :get, name: loc.display_name,
          target: checklist_path(project_id: @project.id,
                                 location_id: loc.id)
        )
      end
    end

    def render_aliases_cell(loc)
      td(class: "align-middle") do
        render(Views::Controllers::Projects::Aliases::Widget.new(
                 project: @project, target: loc
               ))
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
      Button(
        type: :delete,
        name: :remove.ti,
        target: project_target_location_path(
          project_id: @project.id, id: loc.id
        ),
        confirm: :project_target_location_confirm_remove.t(
          name: loc.display_name
        ),
        icon: :x,
        variant: :link,
        class: "p-0"
      )
    end
  end
end
