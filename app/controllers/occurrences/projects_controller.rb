# frozen_string_literal: true

# Resolves project membership gaps on an Occurrence — the nested
# singular resource at `/occurrences/:occurrence_id/projects`.
# Reached only via PATCH from the auto-opening confirmation modal
# (`Views::Controllers::Occurrences::Projects::Form`), which renders
# inside the
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
      case params.dig(:occurrence_projects, :resolution)
      when "add_all" then add_all(gaps)
      when "cancel" then cancel_mix
      end
    end

    def add_all(gaps)
      projects = gaps[:projects] || []
      refused = @occurrence.add_all_to_collections(projects: projects,
                                                   user: @user)
      flash_notice(:occurrence_resolve_projects_all_done.t(
                     count: projects.size - refused.size
                   ))
      return if refused.empty?

      flash_warning(:occurrence_resolve_projects_refused.t(
                      projects: refused.map(&:title).join(", ")
                    ))
    end

    # Backs out the attach that created the mix, rather than leaving the
    # occurrence's members with different project memberships — a state
    # they aren't allowed to be in. See #4932.
    def cancel_mix
      detached = @occurrence.detach_mismatched_observations(@user)
      return if detached.empty?

      flash_notice(:occurrence_resolve_projects_cancelled.t(
                     count: detached.size
                   ))
    end
  end
end
