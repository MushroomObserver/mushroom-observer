# frozen_string_literal: true

require("test_helper")

class ImagePurgeTest < UnitTestCase
  def test_needs_exactly_one_target
    assert(ImagePurge.new(target_user: mary).valid?)
    assert(ImagePurge.new(inat_login: "someone").valid?)
    assert_not(ImagePurge.new.valid?, "A purge needs a target")
    assert_not(ImagePurge.new(target_user: mary, inat_login: "someone").valid?,
               "A purge has one target")
  end

  def test_in_progress_for
    done = ImagePurge.create!(target_user: mary, state: :done)
    running = ImagePurge.create!(target_user: mary, state: :running)

    assert_equal(running, ImagePurge.in_progress_for(target_user: mary))
    assert_nil(ImagePurge.in_progress_for(inat_login: "someone"))
    assert_not_equal(done, ImagePurge.in_progress_for(target_user: mary))
  end
end
