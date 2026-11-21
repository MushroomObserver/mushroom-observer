# frozen_string_literal: true

# Renders the project locations table with target location grouping,
# collapsible sub-locations, and aliases. Rendered from the
# locations index and the target_locations turbo_stream re-render.
#
module Views::Controllers::Projects::Locations
  class Tables < Views::Base
    prop :project, ::Project
    # Each element: { target: ::Location, sub_locations: Array(::Location) }
    prop :grouped_data, _Array(Hash)
    prop :ungrouped_locations, _Array(::Location)
    prop :obs_counts, _Hash(Integer, Integer)
    prop :user, _Nilable(::User), default: nil

    def view_template
      div(id: "locations_table") do
        render_locations_table if @grouped_data.any? ||
                                  @ungrouped_locations.any?
        render_target_remove_footnote if show_target_remove_footnote?
      end
    end

    private

    def admin?
      return @admin if defined?(@admin)

      @admin = @project.is_admin?(@user)
    end

    # --- Footnote explaining the red X (admin-only) ---

    def show_target_remove_footnote?
      @grouped_data.any? && admin?
    end

    def render_target_remove_footnote
      p(class: "mt-3") do
        Icon(type: :remove, class: "text-danger")
        whitespace
        plain(:project_target_locations_remove_footnote.l)
      end
    end

    def render_locations_table
      Table(variant: :striped, identifier: "project-members") do |tab|
        tab.column(:location.ti)
        tab.column(:observations.ti, align: :center)
        tab.column(:project_aliases.ti, align: :center)
        tab.column(:project_target_locations_title.l, align: :center) if admin?
        add_target_group_bodies(tab) if @grouped_data.any?
        add_ungrouped_bodies(tab) if @ungrouped_locations.any?
      end
    end

    # --- Target location groups (collapsible) ---

    def add_target_group_bodies(tab)
      tab.legend(target_summary_text)
      @grouped_data.each { |group| add_group_bodies(tab, group) }
    end

    def target_summary_text
      total = @grouped_data.size
      with_obs = @grouped_data.count do |group|
        target_obs_count(group[:target], group[:sub_locations]).positive?
      end
      without_obs = total - with_obs
      :project_target_locations_summary.t(
        total: total, with_obs: with_obs, without_obs: without_obs
      )
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
        render_count_cell(count)
        render_aliases_cell(target)
        render_target_column(target) if admin?
      end
    end

    def render_count_cell(count)
      td(class: class_names(Components::Table.valign_class(:middle),
                            Components::Table.align_class(:center))) do
        plain(count.to_s)
      end
    end

    def render_target_name_cell(target, collapse_id, subs)
      td(class: Components::Table.valign_class(:middle)) do
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
           class: "panel-collapse-trigger inline-flex-center") do
        Icon(type: :chevron_down, title: :open.ti, class: "active-icon",
             center_tooltip: true)
        Icon(type: :chevron_up, title: :close.ti, center_tooltip: true)
      end
    end

    def target_obs_count(target, subs)
      count = @obs_counts[target.id] || 0
      subs.each { |loc| count += @obs_counts[loc.id] || 0 }
      count
    end

    # --- Ungrouped locations (flat body) ---

    def add_ungrouped_bodies(tab)
      tab.legend(:project_locations_not_targets.l)
      tab.body do
        @ungrouped_locations.each { |loc| render_location_row(loc) }
      end
    end

    # --- Shared ---

    def render_location_row(loc, indent: false)
      count = @obs_counts[loc.id] || 0
      tr do
        render_location_name_cell(loc, indent: indent)
        render_count_cell(count)
        render_aliases_cell(loc)
        td { nil } if admin?
      end
    end

    def render_location_name_cell(loc, indent: false)
      style = indent ? "padding-left: 2em" : nil
      td(class: Components::Table.valign_class(:middle), style: style) do
        Link(
          type: :get, name: loc.display_name,
          target: checklist_path(project_id: @project.id,
                                 location_id: loc.id)
        )
      end
    end

    def render_aliases_cell(loc)
      td(class: class_names(Components::Table.valign_class(:middle),
                            Components::Table.align_class(:center))) do
        render(Views::Controllers::Projects::Aliases::Widget.new(
                 project: @project, target: loc
               ))
      end
    end

    def render_target_column(loc)
      td(class: class_names(Components::Table.valign_class(:middle),
                            Components::Table.align_class(:center))) do
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
        icon: :remove,
        variant: :link,
        class: "p-0"
      )
    end
  end
end
