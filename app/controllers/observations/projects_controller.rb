# frozen_string_literal: true

module Observations
  # Add or remove one Observation from a Project, from the observation's
  # own show page -- mirrors Observations::SpeciesListsController.
  class ProjectsController < ApplicationController
    before_action :login_required

    # Form (table of post_button links) to let user add/remove one
    # observation at a time from a project they're a member of.
    def edit
      return unless (@observation = find_observation!)

      set_project_ivars
      render_phlex_edit
    end

    def update
      return unless (@project = find_project!) &&
                    (@observation = find_observation!)
      return unless permission_to_change_membership?

      set_project_ivars
      dispatch_commit
    end

    private

    def permission_to_change_membership?
      return true if @project.user_can_change_membership?(@observation, @user)

      flash_error(:permission_denied.l)
      redirect_to(project_path(@project.id))
      false
    end

    def dispatch_commit
      case params[:commit]
      when "add"
        add_observation_to_project(@project, @observation)
      when "remove"
        remove_observation_from_project(@project, @observation)
      else
        flash_error(:runtime_invalid.t(type: '"mode"', value: params[:commit]))
        render_phlex_edit(
          location: edit_observation_projects_path(id: @observation.id),
          status: :unprocessable_content
        )
      end
    end

    def render_phlex_edit(**render_opts)
      render(
        Views::Controllers::Observations::Projects::Edit.new(
          observation: @observation,
          obs_projects: @obs_projects,
          other_projects: @other_projects
        ),
        **render_opts
      )
    end

    # `violation_kinds_for` (called per project in @other_projects, in
    # the Edit view) reads location/target_names/target_locations --
    # preload them here so that's not an N+1 across the list.
    def set_project_ivars
      member_ids = @observation.project_ids.to_set
      all_projects = @user.projects_member(
        order: :title, include: [:location, :target_names, :target_locations]
      )
      @obs_projects, @other_projects =
        all_projects.partition { |project| member_ids.include?(project.id) }
    end

    def find_observation!
      find_or_goto_index(Observation, params[:id])
    end

    def find_project!
      find_or_goto_index(Project, params[:project_id])
    end

    def add_observation_to_project(project, observation)
      project.add_observation(observation)
      flash_notice(:runtime_project_add_observation_success.
        t(name: project.title, id: observation.id))
      redirect_to(project_path(id: project.id))
    end

    # Project#remove_observation removes every sibling observation
    # sharing the same Occurrence too, not just the one clicked --
    # match ObservationsController::SharedFormMethods#flash_project_removal's
    # count-aware message so a multi-observation removal isn't
    # silently reported as if only the clicked one changed.
    def remove_observation_from_project(project, observation)
      removed = project.remove_observation(observation)
      if removed.size > 1
        flash_notice(:removed_from_project_with_siblings.t(
                       count: removed.size, project: project.title
                     ))
      else
        flash_notice(:removed_from_project.t(object: :observation,
                                             project: project.title))
      end
      redirect_to(project_path(id: project.id))
    end
  end
end
