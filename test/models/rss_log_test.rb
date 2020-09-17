# frozen_string_literal: true

require("test_helper")

class RssLogTest < UnitTestCase
  # Alert developer if normalization changes the path of an RssLogg'ed object
  # The test should be deleted once controllers for all RssLog'ged objects are
  # normalized.
  # See https://www.pivotaltracker.com/story/show/174685402
  def test_url_for_normalized_controllers
    normalized_rss_log_types.each do |type|
      rss_log = create_rss_log(type)
      id = rss_log.target_id
      assert_match(type_normalized_show_path(type, id), rss_log.url,
                   "rss_log.url incorrect for #{model(type)}")
    end
  end

  def test_orphan_title
    log = rss_logs(:location_rss_log)
    assert_equal(log.notes, log.orphan_title)

    # replace normal top line of log with yyyymmddhhmmss
    log.notes = Time.zone.now.strftime("%Y%m%d%I%M%S")
    assert_equal(:rss_log_of_deleted_item.l, log.orphan_title)
  end

  # ---------- helpers ---------------------------------------------------------

  def normalized_rss_log_types
    RssLog.all_types.each_with_object([]) do |type, ary|
      ary << type if model(type).controller_normalized?(model(type).name)
    end
  end

  def model(type)
    type.camelize.constantize
  end

  # rss_log factory
  def create_rss_log(type)
    # Target must have id; use an existing object to avoid hitting db
    target = model(type).first
    rss_log = RssLog.new
    rss_log["#{type}_id".to_sym] = target.id
    rss_log.updated_at = Time.zone.now
    rss_log
  end

  def type_normalized_show_path(type, id)
    %r{/#{model(type).show_controller}/#{id}}
  end
end
