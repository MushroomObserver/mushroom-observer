# frozen_string_literal: true

require("test_helper")

class InatImportRecoveryJobTest < ActiveJob::TestCase
  def test_marks_stuck_import_as_done
    import = inat_imports(:katrina_inat_import)
    import.update_column(:updated_at,
                         InatImport::STUCK_THRESHOLD.ago - 1.second)

    InatImportRecoveryJob.perform_now

    import.reload
    assert_equal("Done", import.state,
                 "Stuck import should be marked Done")
    assert_not_nil(import.ended_at,
                   "Stuck import should have ended_at set")
    assert_match(/the import may have crashed/, import.response_errors,
                 "Stuck import should have crash error in response_errors")
  end

  def test_does_not_touch_recently_active_import
    import = inat_imports(:katrina_inat_import)
    import.update_column(:updated_at, Time.zone.now)

    InatImportRecoveryJob.perform_now

    import.reload
    assert_equal("Importing", import.state,
                 "Recently active import should not be touched")
  end

  def test_does_not_touch_done_import
    import = inat_imports(:lone_wolf_import)
    original_errors = import.response_errors

    InatImportRecoveryJob.perform_now

    import.reload
    assert_equal(original_errors, import.response_errors,
                 "Done import should not be modified")
  end
end
