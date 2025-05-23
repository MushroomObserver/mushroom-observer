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

  def test_orphan_title
    log = rss_logs(:location_rss_log)
    # If log doesn't look orphaned, it should return generic "deleted item".
    assert_equal(:rss_log_of_deleted_item.l, log.orphan_title)

    # When it is orphaned, it should put the target title in the first line
    # of the log, and that's what orphan_title should return.
    log.update(notes: "Target Title\n#{log.notes}")
    assert_equal("Target Title", log.orphan_title)
  end

  def test_detail_for_complexly_created_observation
    # Observation is created then an image is immediately uploaded.
    # We want it to return "observation created" not "image added".
    log = rss_logs(:detailed_unknown_obs_rss_log)
    detail = log.detail
    assert_equal(:rss_created_at.t(type: :observation), detail)
  end

  def test_detail_for_destroyed_object
    # User.current = users(:dick)
    obs = observations(:detailed_unknown_obs)
    obs.current_user = users(:dick)
    log = obs.rss_log
    assert_not_nil(log)
    assert_false(log.orphan?)
    obs.destroy!
    log.reload
    assert_true(log.orphan?)
    assert_equal(:log_observation_destroyed.t(user: "dick"), log.detail)
  end

  def test_detail_for_merged_location
    User.current = users(:mary)
    loc1 = locations(:albion)
    loc2 = locations(:mitrula_marsh)
    log = loc1.rss_log
    assert_false(log.orphan?)
    loc2.merge(mary, loc1)
    log.reload
    assert_true(log.orphan?)
    assert_equal(:log_location_merged.t(that: loc2.display_name, user: "mary"),
                 log.detail)
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
                      type: :OBSERVATION)
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
