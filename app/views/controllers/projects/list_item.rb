# frozen_string_literal: true

# Inner content of one row in a projects list-group. The
# `<div class="list-group-item …">` wrapper is supplied by the
# caller (`Components::ListGroup`); this class only emits the
# two-column body (id badge + title / meta column), plus an optional
# add/remove-observation section on the right (mutually exclusive,
# used by `Observations::Projects::Edit` — the projects index doesn't
# pass `observation:`, so that section stays absent there).
module Views::Controllers::Projects
  class ListItem < Views::Base
    prop :project, ::Project
    prop :observation, _Nilable(::Observation), default: nil
    prop :remove, _Boolean, default: false
    prop :add, _Boolean, default: false
    prop :violation_kinds, _Array(Symbol), default: -> { [] }

    def view_template
      render_info
      render_manage_section if @remove || @add
    end

    private

    # Badge + title/meta wrapped in one flex child -- keeps the outer
    # row (in `Observations::Projects::Edit`'s add/remove context) to
    # exactly two `justify-content-between` children (info, manage
    # section); three top-level children would center this block
    # between the badge and the button instead of hugging it left.
    def render_info
      div(class: "list_info d-flex align-items-start") do
        div(class: "text-larger") { IDBadge(object: @project, size: :md) }
        div do
          render_title_row
          render_meta_row
          render_violation_warning if @violation_kinds.any?
        end
      end
    end

    def render_title_row
      div do
        a(href: project_path(@project.id)) do
          span(class: "h4") { trusted_html(@project.title.t) }
        end
        if @project.open_membership
          whitespace
          span(class: "ml-4") { plain("(#{:open.ti})") }
        end
      end
    end

    def render_meta_row
      div do
        small { plain(append_colon(@project.created_at.web_time)) }
        whitespace
        Link(type: :user, user: @project.user)
      end
    end

    # Warns that adding the observation to this project would violate
    # one or more of its constraints -- doesn't block the add, mirrors
    # `Observations::Form::Projects`'s warning-not-gate behavior.
    def render_violation_warning
      labels = @violation_kinds.map do |kind|
        :"form_observations_projects_kind_#{kind}".l
      end
      div(class: "text-warning small mt-1") { plain(labels.join("; ")) }
    end

    def render_manage_section
      div(class: "ml-3") do
        if @remove
          render_remove_obs_button
        elsif @add
          render_add_obs_button
        end
      end
    end

    def render_remove_obs_button
      Button(
        type: :put,
        variant: :strip,
        name: :remove.ti,
        target: observation_project_path(
          id: @observation.id, project_id: @project.id, commit: "remove"
        ),
        confirm: :are_you_sure.l
      )
    end

    def render_add_obs_button
      Button(
        type: :put,
        name: :add.ti,
        target: observation_project_path(
          id: @observation.id, project_id: @project.id, commit: "add"
        )
      )
    end
  end
end
