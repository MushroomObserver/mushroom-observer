# frozen_string_literal: true

require("test_helper")

# See test/models/image/processor/verifier_test.rb for the transfer-time
# work-list path. This is the incremental reconciliation pass (#4791's
# target design, part 4): it re-checks already-transferred images past the
# ImageGapCheckpoint against their specific derived-size paths, and
# regenerates any missing ones.
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
    seed_remote(1, image, %w[thumb 320 640 960 1280])
    seed_remote(2, image, %w[thumb 320 640])

    assert_empty(run_detector_for(image)[:gaps])
  end

  # A missing original is expected (originals are archived off the server),
  # not a gap -- only the five derived sizes are checked.
  def test_missing_original_is_not_a_gap
    image = images(:turned_over_image)
    image.update_columns(transferred: true)
    seed_remote(1, image, %w[thumb 320 640 960 1280]) # all derived, no orig
    seed_remote(2, image, %w[thumb 320 640])

    assert_empty(run_detector_for(image)[:gaps],
                 "a missing original must not be reported as a gap")
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
    seed_remote(1, image, %w[thumb 320 640 1280]) # "960" gap, no orig anywhere
    seed_remote(2, image, %w[thumb 320 640])

    result = run_detector_for(image)

    assert_includes(result[:unregenerable], image.id)
    assert_empty(result[:regenerated])
  end

  def test_only_attempts_regeneration_once_per_image_per_run
    image = images(:turned_over_image)
    image.update_columns(transferred: true)
    # Missing on both remote1 (960) and remote2 (640) -- two gaps, one image.
    seed_remote(1, image, %w[thumb 320 640 1280])
    seed_remote(2, image, %w[thumb 320])

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

  # The default (scheduled) scope only examines transferred images.
  def test_default_scope_only_includes_transferred_images
    ImageGapCheckpoint.reset_to(0)
    transferred_image = images(:turned_over_image)
    transferred_image.update_columns(transferred: true)
    seed_remote(1, transferred_image, %w[thumb 320 640 1280]) # "960" missing
    seed_remote(2, transferred_image, %w[thumb 320 640])

    untransferred_image = images(:in_situ_image)
    untransferred_image.update_columns(transferred: false)

    gap_ids = Image::Processor.detect_gaps[:gaps].map(&:first)

    assert_includes(gap_ids, transferred_image.id)
    assert_not_includes(gap_ids, untransferred_image.id)
  end

  # Images at or below the checkpoint are never re-examined.
  def test_default_scope_excludes_images_at_or_below_the_checkpoint
    image = images(:turned_over_image)
    image.update_columns(transferred: true)
    seed_remote(1, image, %w[thumb 320 640 1280]) # "960" would be a gap
    seed_remote(2, image, %w[thumb 320 640])

    ImageGapCheckpoint.reset_to(Image.maximum(:id))

    assert_empty(Image::Processor.detect_gaps[:gaps])
  end

  # A clean default run advances the mark to the highest id examined.
  def test_clean_run_advances_checkpoint_to_max_id
    detector = Image::Processor::GapDetector.new
    ImageGapCheckpoint.reset_to(0)
    image = images(:turned_over_image)

    detector.send(:advance_checkpoint, Image.where(id: image.id))

    assert_equal(image.id, ImageGapCheckpoint.last_verified_image_id)
  end

  # An unrepairable image holds the mark below it, so it keeps being
  # re-checked (and re-alerted) next run.
  def test_checkpoint_holds_below_the_lowest_unregenerable_image
    detector = Image::Processor::GapDetector.new
    detector.instance_variable_set(:@unregenerable, [70, 30, 50])
    ImageGapCheckpoint.reset_to(0)

    detector.send(:advance_checkpoint,
                  Image.where(id: images(:turned_over_image).id))

    assert_equal(29, ImageGapCheckpoint.last_verified_image_id)
  end

  def test_ssh_sizes_shells_out_with_targeted_paths
    detector = Image::Processor::GapDetector.new
    captured = nil
    Open3.stub(:capture3, lambda { |*args|
      captured = args
      ["", "", stub_status(true)]
    }) do
      detector.send(:ssh_sizes, :ssh_server, "mo@example.test:/data/mo",
                    ["thumb/1.jpg", "320/1.jpg"])
    end

    assert_equal(
      ["ssh", "mo@example.test", "find", "-L",
       "/data/mo/thumb/1.jpg", "/data/mo/320/1.jpg",
       "-maxdepth", "0", "-printf", "'%p\\t%s\\n'"],
      captured
    )
  end

  def test_ssh_sizes_parses_output_and_strips_root
    detector = Image::Processor::GapDetector.new
    output = "/data/mo/thumb/1.jpg\t456\n/data/mo/320/1.jpg\t789\n"

    Open3.stub(:capture3, [output, "", stub_status(true)]) do
      result = detector.send(:ssh_sizes, :ssh_server,
                             "mo@example.test:/data/mo",
                             ["thumb/1.jpg", "320/1.jpg"])
      assert_equal({ "thumb/1.jpg" => 456, "320/1.jpg" => 789 }, result)
    end
  end

  # A find exit-status failure whose stderr is only "No such file" is an
  # expected missing path, not a connection failure -- no log line.
  def test_ssh_sizes_logs_only_on_real_failure
    messages = []
    detector = Image::Processor::GapDetector.new { |msg| messages << msg }

    Open3.stub(:capture3, ["", "Permission denied", stub_status(false)]) do
      detector.send(:ssh_sizes, :ssh_server, "mo@example.test:/data/mo",
                    ["thumb/1.jpg"])
    end

    assert(messages.any? do |msg|
      msg.include?("Failed to check") && msg.include?("Permission denied")
    end)
  end

  def test_remote_sizes_for_unknown_type_raises
    detector = Image::Processor::GapDetector.new
    detector.instance_variable_set(:@image_server_data,
                                   { weird: { type: "ftp" } })
    assert_raises(RuntimeError) do
      detector.send(:remote_sizes_for, :weird, ["thumb/1.jpg"])
    end
  end

  private

  def stub_status(success)
    status = Object.new
    status.define_singleton_method(:success?) { success }
    status
  end

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
