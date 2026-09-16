# frozen_string_literal: true

require("test_helper")

class StaleImageFilesJobTest < ActiveJob::TestCase
  # Large, deliberately out-of-range ids so this test's stray files can
  # never collide with a real fixture image id -- and, having no Image
  # row, they classify as orphaned files (#4974).
  FAKE_IDS = (999_900_001..999_900_004).to_a.freeze

  def local_root
    Image::Processor.local_images_path
  end

  def setup
    @written = []
    Image::URL::SUBDIRECTORIES.each_value do |dir|
      FileUtils.mkpath("#{local_root}/#{dir}")
    end
    super
  end

  def teardown
    @written.each { |path| FileUtils.rm_f(path) }
    super
  end

  def test_no_alert_when_nothing_is_stale
    write_file("640", FAKE_IDS[0], age: 1.minute)

    alerts = capture_alerts { StaleImageFilesJob.perform_now }

    assert_empty(alerts)
  end

  # A stale file with no Image row can't be transferred or reprocessed --
  # the only remedy is deleting it, and the alert must say so instead of
  # advising a retry that cannot work (#4974).
  def test_orphaned_files_get_delete_advice
    file1 = write_file("640", FAKE_IDS[1], age: 2.hours)
    file2 = write_file("960", FAKE_IDS[1], age: 2.hours)

    alerts = capture_alerts { StaleImageFilesJob.perform_now }

    assert_equal(1, alerts.size)
    assert_instance_of(JobAlert, alerts.first)
    assert_includes(alerts.first.message, "no Image row")
    assert_includes(alerts.first.message, "FileUtils.rm_f")
    assert_includes(alerts.first.message, file1)
    assert_includes(alerts.first.message, file2)
    assert_not_includes(alerts.first.message, "TransferImagesJob")
  end

  # An image whose derivative sizes were never generated (processing
  # died mid-#process, #4974) needs reprocessing -- retrying the
  # transfer would do nothing, since Verifier skips images with missing
  # local sizes.
  def test_unprocessed_image_gets_reprocess_advice
    image = images(:turned_over_image)
    write_file("orig", image.id, age: 2.hours)

    alerts = capture_alerts { StaleImageFilesJob.perform_now }

    assert_equal(1, alerts.size)
    assert_includes(alerts.first.message, "processing died?")
    assert_includes(alerts.first.message,
                    Image::Processor.reprocess_command([image.id]))
  end

  # A complete set of local files is a genuine transfer straggler -- the
  # one state where retrying TransferImagesJob is the right advice.
  def test_untransferred_image_gets_retry_advice
    image = images(:turned_over_image)
    Image::URL::SUBDIRECTORIES.each_value do |dir|
      write_file(dir, image.id, age: 2.hours)
    end

    alerts = capture_alerts { StaleImageFilesJob.perform_now }

    assert_equal(1, alerts.size)
    assert_includes(alerts.first.message,
                    TransferImagesJob.retry_command([image.id]))
    assert_not_includes(alerts.first.message, "Reprocess")
  end

  # Each classification alerts independently, so mixed findings arrive
  # as separate, correctly-advised messages.
  def test_mixed_states_alert_separately
    write_file("640", FAKE_IDS[2], age: 2.hours)
    image = images(:turned_over_image)
    write_file("orig", image.id, age: 2.hours)

    alerts = capture_alerts { StaleImageFilesJob.perform_now }

    assert_equal(2, alerts.size)
    messages = alerts.map(&:message)
    assert(messages.any? { |msg| msg.include?("no Image row") })
    assert(messages.any? do |msg|
      msg.include?(Image::Processor.reprocess_command([image.id]))
    end)
  end

  def test_does_not_flag_sizes_kept_local
    MO.stub(:keep_these_image_sizes_local, [:medium]) do
      write_file("640", FAKE_IDS[3], age: 2.hours)

      alerts = capture_alerts { StaleImageFilesJob.perform_now }

      assert_empty(alerts)
    end
  end

  private

  def write_file(subdir, id, age:)
    path = "#{local_root}/#{subdir}/#{id}.jpg"
    File.write(path, "data")
    # File.utime needs a native Time, not TimeWithZone -- rubocop:disable
    # Rails/TimeZone is correct here, not a style violation to fix.
    time = Time.at((Time.zone.now - age).to_f) # rubocop:disable Rails/TimeZone
    File.utime(time, time, path)
    @written << path
    path
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
