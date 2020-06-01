# frozen_string_literal: true

require "test_helper"

class ProjectTest < UnitTestCase
  def test_add_and_remove_observations
    proj = projects(:eol_project)
    minimal_unknown_obs = observations(:minimal_unknown_obs)
    detailed_unknown_obs = observations(:detailed_unknown_obs)
    imgs = detailed_unknown_obs.images.sort_by(&:id)
    assert_obj_list_equal([], proj.observations)
    assert_obj_list_equal([], proj.images)
    assert_obj_list_equal([], minimal_unknown_obs.images)
    assert(imgs.any?)

    proj.add_observation(minimal_unknown_obs)
    assert_obj_list_equal([minimal_unknown_obs], proj.observations)
    assert_obj_list_equal([], proj.images)

    proj.add_observation(detailed_unknown_obs)
    assert_obj_list_equal([minimal_unknown_obs, detailed_unknown_obs],
                          proj.observations.sort_by(&:id))
    assert_obj_list_equal(imgs, proj.images.sort_by(&:id))

    proj.add_observation(detailed_unknown_obs)
    assert_obj_list_equal([minimal_unknown_obs, detailed_unknown_obs],
                          proj.observations.sort_by(&:id))
    assert_obj_list_equal(imgs, proj.images.sort_by(&:id))

    minimal_unknown_obs.images << imgs.first
    proj.remove_observation(detailed_unknown_obs)
    assert_obj_list_equal([minimal_unknown_obs], proj.observations)
    # should keep first img because it is reused
    # by another observation still attached to project
    assert_obj_list_equal([imgs.first], proj.images)

    proj.remove_observation(minimal_unknown_obs)
    assert_obj_list_equal([], proj.observations)
    # should lose it now because no observations left which use it
    assert_obj_list_equal([], proj.images)

    proj.remove_observation(minimal_unknown_obs)
    assert_obj_list_equal([], proj.observations)
    assert_obj_list_equal([], proj.images)
  end

  def test_add_and_remove_images
    in_situ_img = images(:in_situ_image)
    turned_over_img = images(:turned_over_image)
    proj = projects(:eol_project)

    assert_obj_list_equal([], proj.images)

    proj.add_image(in_situ_img)
    assert_obj_list_equal([in_situ_img], proj.images)

    proj.add_image(turned_over_img)
    assert_obj_list_equal([in_situ_img, turned_over_img].sort_by(&:id),
                          proj.images.sort_by(&:id))

    proj.add_image(turned_over_img)
    assert_obj_list_equal([in_situ_img, turned_over_img].sort_by(&:id),
                          proj.images.sort_by(&:id))

    proj.remove_image(in_situ_img)
    assert_obj_list_equal([turned_over_img], proj.images)

    proj.remove_image(turned_over_img)
    assert_obj_list_equal([], proj.images)

    proj.remove_image(turned_over_img)
    assert_obj_list_equal([], proj.images)
  end

  def test_add_and_remove_species_lists
    proj = projects(:bolete_project)
    first_list = species_lists(:first_species_list)
    another_list = species_lists(:unknown_species_list)
    assert_obj_list_equal([another_list], proj.species_lists)

    proj.add_species_list(first_list)
    assert_obj_list_equal([first_list, another_list].sort_by(&:id),
                          proj.species_lists.sort_by(&:id))

    proj.add_species_list(another_list)
    assert_obj_list_equal([first_list, another_list].sort_by(&:id),
                          proj.species_lists.sort_by(&:id))

    proj.remove_species_list(another_list)
    assert_obj_list_equal([first_list], proj.species_lists)

    proj.remove_species_list(first_list)
    assert_obj_list_equal([], proj.species_lists)

    proj.remove_species_list(first_list)
    assert_obj_list_equal([], proj.species_lists)
  end
end
