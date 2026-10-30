# frozen_string_literal: true

require("test_helper")

class ContentPurgeTest < UnitTestCase
  def test_needs_exactly_one_target
    assert(ContentPurge.new(target_user: mary).valid?)
    assert(ContentPurge.new(inat_login: "someone").valid?)
    assert_not(ContentPurge.new.valid?, "A purge needs a target")
    both = ContentPurge.new(target_user: mary, inat_login: "someone")
    assert_not(both.valid?, "A purge has one target")
  end

  def test_in_progress_for
    done = ContentPurge.create!(target_user: mary, state: :done)
    running = ContentPurge.create!(target_user: mary, state: :running)

    assert_equal(running, ContentPurge.in_progress_for(target_user: mary))
    assert_nil(ContentPurge.in_progress_for(inat_login: "someone"))
    assert_not_equal(done, ContentPurge.in_progress_for(target_user: mary))
  end
end
