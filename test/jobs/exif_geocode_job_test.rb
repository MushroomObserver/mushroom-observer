# frozen_string_literal: true

require("test_helper")

class EXIFGeocodeJobTest < ActiveJob::TestCase
  include ActionCable::TestHelper

  def test_broadcasts_geotagged_exif_data
    image = images(:in_situ_image)
    image.update_attribute(:transferred, false)
    copy_geotagged_fixture_to(image)

    assert_broadcasts(stream_for(image), 1) do
      EXIFGeocodeJob.perform_now(image.id, read_only: false,
                                           date_differs: false)
    end

    assert_includes(broadcasts(stream_for(image)).first, "25.7582")
  end

  def test_falls_back_to_database_date_with_no_exif
    image = images(:in_situ_image)
    image.update_attribute(:transferred, false)
    FileUtils.rm_f(image.full_filepath("orig"))

    EXIFGeocodeJob.perform_now(image.id, read_only: false, date_differs: false)

    assert_includes(broadcasts(stream_for(image)).first,
                    image.when.strftime("%d-%B-%Y"))
  end

  def test_missing_image_is_a_noop
    assert_nothing_raised do
      EXIFGeocodeJob.perform_now(-1, read_only: false, date_differs: false)
    end
  end

  def test_enqueue_for_schedules_with_delay
    EXIFGeocodeJob.enqueue_for(42, read_only: true, date_differs: true)

    job = enqueued_jobs.last
    kwargs = job[:args].last.except("_aj_ruby2_keywords")

    assert_equal("EXIFGeocodeJob", job[:job].to_s)
    assert_equal(42, job[:args].first)
    assert_equal({ "read_only" => true, "date_differs" => true }, kwargs)
    assert(job[:at] >= Time.zone.now.to_f)
  end

  private

  def stream_for(image)
    Turbo::StreamsChannel.send(:stream_name_from, "exif_geocode_#{image.id}")
  end

  def copy_geotagged_fixture_to(image)
    fixture = "#{MO.root}/test/images/geotagged.jpg"
    file = image.full_filepath("orig")
    FileUtils.mkdir_p(File.dirname(file))
    FileUtils.cp(fixture, file)
  end
end
