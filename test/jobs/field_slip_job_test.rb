# frozen_string_literal: true

require "test_helper"

class FieldSlipJobTest < ActiveJob::TestCase
  test "it should perform" do
    job = FieldSlipJob.new
    tracker = field_slip_job_trackers(:fsjt_page_two)
    job.perform(projects(:eol_project).id, tracker.id)
    assert(File.exist?(tracker.filepath))
    File.delete(tracker.filepath)
  end

  test "it should delete old trackers" do
    old_tracker_id = field_slip_job_trackers(:fsjt_old).id
    job = FieldSlipJob.new
    tracker = field_slip_job_trackers(:fsjt_page_two)
    job.perform(projects(:eol_project).id, tracker.id)
    File.delete(tracker.filepath)
    assert_nil(FieldSlipJobTracker.find_by(id: old_tracker_id))
  end

  test "it should delete old tracker files" do
    old_filepath = field_slip_job_trackers(:fsjt_old).filepath
    FileUtils.touch(old_filepath)
    job = FieldSlipJob.new
    tracker = field_slip_job_trackers(:fsjt_page_two)
    job.perform(projects(:eol_project).id, tracker.id)
    File.delete(tracker.filepath)
    assert_not(File.exist?(old_filepath))
  end
end
