# frozen_string_literal: true

require("test_helper")

class ImageTest < UnitTestCase
  def test_votes
    img = images(:in_situ_image)
    assert(img.image_votes.empty?)
    assert_equal(0, img.num_votes)
    assert_equal(0, img.vote_cache.to_i)
    assert_nil(img.users_vote(mary))
    assert_nil(img.users_vote(rolf))

    img.change_vote(mary, 2)
    assert_equal(1, img.num_votes)
    assert_equal(2, img.vote_cache)
    assert_equal(2, img.users_vote(mary))
    assert_nil(img.users_vote(rolf))
    assert_false(img.image_votes.first.anonymous)

    img.change_vote(rolf, 4, anon: true)
    assert_equal(2, img.num_votes)
    assert_equal(3, img.vote_cache)
    assert_equal(2, img.users_vote(mary))
    assert_equal(4, img.users_vote(rolf))

    img.change_vote(mary, nil)
    assert_equal(1, img.num_votes)
    assert_equal(4, img.vote_cache)
    assert_equal(4, img.users_vote(rolf))
    assert_nil(img.users_vote(mary))
    assert_true(img.image_votes.first.anonymous)

    img.change_vote(rolf, nil)
    assert_nil(img.users_vote(mary))
    assert_nil(img.users_vote(rolf))
  end

  def test_copyright_logging
    User.current = mary

    license_one = licenses(:ccnc25)
    license_two = licenses(:ccwiki30)
    name_one = "Bobby Singer"
    name_two = "Robert H. Singer"
    date_one = Date.parse("2007-12-31")
    date_two = Date.parse("2008-01-01")

    img = Image.create(
      user: mary,
      when: date_one,
      license: license_one,
      copyright_holder: name_one
    )
    assert_equal(date_one.year, img.when.year)
    assert_equal(license_one, img.license)
    assert_equal(name_one, img.copyright_holder)
    assert_equal(0, img.copyright_changes.length)

    img.original_name = "blah blah"
    img.save
    img.reload
    assert_equal(0, img.copyright_changes.length)

    img.when = date_two
    img.save
    img.reload
    assert_equal(date_two.year, img.when.year)
    assert_not_equal(date_one.year, date_two.year)
    assert_equal(1, img.copyright_changes.length)

    img.copyright_holder = name_two
    img.license = license_two
    img.save
    img.reload
    assert_equal(name_two, img.copyright_holder)
    assert_equal(license_two, img.license)
    assert_equal(2, img.copyright_changes.length)

    changes = img.copyright_changes
    assert_equal(2, changes.length)
    assert_equal(date_one.year, changes[0].year)
    assert_equal(name_one,      changes[0].name)
    assert_equal(license_one,   changes[0].license)
    assert_equal(date_two.year, changes[1].year)
    assert_equal(name_one,      changes[1].name)
    assert_equal(license_one,   changes[1].license)
  end

  def test_project_ownership
    # NOT owned by Bolete project, but owned by Rolf
    img = images(:commercial_inquiry_image)
    assert_true(img.can_edit?(rolf))
    assert_false(img.can_edit?(mary))
    assert_false(img.can_edit?(dick))

    # IS owned by Bolete project, AND owned by Mary
    # (Dick is member of Bolete project)
    img = images(:in_situ_image)
    assert_false(img.can_edit?(rolf))
    assert_true(img.can_edit?(mary))
    assert_true(img.can_edit?(dick))
  end

  def test_validation
    img = Image.new
    assert_false(img.valid?)
    img.user = rolf
    assert_true(img.valid?)
    do_truncate_test(img, :content_type, 100)
    do_truncate_test(img, :copyright_holder, 100)
  end

  def do_truncate_test(img, var, len)
    exes = "x" * (len - 1)
    assert_truncated_right(img, var, exes, exes)
    assert_truncated_right(img, var, "#{exes}a", "#{exes}a")
    assert_truncated_right(img, var, "#{exes}å", "#{exes}å")
    assert_truncated_right(img, var, "#{exes}aå", "#{"x" * (len - 3)}...")
  end

  def assert_truncated_right(img, var, set, get)
    img.send(:"#{var}=", set)
    img.valid?
    assert_equal(get, img.send(var))
  end

  def test_presence_of_critical_external_scripts
    assert_not(Rails.root.join("script/bogus_script").exist?,
               "script/bogus_script should not exist!")
    assert(Rails.root.join("script/process_image").exist?,
           "Missing script/process_image!")
    assert(Rails.root.join("script/rotate_image").exist?,
           "Missing script/rotate_image!")
    assert(Rails.root.join("script/retransfer_images").exist?,
           "Missing script/retransfer_images!")
  end

  def test_transform
    img = Image.new
    assert_nil(img.transform(:mirror))
    assert_raises(RuntimeError) { img.transform(:edible) }
  end

  def test_move_original_system_fail
    img = Image.new
    File.stub(:rename, false) do
      Kernel.stub(:system, false) do
        assert_raises(RuntimeError) { img.move_original }
      end
    end
  end

  def test_glossary_terms
    img1  = images(:conic_image)
    img2  = images(:unused_image)
    term1 = glossary_terms(:conic_glossary_term)
    term2 = glossary_terms(:unused_thumb_and_used_image_glossary_term)
    assert_obj_arrays_equal([term1, term2].sort_by(&:id),
                            img1.glossary_terms.sort_by(&:id))
    assert_obj_arrays_equal([term1], img1.thumb_glossary_terms)
    assert_obj_arrays_equal([term2], img2.glossary_terms)
    assert_obj_arrays_equal([term2], img2.thumb_glossary_terms)
  end

  def test_delete_thmubnail_of_glossary_term_with_no_other_images
    term = glossary_terms(:conic_glossary_term)
    thumb = term.thumb_image
    other_images = term.images - [thumb]
    assert_not_nil(thumb)
    assert_empty(other_images)

    User.current = thumb.user
    thumb.destroy!

    assert_nil(term.reload.thumb_image,
               "Glossary term has destroyed image as thumbnail!")
    assert_empty(term.images, "Glossary term should have no images left!")
  end

  def test_delete_thmubnail_of_glossary_term_with_multiple_images
    term = glossary_terms(:plane_glossary_term)
    thumb = term.thumb_image
    other_images = term.images - [thumb]
    assert_not_nil(thumb)
    assert_not_empty(other_images)
    assert_includes(thumb.glossary_terms, term)
    assert_includes(thumb.thumb_glossary_terms, term)
    thumb_id = thumb.id
    other_image_ids = other_images.map(&:id)

    User.current = thumb.user
    thumb.destroy!

    assert_false(term.reload.image_ids.include?(thumb_id),
                 "Glossary term is attached to destroyed image!")
    assert_true(other_image_ids.include?(term.thumb_image_id),
                "Should have chosen another thumbnail for glossary term.")
  end

  def test_delete_thumbnail_of_observation_with_no_other_images
    obs = observations(:coprinus_comatus_obs)
    thumb = obs.thumb_image
    other_images = obs.images - [thumb]
    assert_not_nil(thumb)
    assert_empty(other_images)

    User.current = thumb.user
    thumb.destroy!

    assert_nil(obs.reload.thumb_image,
               "Observation has destroyed image as thumbnail!")
    assert_empty(obs.images, "Observation should have no images left!")
  end

  def test_delete_thumbnail_of_observation_with_multiple_images
    obs = observations(:detailed_unknown_obs)
    thumb = obs.thumb_image
    other_images = obs.images - [thumb]
    assert_not_nil(thumb)
    assert_not_empty(other_images)
    assert_includes(thumb.observations, obs)
    assert_includes(thumb.thumb_observations, obs)
    thumb_id = thumb.id
    other_image_ids = other_images.map(&:id)

    User.current = thumb.user
    thumb.destroy!

    assert_false(obs.reload.image_ids.include?(thumb_id),
                 "Observation is attached to destroyed image!")
    assert_true(other_image_ids.include?(obs.thumb_image_id),
                "Should have chosen another thumbnail for observation.")
  end

  def test_delete_user_profile_image
    assert_not_nil(rolf.image)

    User.current = rolf.image.user
    rolf.image.destroy!

    assert_nil(rolf.reload.image_id,
               "Rolf's is using a destroyed image for profile image!")
  end

  def test_delete_project_image
    project = projects(:bolete_project)
    image = project.images.first
    assert_not_nil(image)
    image_id = image.id

    User.current = image.user
    image.destroy!

    assert_false(project.reload.image_ids.include?(image_id),
                 "Project is still attached to a destroyed image!")
  end

  def test_delete_visual_group_image
    group = visual_groups(:visual_group_one)
    image = group.images.first
    assert_not_nil(image)
    image_id = image.id

    User.current = image.user
    image.destroy!

    assert_false(group.reload.image_ids.include?(image_id),
                 "VisualGroup still references a destroyed image!")
  end

  def test_delete_image_with_votes
    image = images(:peltigera_image)
    image_id = image.id
    assert_not_empty(ImageVote.where(image_id: image_id))

    User.current = image.user
    image.destroy!

    assert_empty(ImageVote.where(image_id: image_id),
                 "Failed to delete ImageVotes attached to destroyed image!")
  end
end
