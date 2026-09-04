# frozen_string_literal: true

require("test_helper")

class MycoportalExportJobTest < ActiveJob::TestCase
  def teardown
    FileUtils.rm_rf(MycoportalExportJob::EXPORT_DIR)
    super
  end

  def test_no_alert_when_no_candidates
    Mycoportal::ExportCandidates.stub(:new, mock_candidates([], [])) do
      alerts = capture_alerts { MycoportalExportJob.perform_now }

      assert_empty(alerts)
    end
    assert_empty(Dir.glob("#{MycoportalExportJob::EXPORT_DIR}/*"))
  end

  def test_writes_csvs_marks_exported_and_alerts
    obs = create_observation(vote_cache: 3.0)

    Mycoportal::ExportCandidates.stub(:new, mock_candidates([], [obs.id])) do
      alerts = capture_alerts { MycoportalExportJob.perform_now }

      assert_equal(1, alerts.size)
      assert_includes(alerts.first.message, "1 observation(s)")
    end

    data_file = Dir.glob(
      "#{MycoportalExportJob::EXPORT_DIR}/mycoportal_data_*.csv"
    ).first
    assert_not_nil(data_file, "Expected a mycoportal_data CSV to be written")
    assert_includes(File.read(data_file), "MUOB #{obs.id}")

    images_file = Dir.glob(
      "#{MycoportalExportJob::EXPORT_DIR}/mycoportal_images_*.csv"
    ).first
    assert_not_nil(images_file,
                   "Expected a mycoportal_images CSV to be written")

    assert(
      ExternalLink.exists?(target_type: "Observation", target_id: obs.id,
                           external_site: ExternalSite.mycoportal,
                           relationship: :export),
      "perform should mark the observation as exported"
    )
  end

  private

  def mock_candidates(updated, new)
    candidates = Object.new
    candidates.define_singleton_method(:updated_observation_ids) { updated }
    candidates.define_singleton_method(:new_observation_ids) { new }
    candidates
  end

  def create_observation(vote_cache:)
    Observation.create!(
      user: users(:rolf), when: Time.zone.today, where: "anywhere",
      name_id: names(:coprinus_comatus).id, vote_cache: vote_cache
    )
  end

  # Records the exceptions handed to the #alerts pipeline while alerting is
  # forced active, so tests can assert on what a run would post to Slack.
  def capture_alerts(&block)
    alerts = []
    ExceptionNotifier.stub(:notifiers, [:slack]) do
      ExceptionNotifier.stub(:notify_exception,
                             lambda { |exception, **_o|
                               alerts << exception
                             }, &block)
    end
    alerts
  end
end
