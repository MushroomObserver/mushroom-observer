# frozen_string_literal: true

require("test_helper")

# Tests for RssLog::Title (app/models/rss_log/title.rb)
class RssLog::TitleTest < UnitTestCase
  def test_orphan_title
    log = rss_logs(:location_rss_log)
    # If log doesn't look orphaned, it should return generic "deleted item".
    assert_equal(:rss_log_of_deleted_item.l, log.title.send(:orphan_title))

    # When it is orphaned, it should put the target title in the first line
    # of the log, and that's what orphan_title should return.
    log.update(notes: "Target Title\n#{log.notes}")
    assert_equal("Target Title", log.title.send(:orphan_title))
  end

  def test_text_name
    # Name responds to real_text_name directly.
    name_log = create_rss_log(:name)
    assert_equal(Name.first.real_text_name, name_log.text_name)

    # Observation doesn't define real_text_name, falls to text_name.
    obs_log = create_rss_log(:observation)
    assert_equal(Observation.first.text_name, obs_log.text_name)

    # Orphaned (no target at all).
    orphan_log = RssLog.new
    assert_equal(
      orphan_log.title.send(:orphan_title).t.html_to_ascii.sub(/ (\d+)$/, ""),
      orphan_log.text_name
    )
  end

  def test_unique_text_name
    log = create_rss_log(:species_list)
    assert_equal(SpeciesList.first.unique_text_name, log.unique_text_name)

    orphan_log = RssLog.new
    assert_equal(orphan_log.title.send(:orphan_title).t.html_to_ascii,
                 orphan_log.unique_text_name)
  end

  def test_format_name
    log = create_rss_log(:species_list)
    assert_equal(SpeciesList.first.format_name, log.format_name)

    orphan_log = RssLog.new
    assert_equal(orphan_log.title.send(:orphan_title).sub(/ (\d+)$/, ""),
                 orphan_log.format_name)
  end

  def test_unique_format_name
    log = create_rss_log(:species_list)
    assert_equal(SpeciesList.first.unique_format_name, log.unique_format_name)

    orphan_log = RssLog.new
    assert_equal(orphan_log.title.send(:orphan_title),
                 orphan_log.unique_format_name)
  end

  # ---------- helpers ---------------------------------------------------

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
