# frozen_string_literal: true

require("test_helper")

class InatObservationImporterTest < UnitTestCase
  # update_timings keeps a cumulative moving average (CMA) of per-observation
  # import time for the current job. After obs #1 with elapsed T: avg = T.
  # After obs #2 with elapsed S: avg = (T + S) / 2.
  def test_update_timings_cumulative_moving_average
    import = inat_imports(:rolf_inat_import)
    importer = ::Inat::ObservationImporter.new(import, import.user)

    # Simulate first obs taking ~10 seconds
    import.update(avg_import_time: 15.0, imported_count: 1,
                  last_obs_start: 10.seconds.ago)
    importer.send(:update_timings)
    import.reload
    assert_in_delta(10, import.avg_import_time, 1,
                    "After first obs, avg_import_time should equal elapsed " \
                    "time (CMA with count=1 collapses to the raw value)")

    # Simulate second obs taking ~20 seconds; mean of [10, 20] = 15
    import.update(imported_count: 2, last_obs_start: 20.seconds.ago)
    importer.send(:update_timings)
    import.reload
    assert_in_delta(15, import.avg_import_time, 1,
                    "After second obs, avg_import_time should be the mean " \
                    "of both elapsed times")
  end

  # accumulate_counts also threads a builder's created_image_ids up onto
  # the importer -- InatImportJob reads this after each batch to enqueue
  # one TransferImagesJob per batch (see #4791's target design).
  def test_accumulate_counts_collects_created_image_ids
    import = inat_imports(:rolf_inat_import)
    importer = ::Inat::ObservationImporter.new(import, import.user)
    fake_builder = Object.new
    fake_builder.define_singleton_method(:unlicensed_obs) { 0 }
    fake_builder.define_singleton_method(:skipped_images) { 0 }
    fake_builder.define_singleton_method(:created_image_ids) { [123, 456] }

    importer.send(:accumulate_counts, fake_builder)

    assert_equal([123, 456], importer.image_ids)
  end

  # skip_unlicensed_other? (#4828): create_skeletons on (the default) marks
  # the obs for a skeleton build instead of skipping it.
  def test_skip_unlicensed_other_builds_skeleton_when_create_skeletons_on
    import = inat_imports(:dick_inat_import)
    import.update(import_others: true, create_skeletons: true)
    importer = ::Inat::ObservationImporter.new(import, import.user)
    importer.instance_variable_set(:@inat_obs, unlicensed_inat_obs)

    assert_not(importer.send(:skip_unlicensed_other?),
               "Should not skip when create_skeletons is on")
    assert(importer.instance_variable_get(:@skeleton),
           "Should mark the obs for a skeleton build")
    assert_equal(0, import.reload.ignored_unlicensed_count)
  end

  # create_skeletons off restores the original skip-entirely behavior.
  def test_skip_unlicensed_other_skips_when_create_skeletons_off
    import = inat_imports(:dick_inat_import)
    import.update(import_others: true, create_skeletons: false)
    importer = ::Inat::ObservationImporter.new(import, import.user)
    importer.instance_variable_set(:@inat_obs, unlicensed_inat_obs)

    assert(importer.send(:skip_unlicensed_other?),
           "Should skip when create_skeletons is off")
    assert_not(importer.instance_variable_get(:@skeleton))
    assert_equal(1, import.reload.ignored_unlicensed_count)
  end

  def test_build_observation_builder_picks_skeleton_class
    import = inat_imports(:dick_inat_import)
    import.update(import_others: true)
    importer = ::Inat::ObservationImporter.new(import, import.user)
    importer.instance_variable_set(:@inat_obs, unlicensed_inat_obs)
    importer.instance_variable_set(:@skeleton, true)

    assert_instance_of(Inat::SkeletonObservationBuilder,
                       importer.send(:build_observation_builder))
  end

  def test_build_observation_builder_picks_full_class_by_default
    import = inat_imports(:rolf_inat_import)
    importer = ::Inat::ObservationImporter.new(import, import.user)
    importer.instance_variable_set(:@inat_obs, unlicensed_inat_obs)

    assert_instance_of(Inat::MoObservationBuilder,
                       importer.send(:build_observation_builder))
  end

  # finalize_import's record_skeleton_import (#4828): tracks the skeleton
  # count and observation id so Inat::ImportDigest can exclude it.
  def test_record_skeleton_import
    import = inat_imports(:rolf_inat_import)
    obs = observations(:coprinus_comatus_obs)
    importer = ::Inat::ObservationImporter.new(import, import.user)
    importer.instance_variable_set(:@observation, obs)

    importer.send(:record_skeleton_import)

    import.reload
    assert_equal(1, import.skeleton_imported_count)
    assert_equal([obs.id], import.skeleton_observation_ids)
  end

  def unlicensed_inat_obs
    ::Inat::Obs.new({ id: 999_999, license_code: nil }.to_json)
  end

  def test_canceled
    import = inat_imports(:ollie_inat_import)
    assert(import.canceled?, "Test needs a canceled InatImport fixture")
    user = import.user
    mock_inat_response = File.read("test/inat/calostoma_lutescens.txt")
    page = JSON.parse(mock_inat_response)

    importer = ::Inat::ObservationImporter.new(import, user)
    assert_no_difference(
      "Observation.count",
      "ObservationImporter should stop importing observations after " \
      "user cancels the Import"
    ) do
      importer.import_page(page)
    end
  end
end
