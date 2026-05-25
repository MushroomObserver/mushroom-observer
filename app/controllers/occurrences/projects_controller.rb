# frozen_string_literal: true

# Resolves project membership gaps on an Occurrence — the nested
# singular resource at `/occurrences/:occurrence_id/projects`.
# Reached only via PATCH from the auto-opening confirmation modal
# (`Components::OccurrenceProjectsForm`), which renders inside the
# parent occurrence's edit page (and field_slips' new/edit) when
# `project_membership_gaps` are detected after a successful update.
#
# Replaces the old custom `OccurrencesController#resolve_projects`
# action. The mutation is straightforward update semantics — update
# the projects collection of this occurrence — so it sits under
# standard CRUD routing rather than a bespoke action.
module Occurrences
  class ProjectsController < ApplicationController
    before_action :login_required
    before_action :find_occurrence!

    def update
      gaps = @occurrence.project_membership_gaps
      if gaps.empty?
        redirect_to(occurrence_path(@occurrence))
        return
      end

      apply_resolution(gaps)
      redirect_to(occurrence_path(@occurrence))
    end

    private

    def find_occurrence!
      @occurrence = Occurrence.safe_find(params[:occurrence_id])
      return @occurrence if @occurrence

      flash_error(:occurrence_not_found.t)
      redirect_to(observations_path)
      nil
    end

    def apply_resolution(gaps)
      return unless params.dig(:occurrence_projects,
                               :resolution) == "add_all"

      projects = gaps[:projects] || []
      @occurrence.add_all_to_collections(projects: projects)
      flash_notice(:occurrence_resolve_projects_all_done.t(
                     count: projects.size
                   ))
    end
  end
end
