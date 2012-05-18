# encoding: utf-8
require File.expand_path(File.dirname(__FILE__) + '/../boot.rb')

class ProjectTest < UnitTestCase

  def test_add_and_remove_observations
    proj = projects(:eol_project)
    obs1 = Observation.find(1)
    obs2 = Observation.find(2)
    imgs = obs2.images.sort_by(&:id)
    assert_obj_list_equal([], proj.observations)
    assert_obj_list_equal([], proj.images)
    assert_obj_list_equal([], obs1.images)
    assert(imgs.any?)

    proj.add_observation(obs1)
    assert_obj_list_equal([obs1], proj.observations)
    assert_obj_list_equal([], proj.images)

    proj.add_observation(obs2)
    assert_obj_list_equal([obs1, obs2], proj.observations.sort_by(&:id))
    assert_obj_list_equal(imgs, proj.images.sort_by(&:id))

    proj.add_observation(obs2)
    assert_obj_list_equal([obs1, obs2], proj.observations.sort_by(&:id))
    assert_obj_list_equal(imgs, proj.images.sort_by(&:id))

    obs1.images << imgs.first
    proj.remove_observation(obs2)
    assert_obj_list_equal([obs1], proj.observations)
    # should keep first img because it is reused by another observation still attached to project
    assert_obj_list_equal([imgs.first], proj.images)

    proj.remove_observation(obs1)
    assert_obj_list_equal([], proj.observations)
    # should lose it now because no observations left which use it
    assert_obj_list_equal([], proj.images)

    proj.remove_observation(obs1)
    assert_obj_list_equal([], proj.observations)
    assert_obj_list_equal([], proj.images)
  end

  def test_add_and_remove_images
    proj = projects(:eol_project)
    img1 = Image.find(1)
    img2 = Image.find(2)
    assert_obj_list_equal([], proj.images)

    proj.add_image(img1)
    assert_obj_list_equal([img1], proj.images.sort_by(&:id))

    proj.add_image(img2)
    assert_obj_list_equal([img1,img2], proj.images.sort_by(&:id))

    proj.add_image(img2)
    assert_obj_list_equal([img1,img2], proj.images.sort_by(&:id))

    proj.remove_image(img1)
    assert_obj_list_equal([img2], proj.images)

    proj.remove_image(img2)
    assert_obj_list_equal([], proj.images)

    proj.remove_image(img2)
    assert_obj_list_equal([], proj.images)
  end

  def test_add_and_remove_species_lists
    proj = projects(:bolete_project)
    spl1 = species_lists(:first_species_list)
    spl2 = species_lists(:unknown_species_list)
    assert_obj_list_equal([spl2], proj.species_lists)

    proj.add_species_list(spl1)
    assert_obj_list_equal([spl1,spl2], proj.species_lists.sort_by(&:id))

    proj.add_species_list(spl2)
    assert_obj_list_equal([spl1,spl2], proj.species_lists.sort_by(&:id))

    proj.remove_species_list(spl2)
    assert_obj_list_equal([spl1], proj.species_lists)

    proj.remove_species_list(spl1)
    assert_obj_list_equal([], proj.species_lists)

    proj.remove_species_list(spl1)
    assert_obj_list_equal([], proj.species_lists)
  end
end
