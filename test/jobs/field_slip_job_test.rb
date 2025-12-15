# frozen_string_literal: true

require("test_helper")

class FieldSlipJobTest < ActiveJob::TestCase
  include GeneralExtensions

  def setup
    super
    # Use worker-specific directory for parallel testing
    worker_suffix = database_worker_number ? "-#{database_worker_number}" : ""
    @pdf_dir = "public/shared#{worker_suffix}"
  end

  def teardown
    # Clean up any generated PDFs
    FileUtils.rm_rf(@pdf_dir) if @pdf_dir
    super
  end

  def test_perform
    job = FieldSlipJob.new
    tracker = field_slip_job_trackers(:fsjt_page_two)
    FieldSlipJobTracker.stub(:pdf_directory, @pdf_dir) do
      job.perform(tracker.id)
      assert(File.exist?(tracker.filepath))
      File.delete(tracker.filepath)
    end
  end

  def test_performs_with_one_per_page
    job = FieldSlipJob.new
    tracker = field_slip_job_trackers(:fsjt_one_per_page)
    FieldSlipJobTracker.stub(:pdf_directory, @pdf_dir) do
      job.perform(tracker.id)
      assert(File.exist?(tracker.filepath))
      File.delete(tracker.filepath)
    end
  end

  def test_deletes_old_trackers
    old_tracker_id = field_slip_job_trackers(:fsjt_old).id
    job = FieldSlipJob.new
    tracker = field_slip_job_trackers(:fsjt_page_two)
    FieldSlipJobTracker.stub(:pdf_directory, @pdf_dir) do
      job.perform(tracker.id)
      File.delete(tracker.filepath)
      assert_nil(FieldSlipJobTracker.find_by(id: old_tracker_id))
    end
  end

  def test_deletes_old_tracker_files
    FieldSlipJobTracker.stub(:pdf_directory, @pdf_dir) do
      old_tracker = field_slip_job_trackers(:fsjt_old)
      old_filepath = old_tracker.filepath
      FileUtils.touch(old_filepath)
      job = FieldSlipJob.new
      tracker = field_slip_job_trackers(:fsjt_page_two)
      job.perform(tracker.id)
      File.delete(tracker.filepath)
      assert_not(File.exist?(old_filepath))
    end
  end
end
