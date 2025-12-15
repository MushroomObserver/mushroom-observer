# frozen_string_literal: true

require("test_helper")

class FieldSlipJobTest < ActiveJob::TestCase
  include GeneralExtensions

  def setup
    super
    # Use worker-specific directory for parallel testing
    worker_suffix = database_worker_number ? "-#{database_worker_number}" : ""
    @pdf_dir = "public/shared#{worker_suffix}"

    # Save original constant and set worker-specific one
    @original_pdf_dir = FieldSlipJobTracker::PDF_DIR
    FieldSlipJobTracker.send(:remove_const, :PDF_DIR)
    FieldSlipJobTracker.const_set(:PDF_DIR, @pdf_dir)
  end

  def teardown
    # Restore original constant
    FieldSlipJobTracker.send(:remove_const, :PDF_DIR)
    FieldSlipJobTracker.const_set(:PDF_DIR, @original_pdf_dir)

    # Clean up any generated PDFs
    FileUtils.rm_rf(@pdf_dir) if @pdf_dir
    super
  end

  def test_perform
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
