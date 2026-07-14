# frozen_string_literal: true

require("test_helper")

# See test/models/image/processor/verifier_test.rb for the per-image,
# per-file work-list-scoped path (the routine transfer). This is the
# occasional full-listing reconciliation pass (#4791's target design,
# part 4) -- it catches drift on already-transferred images once their
# local copies are gone, which Verifier structurally can't see.
class Image::Processor::GapDetectorTest < UnitTestCase
  SUBDIRS = Image::URL::SUBDIRECTORIES.values.freeze

  def local_root
    if (worker_num = database_worker_number)
      Rails.public_path.join("test_images-#{worker_num}").to_s
    else
      Rails.public_path.join("test_images").to_s
    end
  end

  def remote_server_path(num)
    if (worker_num = database_worker_number)
      Rails.public_path.join("test_server#{num}-#{worker_num}").to_s
    else
      Rails.public_path.join("test_server#{num}").to_s
    end
  end

  def setup
    [local_root, remote_server_path(1), remote_server_path(2)].each do |root|
      FileUtils.rm_rf(root)
      SUBDIRS.each { |dir| FileUtils.mkpath("#{root}/#{dir}") }
    end
    super
  end

  def teardown
    [local_root, remote_server_path(1), remote_server_path(2)].each do |root|
      FileUtils.rm_rf(root)
    end
    super
  end

  def test_no_gaps_when_transferred_image_is_fully_present_remotely
    image = images(:turned_over_image)
    image.update_columns(transferred: true)
    seed_remote(1, image, %w[thumb 320 640 960 1280 orig])
    seed_remote(2, image, %w[thumb 320 640])

    result = run_detector_for(image)

    assert_empty(result[:gaps])
  end

  # The default scope (Image.where(transferred: true)) is what actually
  # excludes still-processing images -- find_gaps itself doesn't filter
  # by transferred status, it trusts whatever scope it's given. So this
  # exercises Image::Processor.detect_gaps with no explicit override.
  def test_default_scope_only_includes_transferred_images
    transferred_image = images(:turned_over_image)
    transferred_image.update_columns(transferred: true)
    seed_remote(1, transferred_image, %w[thumb 320 640 1280]) # "960" missing
    seed_remote(2, transferred_image, %w[thumb 320 640])

    untransferred_image = images(:in_situ_image)
    untransferred_image.update_columns(transferred: false)
    # Nothing seeded for this one -- would look like a total gap if it
    # were in scope, but it's still mid-processing, Verifier's concern.

    result = Image::Processor.detect_gaps

    gap_ids = result[:gaps].map(&:first)
    assert_includes(gap_ids, transferred_image.id)
    assert_not_includes(gap_ids, untransferred_image.id)
  end

  def test_finds_and_regenerates_a_gap_from_the_original
    image = images(:turned_over_image)
    image.update_columns(transferred: true)
    seed_remote(1, image, %w[thumb 320 640 1280]) # "960" missing
    seed_remote(2, image, %w[thumb 320 640])
    # The original, so regeneration has a source to work from.
    File.binwrite("#{remote_server_path(1)}/orig/#{image.id}.jpg",
                  valid_jpg_bytes)

    result = run_detector_for(image)

    assert_includes(result[:gaps].map(&:first), image.id)
    assert_includes(result[:regenerated], image.id)
    assert_empty(result[:unregenerable])
    assert_path_exists("#{remote_server_path(1)}/960/#{image.id}.jpg",
                       "the missing size should have been regenerated " \
                       "and re-transferred")
  end

  def test_records_unregenerable_when_no_source_is_available_anywhere
    image = images(:turned_over_image)
    image.update_columns(transferred: true)
    seed_remote(1, image, %w[thumb 320 640 1280]) # "960" AND "orig" missing
    seed_remote(2, image, %w[thumb 320 640])

    result = run_detector_for(image)

    assert_includes(result[:unregenerable], image.id)
    assert_empty(result[:regenerated])
  end

  def test_only_attempts_regeneration_once_per_image_per_run
    image = images(:turned_over_image)
    image.update_columns(transferred: true)
    # Missing on both remote1 (960) and remote2 (640) -- two gaps, one image.
    seed_remote(1, image, %w[thumb 320 640 1280 orig]) # "960" missing
    seed_remote(2, image, %w[thumb 320])               # "640" missing

    call_count = 0
    detector = Image::Processor::GapDetector.new
    detector.stub(:regenerate_and_retransfer, lambda { |_image|
      call_count += 1
      raise("boom")
    }) do
      result = detector.run(Image.where(id: image.id))
      assert_equal(2, result[:gaps].size, "both gaps should be recorded")
    end

    assert_equal(1, call_count,
                 "regeneration should only be attempted once per image")
  end

  private

  def run_detector_for(image)
    Image::Processor::GapDetector.new.run(Image.where(id: image.id))
  end

  def valid_jpg_bytes
    Rails.root.join("test/images/sticky.jpg").binread
  end

  def seed_remote(server_num, image, subdirs)
    root = remote_server_path(server_num)
    subdirs.each do |dir|
      File.write("#{root}/#{dir}/#{image.id}.jpg", "remote-#{dir}")
    end
  end
end
