# frozen_string_literal: true

require("test_helper")

class OccurrenceProjectGapsTest < UnitTestCase
  def setup
    super
    @obs1 = observations(:minimal_unknown_obs)
    @obs2 = observations(:coprinus_comatus_obs)
    @obs3 = observations(:detailed_unknown_obs) # in bolete_project
    [@obs1, @obs2, @obs3].each do |obs|
      obs.update_column(:occurrence_id, nil)
    end
    User.current = rolf
  end

  def test_no_gaps_when_no_projects
    occ = make_occurrence(@obs1, [@obs1, @obs2])
    assert_equal({}, occ.project_membership_gaps)
  end

  def test_detects_primary_missing_from_project
    # obs3 is in bolete_project, obs1 is not
    occ = make_occurrence(@obs1, [@obs1, @obs3])
    gaps = occ.project_membership_gaps
    assert(gaps[:projects]&.any?, "Should detect missing projects")
    assert(gaps[:primary_missing]&.any?,
           "Primary should be missing from project")
  end

  def test_detects_non_primary_gaps
    project = projects(:bolete_project)
    # Put obs1 in project but not obs2
    ProjectObservation.create!(project: project, observation: @obs1)
    occ = make_occurrence(@obs1, [@obs1, @obs2])
    gaps = occ.project_membership_gaps
    assert(gaps[:has_non_primary_gaps],
           "Should detect non-primary obs missing from project")
  end

  def test_no_gaps_when_all_in_same_projects
    project = projects(:bolete_project)
    ProjectObservation.create!(project: project, observation: @obs1)
    ProjectObservation.create!(project: project, observation: @obs2)
    occ = make_occurrence(@obs1, [@obs1, @obs2])
    assert_equal({}, occ.project_membership_gaps)
  end

  def test_add_primary_to_collections
    project = projects(:bolete_project)
    occ = make_occurrence(@obs1, [@obs1, @obs3])
    occ.add_primary_to_collections(projects: [project])
    assert_includes(@obs1.reload.projects, project)
  end

  def test_add_all_to_collections
    project = projects(:bolete_project)
    occ = make_occurrence(@obs1, [@obs1, @obs2, @obs3])
    occ.add_all_to_collections(projects: [project])
    assert_includes(@obs1.reload.projects, project)
    assert_includes(@obs2.reload.projects, project)
    assert_includes(@obs3.reload.projects, project)
  end

  private

  def make_occurrence(primary, obs_list)
    occ = Occurrence.create!(user: rolf, primary_observation: primary)
    obs_list.each { |obs| obs.update!(occurrence: occ) }
    occ
  end
end
