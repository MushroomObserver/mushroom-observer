# frozen_string_literal: true

require("test_helper")

class EXIFDataJobTest < ActiveJob::TestCase
  include ActionCable::TestHelper

  def test_broadcasts_exif_table_on_success
    image = images(:in_situ_image)
    image.update_attribute(:transferred, false)
    copy_geotagged_fixture_to(image)

    assert_broadcasts(stream_for(image), 1) do
      EXIFDataJob.perform_now(image.id)
    end

    assert_includes(broadcasts(stream_for(image)).first,
                    "exif_data_frame_#{image.id}")
    assert_includes(broadcasts(stream_for(image)).first, "GPS Latitude")
  end

  def test_broadcasts_error_pre_when_unreadable
    image = images(:in_situ_image)
    FileUtils.rm_f(image.full_filepath("orig"))

    assert_broadcasts(stream_for(image), 1) do
      EXIFDataJob.perform_now(image.id)
    end

    assert_includes(broadcasts(stream_for(image)).first, "File not found")
  end

  def test_missing_image_is_a_noop
    assert_nothing_raised do
      EXIFDataJob.perform_now(-1)
    end
  end

  def test_enqueue_for_schedules_with_delay
    EXIFDataJob.enqueue_for(42)

    job = enqueued_jobs.last

    assert_equal("EXIFDataJob", job[:job].to_s)
    assert_equal([42], job[:args])
    assert(job[:at] >= Time.zone.now.to_f)
  end

  private

  def stream_for(image)
    Turbo::StreamsChannel.send(:stream_name_from, "exif_data_#{image.id}")
  end

  def copy_geotagged_fixture_to(image)
    fixture = "#{MO.root}/test/images/geotagged.jpg"
    file = image.full_filepath("orig")
    FileUtils.mkdir_p(File.dirname(file))
    FileUtils.cp(fixture, file)
  end
end
