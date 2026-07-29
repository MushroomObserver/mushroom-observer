# frozen_string_literal: true

require("test_helper")

# Tests for Occurrences::ProjectsController — the nested singular
# resource at PATCH /occurrences/:occurrence_id/projects, posted by
# the auto-opening project-membership modal. Replaces the old custom
# `OccurrencesController#resolve_projects` action.
module Occurrences
  class ProjectsControllerTest < FunctionalTestCase
    def setup
      @obs1 = observations(:minimal_unknown_obs)
      @obs2 = observations(:coprinus_comatus_obs)
      @obs3 = observations(:detailed_unknown_obs)
    end

    def test_update_add_all_resolves_gaps
      login("mary") # bolete member; unioning requires membership (#4932)
      occ = create_occurrence(@obs1, @obs3)
      project = projects(:bolete_project)

      patch(:update,
            params: { occurrence_id: occ.id,
                      occurrence_projects: { resolution: "add_all" } })

      assert_redirected_to(occurrence_path(occ))
      assert_includes(@obs1.reload.projects, project,
                      "All obs should be added to project")
      assert_includes(@obs3.reload.projects, project)
    end

    # Cancel backs the mix out instead of leaving it: the observations
    # whose project membership differs from the primary's are detached,
    # so what remains is consistent. Replaces the old Skip, which left
    # the occurrence in a state its members aren't allowed to be in.
    # See #4932.
    def test_update_cancel_detaches_the_mismatched_observations
      login("rolf")
      project = projects(:bolete_project)
      occ = create_occurrence(@obs1, @obs3)
      mismatched = occ.observations.reject do |obs|
        obs.id == occ.primary_observation_id
      end
      assert_predicate(mismatched, :any?, "setup needs a mismatched member")

      patch(:update,
            params: { occurrence_id: occ.id,
                      occurrence_projects: { resolution: "cancel" } })

      assert_redirected_to(occurrence_path(occ))
      mismatched.each do |obs|
        assert_nil(obs.reload.occurrence_id, "should have been detached")
      end
      # Detaching leaves each observation's own memberships alone; what
      # cancel must not do is spread them, the way add_all would.
      assert_not_includes(@obs1.reload.projects, project)
    end

    def test_update_missing_resolution_param_leaves_projects_alone
      # Defensive: a PATCH without `occurrence_projects[resolution]` is
      # not triggered by the UI (Skip and Add All both send a value),
      # but the controller should still redirect cleanly rather than
      # erroring on the missing key.
      login("rolf")
      project = projects(:bolete_project)
      occ = create_occurrence(@obs1, @obs3)

      patch(:update, params: { occurrence_id: occ.id })

      assert_not_includes(@obs1.reload.projects, project)
      assert_redirected_to(occurrence_path(occ))
    end

    def test_update_no_gaps_redirects_to_show
      # When projects are already in sync across the occurrence's obs,
      # the modal shouldn't have rendered in the first place — but if
      # a stale PATCH arrives, just redirect to show.
      login("rolf")
      occ = create_occurrence(@obs1, @obs2)

      patch(:update,
            params: { occurrence_id: occ.id,
                      occurrence_projects: { resolution: "add_all" } })

      assert_redirected_to(occurrence_path(occ))
    end

    def test_update_requires_login
      occ = create_occurrence(@obs1, @obs3)
      patch(:update,
            params: { occurrence_id: occ.id,
                      occurrence_projects: { resolution: "add_all" } })
      assert_redirected_to(new_account_login_path)
    end

    def test_update_with_invalid_occurrence_id_redirects
      login("rolf")
      patch(:update,
            params: { occurrence_id: 0,
                      occurrence_projects: { resolution: "add_all" } })
      assert_redirected_to(observations_path)
    end

    private

    def create_occurrence(primary_obs, *other_obs)
      occ = Occurrence.create!(
        user: rolf,
        primary_observation: primary_obs
      )
      primary_obs.update!(occurrence: occ)
      other_obs.each { |obs| obs.update!(occurrence: occ) }
      occ
    end
  end
end
