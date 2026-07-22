# frozen_string_literal: true

require("test_helper")

class GpsLeakDetectorJobTest < ActiveJob::TestCase
  def setup
    super
    @image = images(:in_situ_image)
    # in_situ_image belongs to minimal_unknown, which isn't gps_hidden;
    # make it a candidate: hidden obs, transferred, uploaded this week.
    @image.observations.first.update_columns(gps_hidden: true)
    @image.update_columns(transferred: true, created_at: 2.days.ago)
  end

  def test_alerts_with_ids_when_gps_found
    scanned = nil
    fake_scan = lambda do |images, &_log|
      scanned = images
      [@image.id]
    end

    alerts = Image::Processor.stub(:detect_gps_leaks, fake_scan) do
      capture_alerts { GpsLeakDetectorJob.perform_now }
    end

    assert_equal(1, alerts.size)
    assert_includes(alerts.first.message, "1 gps_hidden image(s)")
    assert_includes(alerts.first.message, "[#{@image.id}]")
    assert_includes(alerts.first.message, "#4859")
    assert_includes(scanned, @image)
  end

  def test_no_alert_when_scan_is_clean
    alerts = Image::Processor.stub(:detect_gps_leaks, ->(_i, &_l) { [] }) do
      capture_alerts { GpsLeakDetectorJob.perform_now }
    end

    assert_empty(alerts)
  end

  def test_candidate_scoping
    old = images(:turned_over_image)
    old.observations.first.update_columns(gps_hidden: true)
    old.update_columns(transferred: true, created_at: 3.months.ago)
    untransferred = images(:commercial_inquiry_image)
    untransferred.update_columns(transferred: false, created_at: 1.day.ago)

    scanned = nil
    Image::Processor.stub(:detect_gps_leaks, lambda { |images, &_log|
      scanned = images
      []
    }) do
      capture_alerts { GpsLeakDetectorJob.perform_now }
    end

    assert_includes(scanned, @image)
    assert_not_includes(scanned, old,
                        "images older than the window must be excluded")
    assert_not_includes(scanned, untransferred,
                        "untransferred images have no server copy yet")
  end

  private

  # See StaleImageFilesJobTest -- records exceptions handed to the
  # #alerts pipeline while alerting is forced active.
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
