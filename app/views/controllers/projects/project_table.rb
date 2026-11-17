# frozen_string_literal: true

# Projects list/manage table -- one row per Project, as a
# Components::Table with two columns: info (title/meta/violation
# warning) and action (REMOVE/ADD button or an observation count
# badge). Used by `Projects::Index` and, via
# `Components::ObservationListManager`, by `Observations::Projects::Edit`.
module Views::Controllers::Projects
  class ProjectTable < Views::Base
    prop :objects, _Array(::Project), :positional
    prop :observation, _Nilable(::Observation), default: nil
    prop :remove, _Boolean, default: false
    prop :add, _Boolean, default: false
    prop :observation_counts, _Hash(Integer, Integer), default: -> { {} }

    def view_template
      Table(@objects, variant: :lg) do |t|
        t.column(:project.ti) { |project| render_info_cell(project) }
        t.column(:observations.ti, align: :right) do |project|
          render_action_cell(project)
        end
      end
    end

    private

    def render_info_cell(project)
      render_title_row(project)
      render_meta_row(project)
      kinds = violation_kinds_for(project)
      render_violation_warning(kinds) if kinds.any?
    end

    # Only computed on the add side of the observation-attach edit
    # page -- the index has no observation to check against.
    def violation_kinds_for(project)
      return [] unless @add

      project.violation_kinds_for(@observation)
    end

    def render_title_row(project)
      div(class: "d-flex align-items-center") do
        a(href: project_path(project.id)) do
          span(class: "h4") { trusted_html(project.title.t) }
        end
        if project.open_membership
          whitespace
          span(class: "ml-3") { plain("(#{:open.ti})") }
        end
        IDBadge(object: project, size: :xl, extra_class: "ml-3")
      end
    end

    def render_meta_row(project)
      div do
        small { trusted_html(append_colon(project.created_at.web_date)) }
        Link(type: :user, user: project.user)
      end
    end

    def render_violation_warning(kinds)
      div(class: "mt-1") do
        kinds.each_with_index do |kind, index|
          whitespace if index.positive?
          render_violation_badge(kind)
        end
      end
    end

    def render_violation_badge(kind)
      span(class: "badge badge-warning") do
        plain(:"form_observations_projects_kind_#{kind}".l)
      end
    end

    def render_action_cell(project)
      if @remove || @add
        render_manage_section(project)
      else
        CountBadge(count: @observation_counts[project.id].to_i)
      end
    end

    def render_manage_section(project)
      if @remove
        render_remove_obs_button(project)
      elsif @add
        render_add_obs_button(project)
      end
    end

    def render_remove_obs_button(project)
      Button(
        type: :delete,
        variant: :outline,
        icon: :remove,
        name: :remove.ti,
        show_label: :responsive,
        target: observation_project_path(
          id: @observation.id, project_id: project.id
        ),
        confirm: :are_you_sure.l
      )
    end

    def render_add_obs_button(project)
      Button(
        type: :put,
        name: :add.ti,
        icon: :attach,
        show_label: :responsive,
        target: observation_project_path(
          id: @observation.id, project_id: project.id
        )
      )
    end
  end
end
