# frozen_string_literal: true

require("test_helper")

# tests of MO's "rss_logs"
class RssLogTest < UnitTestCase
  def test_url_for_normalized_controllers
    normalized_rss_log_types.each do |type|
      rss_log = rss_log_for_type(type)
      id = rss_log.target_id
      assert_match(type_normalized_show_path(type, id), rss_log.url,
                   "rss_log.url incorrect for #{model(type)}")
    end
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
  def rss_log_for_type(type)
    # Target must have id; use an existing object to avoid hitting db
    target = model(type).first
    rss_log = RssLog.new
    rss_log["#{type}_id".to_sym] = target.id
    rss_log.updated_at = Time.zone.now
    rss_log
  end

  def target_id(rss_log)
    rss_log.target_id
  end

  def type_normalized_show_path(type, id)
    %r{/#{model(type).show_controller}/#{id}}
  end
end
