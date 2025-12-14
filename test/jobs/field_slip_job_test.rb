# frozen_string_literal: true

require("test_helper")

class FieldSlipJobTest < ActiveJob::TestCase
  def test_it_should_perform
    job = FieldSlipJob.new
    tracker = field_slip_job_trackers(:fsjt_page_two)
    job.perform(tracker.id)
    assert(File.exist?(tracker.filepath))
    File.delete(tracker.filepath)
  end

  def test_performs_with_one_per_page
    job = FieldSlipJob.new
    tracker = field_slip_job_trackers(:fsjt_one_per_page)
    job.perform(tracker.id)
    assert(File.exist?(tracker.filepath))
    File.delete(tracker.filepath)
  end

  def test_deletes_old_trackers
    old_tracker_id = field_slip_job_trackers(:fsjt_old).id
    job = FieldSlipJob.new
    tracker = field_slip_job_trackers(:fsjt_page_two)
    job.perform(tracker.id)
    File.delete(tracker.filepath)
    assert_nil(FieldSlipJobTracker.find_by(id: old_tracker_id))
  end

  def test_deletes_old_tracker_files
    old_filepath = field_slip_job_trackers(:fsjt_old).filepath
    FileUtils.touch(old_filepath)
    job = FieldSlipJob.new
    tracker = field_slip_job_trackers(:fsjt_page_two)
    job.perform(tracker.id)
    File.delete(tracker.filepath)
    assert_not(File.exist?(old_filepath))
  end
end
