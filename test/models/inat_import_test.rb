# frozen_string_literal: true

require "test_helper"

class InatImportTest < ActiveSupport::TestCase
  def test_total_expected_time_tabula_rasa
    zero_out_prior_import_records
    import = inat_imports(:rolf_inat_import)

    assert_equal(
      import.total_importables * InatImport::BASE_AVG_IMPORT_SECONDS,
      import.total_expected_time,
      "If nobody has imported anhy iNat obss, " \
      "total expected time for the 1st import should be the system default"
    )
  end

  def zero_out_prior_import_records
    prior_imports = InatImport.where.not(total_imported_count: nil)
    prior_imports.each do |import|
      import.update(total_imported_count: nil, total_seconds: nil)
    end
  end

  def test_total_expected_time_user_without_prior_imports
    import = inat_imports(:rolf_inat_import)

    assert_equal(
      import.total_importables *
        InatImport.sum(:total_seconds) / InatImport.sum(:total_imported_count),
      import.total_expected_time
    )
  end

  def test_total_expected_time_user_with_prior_imports
    import = inat_imports(:roy_inat_import)

    assert_equal(import.total_importables * import.initial_avg_import_seconds,
                 import.total_expected_time)
  end

  # A user's import history is summed across ALL their import records, not
  # read off a single one, so it survives the move to one record per import.
  def test_personal_avg_sums_across_a_users_imports
    user = users(:rolf)
    InatImport.where(user: user).
      update_all(total_imported_count: nil, total_seconds: nil)
    InatImport.create!(user: user, total_imported_count: 2, total_seconds: 20)
    InatImport.create!(user: user, total_imported_count: 3, total_seconds: 40)

    import = InatImport.new(user: user)

    # (20 + 40) seconds / (2 + 3) observations = 12 seconds per observation
    assert_equal(12, import.initial_avg_import_seconds)
  end

  def test_estimated_remaining_time_extrapolates_from_progress
    import = inat_imports(:rolf_inat_import)
    import.update!(state: "Importing", total_importables: 20,
                   imported_count: 5, started_at: 10.seconds.ago,
                   ended_at: nil)

    # ~5 obs in ~10s ≈ 2 s/obs; 15 remaining ≈ 30s.
    assert_in_delta(30, import.estimated_remaining_time, 4,
                    "ETA should extrapolate from the observed rate")
  end

  def test_estimated_remaining_time_before_any_imported
    import = inat_imports(:rolf_inat_import)
    import.update!(state: "Importing", total_importables: 10,
                   imported_count: 0, started_at: Time.zone.now,
                   ended_at: nil)

    assert_equal(import.total_expected_time, import.estimated_remaining_time,
                 "Before any obs imported, fall back to the up-front estimate")
  end

  def test_estimated_remaining_time_zero_when_done
    assert_equal(0, inat_imports(:lone_wolf_import).estimated_remaining_time)
  end

  def test_adequate_constraints
    assert(
      inat_imports(:rolf_inat_import).adequate_constraints?,
      "iNat username adequately constrains imports"
    )

    assert_not(
      inat_imports(:ollie_inat_import).adequate_constraints?,
      "Import without an iNat username does not adequately constrain imports"
    )

    # Not-own superimporter: needs username OR specific IDs
    superimporter_import = inat_imports(:dick_inat_import)

    not_own_with_username_import = superimporter_import.dup.tap do |i|
      i.import_others = true
      i.inat_username = "some_user"
      i.inat_ids = ""
    end
    assert(not_own_with_username_import.adequate_constraints?,
           "Not-own import with username should be adequately constrained")

    not_own_with_ids_import = superimporter_import.dup.tap do |i|
      i.import_others = true
      i.inat_username = ""
      i.inat_ids = "123,456"
    end
    assert(not_own_with_ids_import.adequate_constraints?,
           "Not-own import with specific IDs should be adequately constrained")

    not_own_no_constraints_import = superimporter_import.dup.tap do |i|
      i.import_others = true
      i.inat_username = ""
      i.inat_ids = ""
    end
    assert_not(not_own_no_constraints_import.adequate_constraints?,
               "Not-own import with no username or IDs should " \
               "not be adequately constrained")
  end

  def test_super_importer
    assert(
      InatImport.super_importer?(users(:dick)),
      "Dick is a super importer"
    )
    assert_not(
      InatImport.super_importer?(users(:roy)),
      "Roy is not a super importer"
    )
  end

  def test_add_response_error_with_exception
    import = inat_imports(:rolf_inat_import)
    error = StandardError.new("Exception error message")

    import.add_response_error(error)
    import.reload

    assert_match(/Exception error message/, import.response_errors)
  end

  def test_add_response_error_with_rest_client_response
    import = inat_imports(:rolf_inat_import)
    net_res = Net::HTTPBadRequest.new("1.1", 400, "Bad Request")
    req = RestClient::Request.new(method: :get, url: "http://example.com")
    response = RestClient::Response.create("iNat API error", net_res, req)

    import.add_response_error(response)
    import.reload

    assert_match(/iNat API error/, import.response_errors,
                 "RestClient::Response body should be added to response_errors")
  end

  def test_response_errors_initialized_on_new_instance
    import = InatImport.new(user: users(:rolf))

    assert_not_nil(import.response_errors,
                   "response_errors should be initialized to empty string")
    assert_equal("", import.response_errors,
                 "response_errors should be initialized to empty string")
  end

  def test_stuck_when_importing_and_stale
    import = inat_imports(:katrina_inat_import)
    import.update_column(:updated_at,
                         InatImport::STUCK_THRESHOLD.ago - 1.second)

    assert(import.stuck?,
           "Import in Importing state with stale updated_at should be stuck")
  end

  def test_not_stuck_when_importing_but_recent
    import = inat_imports(:katrina_inat_import)
    import.update_column(:updated_at, Time.zone.now)

    assert_not(import.stuck?,
               "Import with recent updated_at should not be stuck")
  end

  def test_not_stuck_when_done
    import = inat_imports(:lone_wolf_import)

    assert_not(import.stuck?, "Done import should not be stuck")
  end

  def test_abandoned_scope
    stale = inat_imports(:rolf_inat_import)
    stale.update!(state: "Authorizing")
    stale.update_column(:updated_at,
                        InatImport::ABANDONED_THRESHOLD.ago - 1.second)
    recent = inat_imports(:mary_inat_import)
    recent.update!(state: "Authenticating")

    abandoned = InatImport.abandoned
    assert_includes(abandoned, stale,
                    "Stale Authorizing import should be abandoned")
    assert_not_includes(abandoned, recent,
                        "Recent Authenticating import should not be abandoned")
    assert_not_includes(abandoned, inat_imports(:katrina_inat_import),
                        "Importing import is stuck, not abandoned")
  end

  def test_ignored_total_count
    import = inat_imports(:rolf_inat_import)
    import.update!(
      ignored_not_importable_count: 3,
      ignored_date_missing_count: 2,
      ignored_already_imported_count: 1
    )

    assert_equal(6, import.ignored_total_count)
  end

  def test_ignored_total_count_with_nils
    import = inat_imports(:rolf_inat_import)

    assert_equal(0, import.ignored_total_count,
                 "nil counts should sum as 0")
  end

  def test_add_response_error_without_prior_errors
    import = InatImport.new(user: users(:rolf))
    import.save!

    import.add_response_error("Test error message")

    assert_match(/Test error message/, import.response_errors,
                 "Error message should be added to response_errors")
  end

  def test_new_instance_initializes_id_arrays
    import = InatImport.new(user: users(:rolf))

    assert_equal([], import.date_missing_inat_ids)
    assert_equal([], import.license_added_inat_ids)
  end

  def test_add_ignored_obs_date_missing_increments_count_and_appends_id
    import = inat_imports(:rolf_inat_import)

    import.add_ignored_obs(:date_missing, inat_id: 42)
    import.reload

    assert_equal(1, import.ignored_date_missing_count)
    assert_equal([42], import.date_missing_inat_ids)
  end

  def test_add_ignored_obs_date_missing_nil_id_still_increments
    import = inat_imports(:rolf_inat_import)

    import.add_ignored_obs(:date_missing, inat_id: nil)
    import.reload

    assert_equal(1, import.ignored_date_missing_count)
    assert_equal([], import.date_missing_inat_ids)
  end

  def test_add_ignored_obs_date_missing_accumulates_multiple_ids
    import = inat_imports(:rolf_inat_import)

    import.add_ignored_obs(:date_missing, inat_id: 10)
    import.add_ignored_obs(:date_missing, inat_id: 20)
    import.reload

    assert_equal(2, import.ignored_date_missing_count)
    assert_equal([10, 20], import.date_missing_inat_ids)
  end

  def test_add_ignored_obs_unknown_reason_raises
    import = inat_imports(:rolf_inat_import)

    assert_raises(ArgumentError) do
      import.add_ignored_obs(:bogus_reason)
    end
  end

  def test_add_license_added_obs_appends_id
    import = inat_imports(:rolf_inat_import)

    import.add_license_added_obs(inat_id: 99)
    import.reload

    assert_equal([99], import.license_added_inat_ids)
  end

  def test_add_license_added_obs_accumulates_multiple_ids
    import = inat_imports(:rolf_inat_import)

    import.add_license_added_obs(inat_id: 11)
    import.add_license_added_obs(inat_id: 22)
    import.reload

    assert_equal([11, 22], import.license_added_inat_ids)
  end

  def test_reached_import_cap_false_below_cap
    import = inat_imports(:rolf_inat_import)
    import.update_columns(imported_count: InatImport::MAX_IMPORTABLE - 1)

    assert_not(import.reached_import_cap?)
  end

  def test_reached_import_cap_true_at_cap
    import = inat_imports(:rolf_inat_import)
    import.update_columns(imported_count: InatImport::MAX_IMPORTABLE)

    assert(import.reached_import_cap?)
  end

  def test_reached_import_cap_true_above_cap
    import = inat_imports(:rolf_inat_import)
    import.update_columns(imported_count: InatImport::MAX_IMPORTABLE + 1)

    assert(import.reached_import_cap?)
  end

  def test_reached_import_cap_false_when_nil
    import = inat_imports(:rolf_inat_import)
    import.update_columns(imported_count: nil)

    assert_not(import.reached_import_cap?)
  end
end
