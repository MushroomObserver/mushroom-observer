# frozen_string_literal: true

require("test_helper")

class ProjectTest < UnitTestCase
  def test_add_and_remove_observations
    proj = projects(:eol_project)
    minimal_unknown_obs = observations(:minimal_unknown_obs)
    detailed_unknown_obs = observations(:detailed_unknown_obs)
    imgs = detailed_unknown_obs.images.sort_by(&:id)
    assert_obj_arrays_equal([], proj.images)
    assert_obj_arrays_equal([], minimal_unknown_obs.images)
    assert(imgs.any?)

    proj.add_observation(minimal_unknown_obs)
    assert_true(proj.observations.include?(minimal_unknown_obs))
    assert_false(proj.observations.include?(detailed_unknown_obs))
    assert_obj_arrays_equal([], proj.images)

    proj.add_observation(detailed_unknown_obs)
    assert_true(proj.observations.include?(minimal_unknown_obs))
    assert_true(proj.observations.include?(detailed_unknown_obs))
    assert_obj_arrays_equal(imgs, proj.images.sort_by(&:id))

    proj.add_observation(detailed_unknown_obs)
    assert_true(proj.observations.include?(minimal_unknown_obs))
    assert_true(proj.observations.include?(detailed_unknown_obs))
    assert_obj_arrays_equal(imgs, proj.images.sort_by(&:id))

    minimal_unknown_obs.images << imgs.first
    proj.remove_observation(detailed_unknown_obs)
    assert_true(proj.observations.include?(minimal_unknown_obs))
    assert_false(proj.observations.include?(detailed_unknown_obs))
    # by another observation still attached to project
    assert_obj_arrays_equal([imgs.first], proj.images)

    proj.remove_observation(minimal_unknown_obs)
    assert_false(proj.observations.include?(minimal_unknown_obs))
    assert_false(proj.observations.include?(detailed_unknown_obs))
    # should lose it now because no observations left which use it
    assert_obj_arrays_equal([], proj.images)

    proj.remove_observation(minimal_unknown_obs)
    assert_false(proj.observations.include?(minimal_unknown_obs))
    assert_false(proj.observations.include?(detailed_unknown_obs))
    assert_obj_arrays_equal([], proj.images)
  end

  def test_add_and_remove_images
    in_situ_img = images(:in_situ_image)
    turned_over_img = images(:turned_over_image)
    proj = projects(:eol_project)

    assert_obj_arrays_equal([], proj.images)

    proj.add_image(in_situ_img)
    assert_obj_arrays_equal([in_situ_img], proj.images)

    proj.add_image(turned_over_img)
    assert_obj_arrays_equal([in_situ_img, turned_over_img].sort_by(&:id),
                            proj.images.sort_by(&:id))

    proj.add_image(turned_over_img)
    assert_obj_arrays_equal([in_situ_img, turned_over_img].sort_by(&:id),
                            proj.images.sort_by(&:id))

    proj.remove_image(in_situ_img)
    assert_obj_arrays_equal([turned_over_img], proj.images)

    proj.remove_image(turned_over_img)
    assert_obj_arrays_equal([], proj.images)

    proj.remove_image(turned_over_img)
    assert_obj_arrays_equal([], proj.images)
  end

  def test_add_and_remove_species_lists
    proj = projects(:bolete_project)
    first_list = species_lists(:first_species_list)
    another_list = species_lists(:unknown_species_list)
    assert_obj_arrays_equal([another_list], proj.species_lists)

    proj.add_species_list(first_list)
    assert_obj_arrays_equal([first_list, another_list].sort_by(&:id),
                            proj.species_lists.sort_by(&:id))

    proj.add_species_list(another_list)
    assert_obj_arrays_equal([first_list, another_list].sort_by(&:id),
                            proj.species_lists.sort_by(&:id))

    proj.remove_species_list(another_list)
    assert_obj_arrays_equal([first_list], proj.species_lists)

    proj.remove_species_list(first_list)
    assert_obj_arrays_equal([], proj.species_lists)

    proj.remove_species_list(first_list)
    assert_obj_arrays_equal([], proj.species_lists)
  end

  def test_destroy_orphans_log
    proj = projects(:two_list_project)
    log = proj.rss_log
    assert_not_nil(log)
    proj.destroy!
    proj.log_destroy
    assert_nil(log.reload.target_id)
  end

  def test_dates_current
    assert(projects(:current_project).current?)
    assert_not(projects(:past_project).current?)
    assert_not(projects(:future_project).current?)
  end

  def test_date_strings
    proj = projects(:pinned_date_range_project)
    assert_equal("#{proj.start_date} to #{proj.end_date}",
                 proj.date_range, "Wrong date range string")

    assert_equal(:form_projects_any.l, projects(:unlimited_project).date_range,
                 "Wrong date range string")
  end

  def test_out_of_range_observations
    assert_out_of_range_observations(projects(:current_project), expect: 0)
    assert_out_of_range_observations(projects(:unlimited_project), expect: 0)
    assert_out_of_range_observations(projects(:no_start_date_project),
                                     expect: 0)
    assert_out_of_range_observations(projects(:no_end_date_project))
    assert_out_of_range_observations(projects(:future_project))
    assert_out_of_range_observations(projects(:pinned_date_range_project))
  end

  def test_in_range_observations
    assert_in_range_observations(projects(:current_project))
    assert_in_range_observations(projects(:unlimited_project))
    assert_in_range_observations(projects(:no_start_date_project))
    assert_in_range_observations(projects(:no_end_date_project), expect: 0)
    assert_in_range_observations(projects(:future_project), expect: 0)
    assert_in_range_observations(projects(:pinned_date_range_project),
                                 expect: 0)
  end

  def assert_out_of_range_observations(project,
                                       expect: project.observations.count)
    assert(
      project.observations.any?,
      "Test needs fixture with some Observations; #{project.title} has none"
    )
    assert_equal(expect, project.out_of_range_observations.count)
  end

  def assert_in_range_observations(project,
                                   expect: project.observations.count)
    assert(
      project.observations.any?,
      "Test needs fixture with some Observations; #{project.title} has none"
    )
    assert_equal(expect, project.in_range_observations.count)
  end

  def test_out_of_area_observations
    project = projects(:falmouth_2023_09_project)
    assert_equal(2, project.out_of_area_observations.size)

    assert_empty(projects(:unlimited_project).out_of_area_observations)
  end

  def test_place_name
    proj = projects(:eol_project)
    loc = locations(:albion)
    proj.place_name = loc.display_name
    assert_equal(proj.location, loc)
  end

  def test_scientific_place_name
    User.current_location_format = "scientific"
    proj = projects(:eol_project)
    loc = locations(:albion)
    proj.place_name = loc.display_name
    assert_equal(proj.location, loc)
    User.current_location_format = "postal"
  end

  def test_location_violations
    proj = Project.create(
      location: locations(:burbank),
      title: "With Location Violations",
      open_membership: true
    )
    geoloc_in_burbank = observations(:unknown_with_lat_lng)
    geoloc_outside_burbank =
      observations(:trusted_hidden) # lat/lon in Falmouth
    geoloc_nil_burbank_contains_loc =
      observations(:minimal_unknown_obs)
    geoloc_nil_outside_burbank = observations(:reused_observation)

    proj.observations = [
      geoloc_in_burbank,
      geoloc_nil_burbank_contains_loc,
      geoloc_outside_burbank,
      geoloc_nil_outside_burbank
    ]

    location_violations = proj.out_of_area_observations

    assert_includes(
      location_violations, geoloc_outside_burbank,
      "Noncompliant Obss missing Obs with geoloc outside Proj location"
    )
    assert_includes(
      location_violations, geoloc_nil_outside_burbank,
      "Noncompliant Obss missing Obs w/o geoloc " \
      "whose Loc is not contained in Proj location"
    )
    assert_not_includes(
      location_violations, geoloc_in_burbank,
      "Noncompliant Obss wrongly includes Obs with geoloc inside Proj location"
    )
    assert_not_includes(
      location_violations, geoloc_nil_burbank_contains_loc,
      "Noncompliant Obss wrongly includes Obs w/o geoloc " \
      "whose Loc is contained in Proj location"
    )
  end

  def test_add_and_remove_target_names
    proj = projects(:rare_fungi_project)
    coprinus = names(:coprinus_comatus)
    agaricus = names(:agaricus_campestris)
    peltigera = names(:peltigera)

    assert_includes(proj.target_names, coprinus)
    assert_includes(proj.target_names, agaricus)

    # Add new target name
    proj.add_target_name(peltigera)
    assert_includes(proj.target_names.reload, peltigera)

    # Idempotent — adding again does nothing
    proj.add_target_name(peltigera)
    assert_equal(1, proj.target_names.where(id: peltigera.id).count)

    # Remove target name
    proj.remove_target_name(peltigera)
    assert_not_includes(proj.target_names.reload, peltigera)

    # Removing non-member does nothing
    proj.remove_target_name(peltigera)
    assert_not_includes(proj.target_names, peltigera)
  end

  def test_add_and_remove_target_locations
    proj = projects(:rare_fungi_project)
    burbank = locations(:burbank)
    albion = locations(:albion)

    assert_includes(proj.target_locations, burbank)

    # Add new target location
    proj.add_target_location(albion)
    assert_includes(proj.target_locations.reload, albion)

    # Idempotent
    proj.add_target_location(albion)
    assert_equal(1, proj.target_locations.where(id: albion.id).count)

    # Remove target location
    proj.remove_target_location(albion)
    assert_not_includes(proj.target_locations.reload, albion)

    # Removing non-member does nothing
    proj.remove_target_location(albion)
    assert_not_includes(proj.target_locations, albion)
  end

  def test_has_targets
    proj = projects(:rare_fungi_project)
    assert(proj.has_targets?)

    empty = projects(:empty_project)
    assert_not(empty.has_targets?)
  end

  def test_candidate_observations
    proj = projects(:rare_fungi_project)
    # Project has both target names and target locations, so
    # candidates must match BOTH (AND logic).
    candidates = proj.candidate_observations

    # coprinus_comatus_obs matches a target name but is in Glendale,
    # not within the Burbank target location — should NOT match.
    coprinus_obs = observations(:coprinus_comatus_obs)
    assert_not_includes(candidates, coprinus_obs)

    # agaricus_campestris_obs matches target name AND is in Burbank
    agaricus_obs = observations(:agaricus_campestris_obs)
    assert_includes(candidates, agaricus_obs)

    # Count should match
    assert_equal(candidates.count, proj.candidate_observations_count)
  end

  def test_candidate_observations_empty_targets
    proj = projects(:empty_project)
    assert_equal(0, proj.candidate_observations.count)
  end

  def test_candidate_observations_names_only
    proj = projects(:rare_fungi_project)
    # Remove all target locations so only names remain
    proj.project_target_locations.destroy_all
    assert(proj.target_names.any?)
    assert_not(proj.target_locations.any?)

    candidates = proj.candidate_observations
    coprinus_obs = observations(:coprinus_comatus_obs)
    assert_includes(candidates, coprinus_obs)
  end

  def test_candidate_observations_locations_only
    proj = projects(:rare_fungi_project)
    # Remove all target names so only locations remain
    proj.project_target_names.destroy_all
    assert_not(proj.target_names.any?)
    assert(proj.target_locations.any?)

    candidates = proj.candidate_observations
    assert(candidates.count >= 0, "Should query without error")
  end

  # Genus-level target should pick up observations of species in that
  # genus (Joe's example from #4130: Gloeomucro genus → Gloeomucro flavus).
  def test_candidate_observations_includes_subtaxa_of_genus_target
    proj = projects(:rare_fungi_project)
    # Drop existing targets, add genus Agaricus as the only target.
    proj.project_target_names.destroy_all
    proj.add_target_name(names(:agaricus))

    species_obs = observations(:agaricus_campestris_obs)
    assert_includes(proj.candidate_observations, species_obs,
                    "Obs of a species should match its genus as target")
  end

  # Genus target should NOT pull in current-name species whose deprecated
  # synonym happens to fall under the target genus. E.g., an Agaricus
  # target would otherwise match a current Protostropharia species whose
  # old name was "Agaricus semiglobatus". This caught 21K spurious
  # observations for the real Agaricus on production.
  def test_candidate_observations_excludes_cross_genus_historical_synonyms
    proj = projects(:rare_fungi_project)
    proj.project_target_names.destroy_all
    proj.add_target_name(names(:agaricus))

    # Simulate the historical-rename scenario: a current Protostropharia
    # species whose old name would fall under Agaricus via subtaxa
    # expansion.
    synonym = Synonym.create!
    Name.create!(
      user: users(:rolf),
      text_name: "Agaricus fakedeprecated",
      search_name: "Agaricus fakedeprecated",
      sort_name: "Agaricus fakedeprecated",
      display_name: "__Agaricus__ __fakedeprecated__",
      author: "",
      rank: Name.ranks[:Species],
      deprecated: true,
      synonym_id: synonym.id,
      correct_spelling_id: nil
    )
    other_genus = Name.create!(
      user: users(:rolf),
      text_name: "Protostropharia fakecurrent",
      search_name: "Protostropharia fakecurrent",
      sort_name: "Protostropharia fakecurrent",
      display_name: "__Protostropharia__ __fakecurrent__",
      author: "",
      rank: Name.ranks[:Species],
      deprecated: false,
      synonym_id: synonym.id,
      correct_spelling_id: nil
    )
    obs = Observation.create!(
      name: other_genus, user: users(:rolf), when: Time.zone.now
    )

    assert_not_includes(
      proj.candidate_observations, obs,
      "Current Protostropharia obs should NOT match the Agaricus target " \
      "just because its deprecated synonym is under Agaricus"
    )
  end

  def test_field_slip_prefix_validation
    proj = Project.new(title: "Test", field_slip_prefix: "bad prefix!")
    proj.valid?
    assert(proj.errors[:field_slip_prefix].any?,
           "Should reject invalid field_slip_prefix")
  end

  def test_exclude_and_unexclude_observation
    proj = projects(:rare_fungi_project)
    obs = observations(:agaricus_campestris_obs)

    proj.exclude_observation(obs)
    assert_includes(proj.excluded_observations.reload, obs)
    assert_not_includes(proj.observations.reload, obs)

    proj.unexclude_observation(obs)
    assert_not_includes(proj.excluded_observations.reload, obs)
  end

  def test_exclude_observation_removes_from_project
    proj = projects(:rare_fungi_project)
    obs = observations(:agaricus_campestris_obs)
    proj.add_observation(obs)
    assert_includes(proj.observations.reload, obs)

    proj.exclude_observation(obs)
    assert_not_includes(proj.observations.reload, obs)
    assert_includes(proj.excluded_observations.reload, obs)
  end

  def test_add_observation_removes_from_excluded
    proj = projects(:rare_fungi_project)
    obs = observations(:agaricus_campestris_obs)
    proj.exclude_observation(obs)
    assert_includes(proj.excluded_observations.reload, obs)

    proj.add_observation(obs)
    assert_includes(proj.observations.reload, obs)
    assert_not_includes(proj.excluded_observations.reload, obs)
  end

  def test_new_candidate_observations_excludes_excluded
    proj = projects(:rare_fungi_project)
    obs = observations(:agaricus_campestris_obs)
    assert_includes(proj.new_candidate_observations, obs)

    proj.exclude_observation(obs)
    assert_not_includes(proj.new_candidate_observations.reload, obs)
  end

  def test_new_candidate_observations_excludes_in_project
    proj = projects(:rare_fungi_project)
    obs = observations(:agaricus_campestris_obs)
    proj.add_observation(obs)
    assert_not_includes(proj.new_candidate_observations.reload, obs)
  end

  def test_remove_target_name_purges_matching_observations
    proj = projects(:rare_fungi_project)
    matching_name = names(:agaricus_campestris)
    added_obs = observations(:agaricus_campestris_obs)
    excluded_obs = Observation.create!(
      name: matching_name, user: users(:rolf),
      location: locations(:burbank), when: Time.zone.now
    )
    proj.add_observation(added_obs)
    proj.exclude_observation(excluded_obs)
    assert_includes(proj.observations.reload, added_obs)
    assert_includes(proj.excluded_observations.reload, excluded_obs)

    proj.remove_target_name(matching_name)

    assert_not_includes(proj.observations.reload, added_obs)
    assert_not_includes(proj.excluded_observations.reload, excluded_obs)
  end

  # Issue #4130: removing a genus target should also purge obs of its
  # species (which qualified as candidates via the sub-taxa rule), not
  # just the bare-genus obs.
  def test_remove_target_name_purges_subtaxa_observations
    proj = projects(:rare_fungi_project)
    proj.project_target_names.destroy_all
    proj.add_target_name(names(:agaricus)) # genus
    species_obs = observations(:agaricus_campestris_obs)
    proj.add_observation(species_obs)
    assert_includes(proj.observations.reload, species_obs)

    proj.remove_target_name(names(:agaricus))

    assert_not_includes(proj.observations.reload, species_obs,
                        "Species obs qualified via genus target should be " \
                        "purged when the genus target is removed")
  end

  # Issue #4130: when a species is still explicitly targeted, removing
  # a broader (genus) target must leave that species' obs in place.
  def test_remove_target_name_keeps_obs_still_covered_by_another_target
    proj = projects(:rare_fungi_project)
    proj.project_target_names.destroy_all
    proj.add_target_name(names(:agaricus))            # genus target
    proj.add_target_name(names(:agaricus_campestris)) # species target
    species_obs = observations(:agaricus_campestris_obs)
    proj.add_observation(species_obs)

    proj.remove_target_name(names(:agaricus))

    assert_includes(proj.observations.reload, species_obs,
                    "Species obs should stay because it's still covered " \
                    "by the remaining species target")
  end
end
