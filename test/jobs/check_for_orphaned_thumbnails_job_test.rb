# frozen_string_literal: true

require("test_helper")

class CheckForOrphanedThumbnailsJobTest < ActiveJob::TestCase
  DANGLING_ID = 999_999_999

  def test_nulls_orphaned_thumb_image_id
    obs = observations(:coprinus_comatus_obs)
    obs.update_column(:thumb_image_id, DANGLING_ID)

    CheckForOrphanedThumbnailsJob.perform_now(verbose: true)

    assert_nil(obs.reload.thumb_image_id)
  end

  def test_dry_run_reports_without_modifying
    obs = observations(:coprinus_comatus_obs)
    obs.update_column(:thumb_image_id, DANGLING_ID)

    CheckForOrphanedThumbnailsJob.perform_now(dry_run: true)

    assert_equal(DANGLING_ID, obs.reload.thumb_image_id)
  end

  def test_perform_runs_end_to_end_without_error
    CheckForOrphanedThumbnailsJob.perform_now(verbose: true)
  end
end
