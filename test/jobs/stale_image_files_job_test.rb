# frozen_string_literal: true

require("test_helper")

class StaleImageFilesJobTest < ActiveJob::TestCase
  # Large, deliberately out-of-range ids so this test's stray files can
  # never collide with a real fixture image id.
  FAKE_IDS = (999_900_001..999_900_004).to_a.freeze

  def local_root
    Image::Processor.local_images_path
  end

  def setup
    Image::URL::SUBDIRECTORIES.each_value do |dir|
      FileUtils.mkpath("#{local_root}/#{dir}")
    end
    super
  end

  def teardown
    Image::URL::SUBDIRECTORIES.each_value do |dir|
      FAKE_IDS.each do |id|
        FileUtils.rm_f("#{local_root}/#{dir}/#{id}.jpg")
      end
    end
    super
  end

  def test_no_alert_when_nothing_is_stale
    write_file("640", FAKE_IDS[0], age: 1.minute)

    alerts = capture_alerts { StaleImageFilesJob.perform_now }

    assert_empty(alerts)
  end

  def test_alerts_with_remediation_command_for_stale_files
    write_file("640", FAKE_IDS[1], age: 2.hours)

    alerts = capture_alerts { StaleImageFilesJob.perform_now }

    assert_equal(1, alerts.size)
    assert_instance_of(JobAlert, alerts.first)
    assert_includes(alerts.first.message, "1 image(s)")
    assert_includes(
      alerts.first.message,
      "TransferImagesJob.perform_now(image_ids: [#{FAKE_IDS[1]}])"
    )
  end

  def test_does_not_flag_sizes_kept_local
    MO.stub(:keep_these_image_sizes_local, [:medium]) do
      write_file("640", FAKE_IDS[2], age: 2.hours)

      alerts = capture_alerts { StaleImageFilesJob.perform_now }

      assert_empty(alerts)
    end
  end

  def test_deduplicates_ids_across_subdirs
    write_file("640", FAKE_IDS[3], age: 2.hours)
    write_file("960", FAKE_IDS[3], age: 2.hours)

    alerts = capture_alerts { StaleImageFilesJob.perform_now }

    assert_equal(1, alerts.size)
    assert_includes(
      alerts.first.message,
      "TransferImagesJob.perform_now(image_ids: [#{FAKE_IDS[3]}])"
    )
  end

  private

  def write_file(subdir, id, age:)
    path = "#{local_root}/#{subdir}/#{id}.jpg"
    File.write(path, "data")
    # File.utime needs a native Time, not TimeWithZone -- rubocop:disable
    # Rails/TimeZone is correct here, not a style violation to fix.
    time = Time.at((Time.zone.now - age).to_f) # rubocop:disable Rails/TimeZone
    File.utime(time, time, path)
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
