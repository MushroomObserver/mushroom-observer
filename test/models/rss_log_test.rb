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

      assert(rss_log.url.starts_with?("#{model(type).show_controller}/#{id}"),
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

  def test_details
    log = rss_logs(:observation_rss_log)
    assert_equal(log.detail, "Updated Observation &amp; Notes")

    log = rss_logs(:imged_unvouchered_obs_rss_log)
    assert_equal(log.detail, "Updated Observation &amp; Notes")

    log = rss_logs(:locally_sequenced_obs_rss_log)
    assert_equal(log.detail, "Observation Created")

    log = rss_logs(:species_list_rss_log)
    assert_equal(log.detail, "Updated Species List")

    log = rss_logs(:name_rss_log)
    assert_equal(log.detail, "Updated Name")

    log = rss_logs(:location_rss_log)
    assert_equal(log.detail, "Updated Location")

    log = rss_logs(:albion_rss_log)
    assert_equal(log.detail, "Updated Created")

    log = rss_logs(:glossary_term_rss_log)
    assert_equal(log.detail, "Updated Glossary Term")

    log = rss_logs(:project_rss_log)
    assert_equal(log.detail, "Updated Project")

    log = rss_logs(:article_rss_log)
    assert_equal(log.detail, "Updated Article")
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
end
