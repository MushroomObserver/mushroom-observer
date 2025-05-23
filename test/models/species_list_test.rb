# frozen_string_literal: true

require("test_helper")

class SpeciesListTest < UnitTestCase
  def test_project_ownership
    # NOT owned by Bolete project, but owned by Rolf
    spl = species_lists(:first_species_list)
    assert_true(spl.can_edit?(rolf))
    assert_false(spl.can_edit?(mary))
    assert_false(spl.can_edit?(dick))

    # IS owned by Bolete project,
    # AND owned by Mary (Dick is member of Bolete project)
    spl = species_lists(:unknown_species_list)
    assert_false(spl.can_edit?(rolf))
    assert_true(spl.can_edit?(mary))
    assert_true(spl.can_edit?(dick))
  end

  def test_add_and_remove_observations
    spl = species_lists(:first_species_list)
    minimal_unknown_obs = observations(:minimal_unknown_obs)
    detailed_unknown_obs = observations(:detailed_unknown_obs)
    assert_obj_arrays_equal([], spl.observations)

    spl.add_observation(minimal_unknown_obs)
    assert_obj_arrays_equal([minimal_unknown_obs], spl.observations)

    spl.add_observation(minimal_unknown_obs)
    assert_obj_arrays_equal([minimal_unknown_obs], spl.observations)

    spl.add_observation(detailed_unknown_obs)
    assert_obj_arrays_equal([minimal_unknown_obs,
                             detailed_unknown_obs].sort_by(&:id),
                            spl.observations.sort_by(&:id))

    spl.remove_observation(minimal_unknown_obs)
    assert_obj_arrays_equal([detailed_unknown_obs], spl.observations)

    spl.remove_observation(minimal_unknown_obs)
    assert_obj_arrays_equal([detailed_unknown_obs], spl.observations)

    spl.remove_observation(detailed_unknown_obs)
    assert_obj_arrays_equal([], spl.observations)

    spl.remove_observation(detailed_unknown_obs)
    assert_obj_arrays_equal([], spl.observations)
  end

  def test_construct_observation
    spl = species_lists(:first_species_list)
    assert_users_equal(rolf, spl.user)
    proj = projects(:lone_wolf_project)
    proj.add_species_list(spl)
    assert_obj_arrays_equal([lone_wolf], proj.user_group.users)
    User.current = lone_wolf
    name = Name.reorder(id: :asc).first

    # Test defaults first.
    now = Time.zone.now
    spl.construct_observation(name)
    o = Observation.last
    n = Naming.last
    v = Vote.last
    assert_objs_equal(o, spl.observations.last)
    assert(o.created_at >= 1.minute.ago)
    assert(o.updated_at >= 1.minute.ago)
    assert_users_equal(lone_wolf, o.user)
    assert_obj_arrays_equal([proj], o.projects)
    assert_equal(spl.when, o.when)
    assert_equal(spl.where, o.where)
    assert_equal(spl.location, o.location)
    assert_equal({}, o.notes)
    assert_nil(o.alt)
    assert_nil(o.lng)
    assert_nil(o.alt)
    assert_true(o.is_collection_location)
    assert_false(o.specimen)
    assert_names_equal(name, o.name)
    assert_obj_arrays_equal([n], o.namings)
    assert(n.created_at <= now + 1.second)
    assert(n.updated_at <= now + 1.second)
    assert_users_equal(lone_wolf, n.user)
    assert_names_equal(name, n.name)
    assert_obj_arrays_equal([v], n.votes)
    assert(v.created_at <= now + 1.second)
    assert(v.updated_at <= now + 1.second)
    assert_users_equal(lone_wolf, v.user)
    assert_equal(Vote.maximum_vote, v.value)

    # Now override everything.
    spl.construct_observation(
      name,
      user: mary,
      projects: [],
      when: "2012-01-13",
      where: "Undefined Location",
      notes: { Other: "notes" },
      lat: " 12deg 34min N ",
      lng: " 123 45 W ",
      alt: " 123.45 ft ",
      is_collection_location: false,
      specimen: true,
      vote: Vote.next_best_vote
    )
    o = Observation.last
    n = Naming.last
    v = Vote.last
    assert_objs_equal(o, spl.observations.last)
    assert_users_equal(mary, o.user)
    assert_obj_arrays_equal([], o.projects)
    assert_equal("2012-01-13", o.when.web_date)
    assert_equal("Undefined Location", o.where)
    assert_nil(o.location)
    assert_equal({ Other: "notes" }, o.notes)
    assert_equal(12.5667, o.lat.round(4))
    assert_equal(-123.75, o.lng.round(4))
    assert_equal(38, o.alt.round(4))
    assert_false(o.is_collection_location)
    assert_true(o.specimen)
    assert_names_equal(name, o.name)
    assert_obj_arrays_equal([n], o.namings)
    assert_users_equal(mary, n.user)
    assert_names_equal(name, n.name)
    assert_obj_arrays_equal([v], n.votes)
    assert_users_equal(mary, v.user)
    assert_equal(Vote.next_best_vote, v.value)
  end

  def test_destroy_orphans_log
    spl = species_lists(:first_species_list)
    log = spl.rss_log
    assert_not_nil(log)
    spl.destroy!
    assert_nil(log.reload.target_id)
  end

  def test_define_location
    list = species_lists(:no_location_list)
    old_where_name = list.where
    new_location = locations(:with_single_quotes_location)

    SpeciesList.define_a_location(new_location, old_where_name)

    assert_equal(
      new_location.name, list.reload.where,
      "SpeciesList#where should change upon defining that Location"
    )
    assert_equal(
      new_location.id, list.location_id,
      "SpeciesList#location_id should change upon defining that Location"
    )
  end
end
