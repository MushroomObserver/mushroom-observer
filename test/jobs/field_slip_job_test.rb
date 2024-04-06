# frozen_string_literal: true

require "test_helper"

class FieldSlipJobTest < ActiveJob::TestCase
  test "it should perform" do
    job = FieldSlipJob.new
    tracker = field_slip_job_trackers(:fsjt_one)
    job.perform(projects(:eol_project).id, tracker.id)
    assert(File.exist?(tracker.filepath))
    File.delete(tracker.filepath)
  end
end
