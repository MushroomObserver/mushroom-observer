# encoding: utf-8
require File.expand_path(File.dirname(__FILE__) + '/../boot.rb')

class SpeciesListTest < UnitTestCase

  def test_project_ownership

    # NOT owned by Bolete project, but owned by Rolf
    spl = species_lists(:first_species_list)
    assert_true(spl.has_edit_permission?(@rolf))
    assert_false(spl.has_edit_permission?(@mary))
    assert_false(spl.has_edit_permission?(@dick))

    # IS owned by Bolete project, AND owned by Mary (Dick is member of Bolete project)
    spl = species_lists(:unknown_species_list)
    assert_false(spl.has_edit_permission?(@rolf))
    assert_true(spl.has_edit_permission?(@mary))
    assert_true(spl.has_edit_permission?(@dick))
  end

  def test_add_and_remove_observations
    spl = species_lists(:first_species_list)
    obs1 = Observation.find(1)
    obs2 = Observation.find(2)
    assert_obj_list_equal([], spl.observations)

    spl.add_observation(obs1)
    assert_obj_list_equal([obs1], spl.observations)

    spl.add_observation(obs1)
    assert_obj_list_equal([obs1], spl.observations)

    spl.add_observation(obs2)
    assert_obj_list_equal([obs1,obs2], spl.observations.sort_by(&:id))

    spl.remove_observation(obs1)
    assert_obj_list_equal([obs2], spl.observations)

    spl.remove_observation(obs1)
    assert_obj_list_equal([obs2], spl.observations)

    spl.remove_observation(obs2)
    assert_obj_list_equal([], spl.observations)

    spl.remove_observation(obs2)
    assert_obj_list_equal([], spl.observations)
  end

  def test_construct_observation
    spl = SpeciesList.first
    assert_users_equal(@rolf, spl.user)
    proj = projects(:bolete_project)
    proj.add_species_list(spl)
    assert_obj_list_equal([@dick], proj.user_group.users)
    User.current = @dick
    name = Name.first

    # Test defaults first.
    now = Time.now
    spl.construct_observation(name)
    o = Observation.last
    n = Naming.last
    v = Vote.last
    assert_objs_equal(o, spl.observations.last)
    assert(o.created >= 1.minute.ago)
    assert(o.modified >= 1.minute.ago)
    assert_users_equal(@dick, o.user)
    assert_obj_list_equal([proj], o.projects)
    assert_equal(spl.when, o.when)
    assert_equal(spl.where, o.where)
    assert_equal(spl.location, o.location)
    assert_equal('', o.notes)
    assert_nil(o.alt)
    assert_nil(o.long)
    assert_nil(o.alt)
    assert_true(o.is_collection_location)
    assert_false(o.specimen)
    assert_names_equal(name, o.name)
    assert_obj_list_equal([n], o.namings)
    assert(n.created <= now)
    assert(n.modified <= now)
    assert_users_equal(@dick, n.user)
    assert_names_equal(name, n.name)
    assert_obj_list_equal([v], n.votes)
    assert(v.created <= now)
    assert(v.modified <= now)
    assert_users_equal(@dick, v.user)
    assert_equal(Vote.maximum_vote, v.value)

    # Now override everything.
    spl.construct_observation(name,
      :user                   => @mary,
      :projects               => [],
      :when                   => '2012-01-13',
      :where                  => 'Undefined Location',
      :notes                  => 'notes',
      :lat                    => ' 12deg 34min N ',
      :long                   => ' 123 45 W ',
      :alt                    => ' 123.45 ft ',
      :is_collection_location => false,
      :specimen               => true,
      :vote                   => Vote.next_best_vote
    )
    o = Observation.last
    n = Naming.last
    v = Vote.last
    assert_objs_equal(o, spl.observations.last)
    assert_users_equal(@mary, o.user)
    assert_obj_list_equal([], o.projects)
    assert_equal('2012-01-13', o.when.web_date)
    assert_equal('Undefined Location', o.where)
    assert_equal(nil, o.location)
    assert_equal('notes', o.notes)
    assert_equal(12.5667, o.lat.round(4))
    assert_equal(-123.75, o.long.round(4))
    assert_equal(38, o.alt.round(4))
    assert_false(o.is_collection_location)
    assert_true(o.specimen)
    assert_names_equal(name, o.name)
    assert_obj_list_equal([n], o.namings)
    assert_users_equal(@mary, n.user)
    assert_names_equal(name, n.name)
    assert_obj_list_equal([v], n.votes)
    assert_users_equal(@mary, v.user)
    assert_equal(Vote.next_best_vote, v.value)
  end
end
