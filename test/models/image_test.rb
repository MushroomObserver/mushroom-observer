require "test_helper"

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

    img.change_vote(rolf, 4, :anon)
    assert_equal(2, img.num_votes)
    assert_equal(3, img.vote_cache)
    assert_equal(2, img.users_vote(mary))
    assert_equal(4, img.users_vote(rolf))

    img.change_vote(mary)
    assert_equal(1, img.num_votes)
    assert_equal(4, img.vote_cache)
    assert_equal(4, img.users_vote(rolf))
    assert_nil(img.users_vote(mary))
    assert_true(img.image_votes.first.anonymous)

    img.change_vote(rolf)
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
    assert_truncated_right(img, var, exes + "a", exes + "a")
    assert_truncated_right(img, var, exes + "å", exes + "å")
    assert_truncated_right(img, var, exes + "aå", "x" * (len - 3) + "...")
  end

  def assert_truncated_right(img, var, set, get)
    img.send("#{var}=", set)
    img.valid?
    assert_equal(get, img.send(var))
  end

  def test_presence_of_critical_external_scripts
    assert_not(File.exist?("#{::Rails.root}/script/bogus_script"),
               "script/bogus_script should not exist!")
    assert(File.exist?("#{::Rails.root}/script/process_image"),
           "Missing script/process_image!")
    assert(File.exist?("#{::Rails.root}/script/rotate_image"),
           "Missing script/rotate_image!")
    assert(File.exist?("#{::Rails.root}/script/retransfer_images"),
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
end
