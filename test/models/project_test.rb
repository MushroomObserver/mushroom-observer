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

  def test_place_name
    proj = projects(:eol_project)
    loc = locations(:albion)
    proj.place_name = loc.display_name(rolf)
    assert_equal(proj.location, loc)
  end

  def test_scientific_place_name
    proj = projects(:eol_project)
    proj.current_user = roy
    loc = locations(:albion)
    proj.place_name = loc.display_name(roy)
    assert_equal(proj.location, loc)
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

  # A concurrent insert of the same target name/location can make
  # find_or_create_by! raise RecordNotUnique instead of returning the
  # existing record, skipping the line that would otherwise memoize
  # target_names_present?/target_locations_present? as true.
  def test_add_target_name_after_record_not_unique_race
    proj = projects(:empty_project)
    assert_not(proj.target_names_present?)

    proj.project_target_names.stub(
      :find_or_create_by!, ->(*) { raise(ActiveRecord::RecordNotUnique) }
    ) do
      proj.add_target_name(names(:agaricus))
    end

    assert(proj.target_names_present?,
           "target_names_present? must not stay stale after a " \
           "RecordNotUnique race")
  end

  def test_add_target_location_after_record_not_unique_race
    proj = projects(:empty_project)
    assert_not(proj.target_locations_present?)

    proj.project_target_locations.stub(
      :find_or_create_by!, ->(*) { raise(ActiveRecord::RecordNotUnique) }
    ) do
      proj.add_target_location(locations(:burbank))
    end

    assert(proj.target_locations_present?,
           "target_locations_present? must not stay stale after a " \
           "RecordNotUnique race")
  end

  # violates_target_name? memoizes expanded_target_name_id_set on the
  # Project instance -- add/remove_target_name must invalidate it so a
  # check made before the change doesn't leak into one made after.
  def test_add_target_name_invalidates_stale_expanded_set
    proj = projects(:rare_fungi_project)
    peltigera_obs = observations(:peltigera_obs)

    assert(proj.violates_target_name?(peltigera_obs),
           "Test needs an obs whose name is not yet a target")

    proj.add_target_name(names(:peltigera))

    assert_not(
      proj.violates_target_name?(peltigera_obs),
      "violates_target_name? used a stale expanded_target_name_id_set " \
      "memoized before the target name was added"
    )
  end

  def test_remove_target_name_invalidates_stale_expanded_set
    proj = projects(:rare_fungi_project)
    peltigera_obs = observations(:peltigera_obs)
    proj.add_target_name(names(:peltigera))

    assert_not(proj.violates_target_name?(peltigera_obs),
               "Test needs peltigera added as a target first")

    proj.remove_target_name(names(:peltigera))

    assert(
      proj.violates_target_name?(peltigera_obs),
      "violates_target_name? used a stale expanded_target_name_id_set " \
      "memoized before the target name was removed"
    )
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
    # Strip all targets and rebuild with just a single genus name so
    # the assertion tests the name-matching logic in isolation (no
    # location filter to also satisfy).
    proj.project_target_names.destroy_all
    proj.project_target_locations.destroy_all
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
    # Clear target_locations too so the test isolates name matching;
    # obs below is created without a location.
    proj.project_target_locations.destroy_all
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

  def test_bulk_add_observations_inserts_obs_and_owner_images
    proj = projects(:eol_project)
    minimal = observations(:minimal_unknown_obs)
    detailed = observations(:detailed_unknown_obs)
    owner_imgs = detailed.images.select { |i| i.user_id == detailed.user_id }
    assert(owner_imgs.any?,
           "fixture must have at least one owner-attributed image")

    count = proj.bulk_add_observations([minimal.id, detailed.id])

    assert_equal(2, count)
    assert_includes(proj.observations.reload, minimal)
    assert_includes(proj.observations.reload, detailed)
    assert_obj_arrays_equal(owner_imgs.sort_by(&:id),
                            proj.images.reload.sort_by(&:id))
  end

  def test_bulk_add_observations_is_idempotent
    proj = projects(:eol_project)
    obs = observations(:detailed_unknown_obs)
    proj.add_observation(obs)
    obs_count_before = proj.observations.reload.size
    img_count_before = proj.images.reload.size

    count = proj.bulk_add_observations([obs.id])

    assert_equal(0, count)
    assert_equal(obs_count_before, proj.observations.reload.size)
    assert_equal(img_count_before, proj.images.reload.size)
  end

  def test_bulk_add_observations_unexcludes
    proj = projects(:rare_fungi_project)
    obs = observations(:agaricus_campestris_obs)
    proj.exclude_observation(obs)
    assert_includes(proj.excluded_observations.reload, obs)

    count = proj.bulk_add_observations([obs.id])

    assert_equal(1, count)
    assert_includes(proj.observations.reload, obs)
    assert_not_includes(proj.excluded_observations.reload, obs)
  end

  def test_bulk_add_observations_handles_empty_input
    proj = projects(:eol_project)
    assert_equal(0, proj.bulk_add_observations([]))
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

  # ------------------------------------------------------------------
  #  #4136 expanded violation concept
  # ------------------------------------------------------------------

  def test_violation_kinds_for_target_name_mismatch
    proj = projects(:rare_fungi_project)
    proj.project_target_names.destroy_all
    proj.project_target_locations.destroy_all
    proj.update!(start_date: nil, end_date: nil, location: nil)
    proj.add_target_name(names(:agaricus))
    off_target = observations(:peltigera_obs)
    proj.add_observation(off_target)

    kinds = proj.violation_kinds_for(off_target)

    assert_includes(kinds, :target_name)
    assert_not_includes(kinds, :date)
    assert_not_includes(kinds, :bbox)
    assert(proj.violates_constraints?(off_target))
  end

  def test_violation_kinds_for_target_name_passes_subtaxa
    proj = projects(:rare_fungi_project)
    proj.project_target_names.destroy_all
    proj.project_target_locations.destroy_all
    proj.update!(start_date: nil, end_date: nil, location: nil)
    proj.add_target_name(names(:agaricus))
    species_obs = observations(:agaricus_campestris_obs)
    proj.add_observation(species_obs)

    kinds = proj.violation_kinds_for(species_obs)

    assert_not_includes(
      kinds, :target_name,
      "Sub-taxa of target genus should not be a target_name " \
      "violation (#4130 + #4136 combined)"
    )
  end

  def test_violation_kinds_for_target_location_mismatch
    proj = build_target_location_project
    california_loc = locations(:california)
    obs_in_ca = observations(:california_obs)
    proj.add_target_location(california_loc)
    obs_outside = observations(:falmouth_2023_09_obs)
    proj.add_observation(obs_in_ca)
    proj.add_observation(obs_outside)

    assert_not_includes(proj.violation_kinds_for(obs_in_ca), :target_location)
    assert_includes(proj.violation_kinds_for(obs_outside), :target_location)
  end

  def test_violations_sorted_by_sort_name
    proj = projects(:falmouth_2023_09_project)
    sort_names = proj.violations.map { |v| v.obs.name&.sort_name.to_s.downcase }

    assert_equal(sort_names, sort_names.sort,
                 "Violations should be sorted by obs.name.sort_name")
  end

  def test_count_violations_matches_violations_size
    proj = projects(:falmouth_2023_09_project)

    assert_equal(proj.violations.size, proj.count_violations)
  end

  def test_violating_observations_matches_violations
    proj = projects(:falmouth_2023_09_project)

    assert_equal(proj.violations.map { |v| v.obs.id },
                 proj.violating_observations.map(&:id),
                 "violating_observations should match violations, in order")
  end

  # violation_kinds_for's bbox check (Location#found_here?) falls
  # back to "violates" when an obs has neither geoloc nor a Location.
  # Observation.project_violating_by_bbox must also cover this, or
  # count_violations/violating_observations would disagree with
  # violates_location? for these obs.
  def test_bbox_violation_matches_found_here_with_no_geoloc_or_location
    proj = Project.create!(title: "Bbox Missing Info #{SecureRandom.hex(4)}",
                           user: users(:rolf), location: locations(:burbank))
    obs = Observation.create!(user: users(:rolf), when: Date.current,
                              name: names(:agaricus), location_id: nil,
                              lat: nil, lng: nil, where: "Nowhere specific")
    proj.add_observation(obs)

    assert(proj.violates_location?(obs),
           "Test needs an obs with neither geoloc nor location")
    assert_includes(proj.violating_observations.pluck(:id), obs.id,
                    "Obs with no geoloc and no location should violate " \
                    "the project's location constraint")
  end

  # Devs' verdict (2026-08-28): flagged as a violation, even though
  # the obs is assigned to the project's Location -- violations are
  # review flags, not a binding state, and imprecise GPS is worth a
  # look regardless of the assigned Location name.
  def test_bbox_violation_flags_imprecise_geoloc_even_when_location_matches
    proj = Project.create!(title: "Bbox Matching Loc #{SecureRandom.hex(4)}",
                           user: users(:rolf), location: locations(:burbank))
    outside_burbank = proj.location.north + 5.0
    obs = Observation.create!(user: users(:rolf), when: Date.current,
                              name: names(:agaricus), location: proj.location,
                              lat: outside_burbank, lng: proj.location.east)
    proj.add_observation(obs)

    assert(proj.violates_location?(obs),
           "Test needs an obs whose location matches the project's, " \
           "with geoloc outside that location's bbox")
    assert_includes(proj.violating_observations.pluck(:id), obs.id,
                    "Obs with geoloc outside the bbox should violate " \
                    "even when its Location matches the project's")
  end

  # violating_observations is a relation, so a caller can paginate it
  # with LIMIT/OFFSET instead of loading every violation into Ruby.
  # Uses 3 target_name violations (not a fixture count, so this
  # doesn't depend on fixture data staying in sync) to prove
  # offset/limit slices the query.
  def test_violating_observations_is_paginable_with_offset_and_limit
    proj = Project.create!(title: "Paginable #{SecureRandom.hex(4)}",
                           user: users(:rolf))
    proj.add_target_name(names(:agaricus))
    off_target = [observations(:peltigera_obs),
                  observations(:california_obs),
                  observations(:minimal_unknown_obs)]
    off_target.each { |obs| proj.add_observation(obs) }

    ordered_ids = proj.violations.map { |v| v.obs.id }
    assert_equal(3, ordered_ids.size, "Test needs exactly 3 violations")

    page = proj.violating_observations.offset(1).limit(1)
    assert_equal([ordered_ids[1]], page.map(&:id),
                 "offset(1).limit(1) should return only the 2nd violation")
  end

  def test_violations_for_skips_observations_that_are_not_violations
    proj = projects(:falmouth_2023_09_project)
    violating_obs = proj.violations.first.obs
    visible = proj.visible_observations.to_a - [violating_obs]
    passing_obs = visible.find { |obs| proj.violation_kinds_for(obs).empty? }
    assert(passing_obs, "Test needs a visible obs that is not a violation")

    result = proj.violations_for([violating_obs, passing_obs])

    assert_equal([violating_obs.id], result.map { |v| v.obs.id })
  end

  def test_candidate_observations_respects_date_range
    proj = build_target_name_project_with_dates
    in_range = observations(:agaricus_campestris_obs)
    in_range.update!(when: proj.start_date + 1.day)
    out_of_range = observations(:agaricus_campestrus_obs)
    out_of_range.update!(when: proj.end_date + 10.days)

    candidate_ids = proj.candidate_observations.pluck(:id)

    assert_includes(candidate_ids, in_range.id)
    assert_not_includes(
      candidate_ids, out_of_range.id,
      "Out-of-date-range obs should be filtered from candidates"
    )
  end

  def test_candidate_observations_respects_bbox_with_gps
    proj = build_target_name_project_with_location
    inside = observations(:agaricus_campestris_obs)
    inside.update!(lat: proj.location.center_lat,
                   lng: proj.location.center_lng,
                   gps_hidden: false, gps_dubious: false)
    outside = observations(:agaricus_campestrus_obs)
    outside.update!(lat: 0.0, lng: 0.0,
                    gps_hidden: false, gps_dubious: false)

    candidate_ids = proj.candidate_observations.pluck(:id)

    assert_includes(candidate_ids, inside.id)
    assert_not_includes(candidate_ids, outside.id,
                        "GPS outside project bbox should be filtered out")
  end

  # Q9: an obs with no GPS but whose Location is fully contained in the
  # project's bbox should pass the candidate filter, mirroring the
  # violations-side rule.
  def test_candidate_observations_includes_no_gps_with_location_in_bbox
    proj = build_target_name_project_with_location
    inside = observations(:agaricus_campestris_obs)
    burbank_sub = locations(:burbank) # by definition contained in itself
    inside.update!(lat: nil, lng: nil, location: burbank_sub)

    candidate_ids = proj.candidate_observations.pluck(:id)

    assert_includes(
      candidate_ids, inside.id,
      "Obs without GPS but with location contained in project bbox " \
      "should remain a candidate"
    )
  end

  def test_violation_kinds_combine_date_and_target_name
    proj = projects(:rare_fungi_project)
    proj.project_target_locations.destroy_all
    proj.project_target_names.destroy_all
    proj.update!(location: nil,
                 start_date: Date.parse("2030-01-01"),
                 end_date: Date.parse("2030-12-31"))
    proj.add_target_name(names(:agaricus))
    off_target = observations(:peltigera_obs) # not Agaricus, not in 2030
    proj.add_observation(off_target)

    kinds = proj.violation_kinds_for(off_target)

    assert_includes(kinds, :date)
    assert_includes(kinds, :target_name)
    assert_not_includes(kinds, :bbox)
    assert_not_includes(kinds, :target_location)
  end

  # Covers Project#count_violations target_name path
  # (collect_target_name_violation_ids id-merge against visible obs whose
  # name_id is outside expanded_target_name_id_set). Project has only
  # target_names, no other constraints, so that id-merge is the only path
  # that can fire.
  def test_count_violations_includes_target_name_violations
    proj = Project.create!(
      title: "Target Name Only #{SecureRandom.hex(4)}",
      user: users(:rolf)
    )
    proj.add_target_name(names(:agaricus))
    off_target = observations(:peltigera_obs)
    proj.add_observation(off_target)

    assert_equal(1, proj.count_violations,
                 "Obs with non-target name should count as a violation")
    assert_equal(proj.violations.size, proj.count_violations)
    kinds = proj.violation_kinds_for(off_target)
    assert_includes(kinds, :target_name)
  end

  # Covers Project#passing_target_location_ids with-loc branch
  # (joins :location, applies location_suffix_conditions) and
  # collect_target_location_violation_ids id-merge.
  def test_count_violations_includes_target_location_violations_with_location
    proj = Project.create!(
      title: "Target Loc Only #{SecureRandom.hex(4)}",
      user: users(:rolf)
    )
    proj.add_target_location(locations(:burbank))

    in_burbank = observations(:agaricus_campestris_obs)
    proj.add_observation(in_burbank)
    in_falmouth = observations(:falmouth_2023_09_obs)
    proj.add_observation(in_falmouth)

    violation_obs_ids = proj.violations.map { |v| v.obs.id }
    assert_includes(violation_obs_ids, in_falmouth.id,
                    "Obs in Falmouth should violate Burbank target_location")
    assert_not_includes(violation_obs_ids, in_burbank.id,
                        "Obs in Burbank should pass via location_id branch")
    assert_equal(proj.violations.size, proj.count_violations)
  end

  # Covers Project#passing_target_location_ids without-loc branch
  # (visible_observations.where(location_id: nil) joined with
  # where_suffix_conditions) and the observation.where leg of
  # #target_location_suffix_match?.
  # Both an obs whose `where` matches and one whose `where` doesn't are
  # exercised so the boundary of the suffix match is locked down.
  def test_count_violations_target_location_uses_obs_where_when_no_location
    proj = Project.create!(
      title: "Target Loc Where #{SecureRandom.hex(4)}",
      user: users(:rolf)
    )
    proj.add_target_location(locations(:burbank))

    # peltigera_obs: location_id is nil, where = "Briceland, California, USA"
    # — should NOT match Burbank's suffix and so should violate.
    off_target = observations(:peltigera_obs)
    proj.add_observation(off_target)

    on_target = Observation.create!(
      user: users(:rolf), when: Date.parse("2024-06-01"),
      name: names(:agaricus), location_id: nil,
      where: "Burbank, California, USA"
    )
    proj.add_observation(on_target)

    violation_obs_ids = proj.violations.map { |v| v.obs.id }
    assert_includes(
      violation_obs_ids, off_target.id,
      "Obs.where=Briceland... should fail target_location suffix match"
    )
    assert_not_includes(
      violation_obs_ids, on_target.id,
      "Obs.where=Burbank... should pass target_location suffix match"
    )
    assert_equal(proj.violations.size, proj.count_violations)
    assert_includes(proj.violation_kinds_for(off_target), :target_location)
  end

  def test_violations_excludes_excluded_observations
    proj = projects(:falmouth_2023_09_project)
    violation_obs = proj.violations.first.obs

    proj.exclude_observation(violation_obs)

    assert_not_includes(proj.violations.map(&:obs), violation_obs,
                        "Excluded obs should not surface as a violation")
  end

  # --- trusted_by? requires membership (#4436) ---

  def test_trusted_by_trusting_member
    assert(projects(:eol_project).trusted_by?(mary)) # editing member
  end

  def test_trusted_by_no_trust_member_is_false
    assert_not(projects(:eol_project).trusted_by?(katrina)) # no_trust member
  end

  def test_trusted_by_non_member_is_false
    project = projects(:eol_project)
    assert_not(project.member?(dick))
    assert_not(project.trusted_by?(dick),
               "A non-member must not be trusted (escalation guard)")
  end

  # --- adopt_matching_field_slips (#4436) ---

  def test_adopt_matching_field_slips_member_owned
    project = projects(:eol_project) # prefix EOL, mary is editing member
    slip = orphan_field_slip("EOL-9001", mary)

    adopted = project.adopt_matching_field_slips

    assert_equal([slip], adopted)
    assert_equal(project.id, slip.reload.project_id)
  end

  def test_adopt_skips_non_member_owned
    project = projects(:eol_project)
    assert_not(project.member?(dick))
    slip = orphan_field_slip("EOL-9002", dick)

    assert_empty(project.adopt_matching_field_slips)
    assert_nil(slip.reload.project_id)
  end

  def test_adopt_skips_non_matching_prefix
    project = projects(:eol_project)
    slip = orphan_field_slip("XYZ-9003", mary)

    project.adopt_matching_field_slips

    assert_nil(slip.reload.project_id)
  end

  # --- removal cascade (#4932) ---

  # An occurrence's observations are one collection, so a project
  # membership that stops holding for one cannot hold for the rest.
  def test_removing_one_occurrence_member_removes_them_all
    project = projects(:eol_project)
    slip = field_slips(:field_slip_one)
    members = share_an_occurrence(slip, observations(:detailed_unknown_obs))
    assert_equal(2, members.size)
    members.each { |o| project.add_observation(o) }

    removed = project.remove_observation(members.first)

    assert_equal(members.map(&:id).sort, removed.map(&:id).sort)
    members.each do |o|
      assert_not_includes(project.reload.observations, o)
    end
  end

  # And the slip cannot go on claiming a project its observations left.
  def test_removing_an_occurrence_member_releases_the_field_slip
    project = projects(:eol_project)
    slip = field_slips(:field_slip_one)
    assert_equal(project.id, slip.project_id, "fixture: slip is in project")
    obs = slip.occurrence.observations.first
    project.add_observation(obs)

    project.remove_observation(obs)

    assert_nil(slip.reload.project_id)
  end

  # An observation with no occurrence is still just itself.
  def test_removing_a_lone_observation_touches_nothing_else
    project = projects(:eol_project)
    obs = observations(:minimal_unknown_obs)
    obs.update!(occurrence: nil)
    project.add_observation(obs)
    before = project.reload.observations.count

    removed = project.remove_observation(obs)

    assert_equal([obs.id], removed.map(&:id))
    assert_equal(before - 1, project.reload.observations.count)
  end

  # --- user_can_change_membership? (#4932) ---

  # Entering an observation does not confer control over which projects
  # reference it. Membership in the project is the whole test, in both
  # directions — the checkbox that reads this disables adding and
  # removing alike.
  def test_membership_change_requires_project_membership
    project = projects(:falmouth_2023_09_project)
    obs = observations(:minimal_unknown_obs)
    owner = obs.user
    assert_not(project.member?(owner), "fixture: owner is not a member")
    assert(project.member?(roy), "fixture: roy is a member")

    assert_not(project.user_can_change_membership?(obs, owner),
               "owning the observation must not confer control over it")
    assert(project.user_can_change_membership?(obs, roy))
  end

  # Adoption is the other half of "a slip's project implies its
  # observations are in that project" — claiming the slip has to bring
  # its observations along. See #4932.
  def test_adopt_brings_the_slips_observations_into_the_project
    project = projects(:eol_project)
    slip = orphan_field_slip("EOL-9004", mary)
    obs = observations(:minimal_unknown_obs)
    obs.update!(occurrence: nil)
    obs.field_slip = slip
    obs.save!
    assert_not(project.violates_constraints?(obs), "fixture must be clean")

    project.adopt_matching_field_slips

    assert_includes(project.reload.observations, obs)
  end

  # A slip whose observations violate the constraints was used outside
  # the project's context, so claiming it would both assert a membership
  # nobody chose and put a violating observation in the project.
  def test_adopt_skips_slips_whose_observations_violate_constraints
    project = projects(:eol_project)
    project.update!(start_date: Date.parse("1990-01-01"),
                    end_date: Date.parse("1990-12-31"))
    slip = orphan_field_slip("EOL-9005", mary)
    obs = observations(:minimal_unknown_obs)
    obs.update!(occurrence: nil)
    obs.field_slip = slip
    obs.save!
    assert(project.violates_constraints?(obs), "fixture must violate")

    assert_empty(project.adopt_matching_field_slips)
    assert_nil(slip.reload.project_id)
    assert_not_includes(project.reload.observations, obs)
  end

  def test_setting_prefix_adopts_member_orphans
    project = projects(:bolete_project) # mary is editing member
    slip = orphan_field_slip("BOLNEW-1", mary)

    project.update!(field_slip_prefix: "BOLNEW")

    assert_equal(project.id, slip.reload.project_id,
                 "Adding a prefix should claim a member's matching orphan")
  end

  # --- admin_power? requires the obs owner to be a trusting member (#4439) ---

  def test_admin_power_over_trusting_member_obs
    obs, = obs_in_eol_owned_by_member # mary is an editing member of eol

    assert(Project.admin_power?(obs, rolf),
           "Admin has power over a trusting member's observation")
  end

  def test_no_admin_power_over_no_trust_member_obs
    obs, project = obs_in_eol_owned_by_member
    ProjectMember.find_by(project: project, user: mary).
      update!(trust_level: "no_trust")

    assert_not(Project.admin_power?(obs, rolf))
  end

  def test_no_admin_power_over_non_member_obs
    obs, project = obs_in_eol_owned_by_member
    ProjectMember.find_by(project: project, user: mary).destroy!

    assert_not(Project.admin_power?(obs, rolf),
               "Admin must not have power over a non-member's observation")
  end

  def test_no_admin_power_when_user_not_project_admin
    obs, = obs_in_eol_owned_by_member # dick is not an eol admin

    assert_not(Project.admin_power?(obs, dick))
  end

  def test_no_admin_power_without_user
    obs, = obs_in_eol_owned_by_member

    assert_not(Project.admin_power?(obs, nil))
  end

  # Adding your observations to a project is largely the point of
  # joining it, so the admins should be able to work on them -- the
  # same trust the web join button and a field slip scan already
  # grant. This path is API2's.
  def test_join_trusts_the_project_with_editing
    project = projects(:open_membership_project)
    user = users(:mary)
    assert(project.can_join?(user), "fixture must allow self-enrollment")

    project.join(user)

    member = ProjectMember.find_by(project: project, user: user)
    assert_not_nil(member, "Cannot find ProjectMember")
    assert_equal("editing", member.trust_level)
    assert_includes(project.user_group.users, user)
  end

  private

  # An observation owned by an eol member (mary), added to eol_project
  # (where rolf is an admin). Returns [observation, project].
  def obs_in_eol_owned_by_member
    project = projects(:eol_project)
    obs = observations(:minimal_unknown_obs) # owner mary, editing member
    project.add_observation(obs)
    [obs, project]
  end

  # A field slip with no project, regardless of prefix matching.
  # Every occurrence fixture holds a single observation, so a test that
  # needs a shared one has to build it.
  def share_an_occurrence(slip, extra)
    extra.update!(occurrence: nil)
    extra.update!(occurrence: slip.occurrence)
    slip.occurrence.reload.observations.to_a
  end

  def orphan_field_slip(code, owner)
    slip = FieldSlip.create!(code: code, user: owner)
    slip.update_column(:project_id, nil)
    slip
  end

  def build_target_location_project
    Project.create!(
      title: "Target Loc #{SecureRandom.hex(4)}",
      open_membership: true,
      user: users(:rolf)
    )
  end

  def build_target_name_project_with_dates
    proj = projects(:rare_fungi_project)
    proj.project_target_names.destroy_all
    proj.project_target_locations.destroy_all
    proj.update!(location: nil,
                 start_date: Date.parse("2010-01-01"),
                 end_date: Date.parse("2010-12-31"))
    proj.add_target_name(names(:agaricus))
    proj
  end

  def build_target_name_project_with_location
    proj = projects(:rare_fungi_project)
    proj.project_target_names.destroy_all
    proj.project_target_locations.destroy_all
    proj.update!(location: locations(:burbank),
                 start_date: nil, end_date: nil)
    proj.add_target_name(names(:agaricus))
    proj
  end
end
