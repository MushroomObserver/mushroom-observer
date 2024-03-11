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
    assert_out_of_range_observations(projects(:future_project))
    assert_out_of_range_observations(projects(:pinned_date_range_project))
  end

  def test_in_range_observations
    assert_in_range_observations(projects(:current_project))
    assert_in_range_observations(projects(:unlimited_project))
    assert_in_range_observations(projects(:future_project), expect: 0)
    assert_in_range_observations(projects(:pinned_date_range_project),
                                 expect: 0)
  end

  def assert_out_of_range_observations(project,
                                       expect: project.observations.count)
    assert(
      project.observations.count.positive?,
      "Test needs fixture with some Observations; #{project.title} has none"
    )
    assert_equal(expect, project.out_of_range_observations.count)
  end

  def assert_in_range_observations(project,
                                   expect: project.observations.count)
    assert(
      project.observations.count.positive?,
      "Test needs fixture with some Observations; #{project.title} has none"
    )
    assert_equal(expect, project.in_range_observations.count)
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
    geoloc_in_bubank = observations(:unknown_with_lat_long)
    geoloc_outside_burbank =
      observations(:trusted_hidden) # lat/lon in Falmouth
    geoloc_nil_burbank_contains_loc =
      observations(:minimal_unknown_obs)
    geoloc_nil_outside_burbank = observations(:reused_observation)

    proj.observations = [
      geoloc_in_bubank,
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
      location_violations, geoloc_in_bubank,
      "Noncompliant Obss wrongly includes Obs with geoloc inside Proj location"
    )
    assert_not_includes(
      location_violations, geoloc_nil_burbank_contains_loc,
      "Noncompliant Obss wrongly includes Obs w/o geoloc " \
      "whose Loc is contained in Proj location"
    )
  end
end
