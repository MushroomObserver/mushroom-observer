# frozen_string_literal: true

# Detects and resolves project/species_list membership gaps
# when the primary observation is not in sibling projects.
module Occurrence::ProjectGaps
  extend ActiveSupport::Concern

  # Projects where any observation in the occurrence is a member
  # but not all observations are members. Returns a hash:
  #   { projects: [Project, ...],
  #     primary_missing: [Project, ...],
  #     has_non_primary_gaps: bool }
  # Empty hash means no gaps.
  def project_membership_gaps
    obs_list = observations.to_a
    all_projects = all_observation_projects(obs_list)
    return {} if all_projects.empty?

    primary_missing = all_projects - primary_observation.projects.to_a
    non_primary_gaps = any_obs_missing_projects?(obs_list, all_projects)
    return {} if primary_missing.empty? && !non_primary_gaps

    { projects: all_projects,
      primary_missing: primary_missing,
      has_non_primary_gaps: non_primary_gaps }
  end

  # Add all occurrence observations to the given projects/lists.
  def add_all_to_collections(projects: [], species_lists: [])
    observations.each do |obs|
      projects.each do |project|
        ProjectObservation.find_or_create_by!(
          project: project, observation: obs
        )
      end
      species_lists.each do |list|
        SpeciesListObservation.find_or_create_by!(
          species_list: list, observation: obs
        )
      end
    end
  end

  # The other way to resolve a gap: instead of unioning the memberships,
  # back out of the mix. Detaches every non-primary observation whose
  # project membership differs from the primary's, leaving what remains
  # consistent. Returns the detached observations.
  #
  # Those differing observations are what created the mix — attaching one
  # that belongs to different projects is the only way an occurrence's
  # members diverge — so detaching them undoes it without the controller
  # having to remember which click did it. See #4932.
  def detach_mismatched_observations(user = nil)
    mismatched = mismatched_observations
    return [] if mismatched.empty?

    mismatched.each { |obs| detach_mismatched(obs, user) }
    reload
    recompute_has_specimen!
    recalculate_consensus!(user)
    destroy_if_incomplete!
    mismatched
  end

  private

  # Re-queried rather than read off the association: callers reach this
  # from strict-loading scopes, where `projects` won't lazily load.
  def mismatched_observations
    members = Observation.where(occurrence_id: id).includes(:projects).to_a
    primary = members.find { |obs| obs.id == primary_observation_id }
    return [] unless primary

    wanted = primary.project_ids.sort
    members.reject do |obs|
      obs.id == primary_observation_id || obs.project_ids.sort == wanted
    end
  end

  def detach_mismatched(obs, user)
    reassign_thumbnails_from(obs)
    obs.update!(occurrence: nil)
    Occurrence.log_observation_removed(obs, self, user)
    Observation::NamingConsensus.new(obs).calc_consensus(user)
  end

  def all_observation_projects(obs_list)
    Project.joins(:project_observations).
      where(project_observations: {
              observation_id: obs_list.map(&:id)
            }).distinct.to_a
  end

  def any_obs_missing_projects?(obs_list, all_projects)
    obs_list.any? do |obs|
      next if obs.id == primary_observation_id

      (all_projects - obs.projects.to_a).any?
    end
  end
end
