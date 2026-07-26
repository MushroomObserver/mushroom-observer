# frozen_string_literal: true

require("test_helper")

class RssLogTest < UnitTestCase
  # Alert developer if normalization changes the path of an RssLogg'ed object
  # The test should be deleted once controllers for all RssLog'ged objects are
  # normalized.
  # See https://www.pivotaltracker.com/story/show/174685402
  def test_url_for_normalized_controllers
    RssLog::ALL_TYPE_TAGS.each do |type|
      rss_log = create_rss_log(type)
      id = rss_log.target_id

      assert(rss_log.url.include?("#{model(type).show_controller}/#{id}"),
             "rss_log.url incorrect for #{model(type)}")
    end
  end

  def test_add_with_date_refuses_to_write_to_orphaned_log
    log = rss_logs(:location_rss_log)
    # Orphan it the way #orphan does: clear the target ids and prepend a
    # title line so notes no longer lead with a timestamp.
    log.clear_target_id
    log.update(notes: "Target Title\n#{log.notes}")
    assert(log.already_orphaned?)
    assert_nil(log.target_id)
    before = log.notes

    log.add_with_date(:log_location_updated, user: "mary")
    log.reload

    # The write is refused: notes are unchanged, so the log stays a proper
    # orphan instead of turning back into a deletable "ghost". See #4763.
    assert_equal(before, log.notes)
    assert(log.already_orphaned?)
    assert_nil(log.target_id)
  end

  def test_orphaning_still_works_through_the_guard
    obs = observations(:detailed_unknown_obs)
    obs.current_user = users(:dick)
    log = obs.rss_log
    assert_not(log.already_orphaned?)

    # Destroying the object orphans its log via #orphan, which calls
    # add_with_date *before* prepending the title. The guard must not block
    # that path.
    obs.destroy!
    log.reload

    assert(log.orphan?)
    assert(log.already_orphaned?)
  end

  def test_a_fresh_log_is_not_treated_as_orphaned
    log = RssLog.new
    assert_not(log.already_orphaned?)

    log.add_with_date(:log_observation_created, user: "mary")

    assert_match(/log_observation_created/, log.notes)
  end

  def test_really_long_notes
    max = RssLog::MAX_LENGTH
    log = RssLog.first
    log.notes = "test test " * (max / 10 - 1)
    log.save
    assert_operator(max, ">", log.notes.length)
    assert_operator(max, "<", log.notes.length + 20)
    log.add_with_date(:log_object_created_by_user,
                      user: "make sure this is nice and long!",
                      type: :observation)
    log.reload
    assert_operator(max, ">", log.notes.length)
  end

  # ---------- helpers ---------------------------------------------------------

  def model(type)
    type.to_s.camelize.constantize
  end

  # rss_log factory
  def create_rss_log(type)
    # Target must have id; use an existing object to avoid hitting db
    target = model(type).first
    rss_log = RssLog.new
    rss_log[:"#{type}_id"] = target.id
    rss_log.updated_at = Time.zone.now
    rss_log
  end
end
