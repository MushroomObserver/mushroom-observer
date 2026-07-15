# frozen_string_literal: true

require("test_helper")

# See test/classes/image_script_test.rb for the equivalent shell-script
# coverage this fixture data is drawn from, GitHub issue #4791 for why
# this is a work-list-scoped port (per-image, per-file checks) driven by
# an explicit list of images rather than a directory-listing scan of the
# old script, and test/jobs/transfer_images_job_test.rb /
# test/models/image/processor/gap_detector_test.rb for the event-driven
# job and the occasional-reconciliation piece that call this.
class Image::Processor::VerifierTest < UnitTestCase
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

  # A mismatch gets uploaded, but the image isn't trusted as complete on
  # the same run that just fixed it -- deliberate (see Verifier's
  # all_synced? comment): a freshly-uploaded file isn't re-verified until
  # the next run's fresh remote check.
  def test_uploads_mismatch_but_does_not_yet_mark_transferred
    image = images(:turned_over_image)
    seed_locally_complete(image)
    seed_remote(1, image, %w[thumb 320 640 1280 orig])
    seed_remote(2, image, %w[thumb 320 640])

    result = Image::Processor.transfer_images([image.id])

    assert_includes(result[:uploaded],
                    [image.id, :remote1, "960/#{image.id}.jpg"])
    assert_not(image.reload.transferred)
    assert_empty(result[:completed])
    assert_path_exists("#{local_root}/960/#{image.id}.jpg",
                       "not deleted -- upload isn't verified yet this run")
  end

  # Nothing to upload from the start (already fully synced) -- completes
  # in one run: marks transferred and deletes local copies not configured
  # to stay local.
  def test_marks_transferred_and_deletes_local_once_fully_synced
    image = images(:turned_over_image)
    seed_locally_complete(image)
    seed_remote(1, image, %w[thumb 320 640 960 1280 orig])
    seed_remote(2, image, %w[thumb 320 640])

    result = Image::Processor.transfer_images([image.id])

    assert_empty(result[:uploaded])
    assert_includes(result[:completed], image.id)
    assert(image.reload.transferred)
    # thumbnail/small (thumb/320) are in MO.keep_these_image_sizes_local --
    # never deleted, even though fully synced everywhere relevant.
    assert_path_exists("#{local_root}/thumb/#{image.id}.jpg")
    assert_path_exists("#{local_root}/320/#{image.id}.jpg")
    %w[640 960 1280 orig].each do |dir|
      assert_not(File.exist?("#{local_root}/#{dir}/#{image.id}.jpg"),
                 "#{dir} should be deleted -- fully synced and not kept local")
    end
  end

  # Regression (#4751): no :write-configured remote (development's
  # :mycolab) means @image_servers is empty -- must not vacuously treat
  # that as "fully synced".
  def test_does_not_delete_or_mark_transferred_when_no_remote_configured
    image = images(:turned_over_image)
    seed_locally_complete(image)
    local_only_data = {
      local: { type: "file", path: local_root, subdirs: SUBDIRS }
    }

    result = Image::Processor.stub(:image_server_data, local_only_data) do
      Image::Processor.transfer_images([image.id])
    end

    assert_empty(result[:uploaded])
    assert_empty(result[:completed])
    assert_empty(result[:deleted])
    assert_not(image.reload.transferred)
    SUBDIRS.each do |dir|
      assert_path_exists(
        "#{local_root}/#{dir}/#{image.id}.jpg",
        "#{dir} should not be deleted -- nothing confirms it's transferred"
      )
    end
  end

  # A local file that hasn't been generated yet (still mid-#process) means
  # nothing to verify or transfer until it exists -- this is the normal
  # in-progress window between upload and job completion, exactly the
  # window #4791's blind rsync used to race.
  def test_skips_image_still_being_processed
    image = images(:turned_over_image)
    image.update_columns(transferred: false)
    # Only "orig" exists locally -- the rest haven't been generated yet.
    File.write("#{local_root}/orig/#{image.id}.jpg", "orig-only")

    result = Image::Processor.transfer_images([image.id])

    assert_empty(result[:uploaded])
    assert_empty(result[:completed])
    assert_not(image.reload.transferred)
    assert_path_exists("#{local_root}/orig/#{image.id}.jpg",
                       "not deleted -- still mid-processing")
  end

  # A non-jpg original also expects its raw orig/<id>.<ext> file (in
  # addition to the converted orig/<id>.jpg) to be present and synced.
  def test_non_jpg_original_checks_the_raw_file_too
    image = images(:turned_over_image)
    image.stub(:original_extension, "tiff") do
      seed_locally_complete(image)
      File.write("#{local_root}/orig/#{image.id}.tiff", "raw-original")
      seed_remote(1, image, %w[thumb 320 640 960 1280 orig])
      File.write("#{remote_server_path(1)}/orig/#{image.id}.tiff",
                 "raw-original")
      seed_remote(2, image, %w[thumb 320 640])

      result = Image::Processor.transfer_images([image.id])
      assert_includes(result[:completed], image.id)
    end
  end

  # Regression test for a Copilot finding on PR #4751: a failed upload
  # must not be recorded in the summary as if it succeeded.
  def test_transfer_does_not_record_failed_uploads_as_successful
    image = images(:turned_over_image)
    seed_locally_complete(image)
    messages = []
    verifier = Image::Processor::Verifier.new { |msg| messages << msg }

    Image::Processor::FileTransfer.stub(:copy_file_to_server, false) do
      result = verifier.transfer(Image.where(id: image.id))
      assert_empty(result[:uploaded])
      assert_not_empty(result[:failed])
    end

    assert(messages.any? { |msg| msg.start_with?("Failed to upload") })
  end

  # A raised exception (e.g. missing rsync binary, Errno::ENOENT) from one
  # file's transfer must not abort the rest of the run -- every other
  # mismatched file still needs its chance to upload.
  def test_transfer_continues_after_one_file_raises
    image = images(:turned_over_image)
    seed_locally_complete(image)
    messages = []
    verifier = Image::Processor::Verifier.new { |msg| messages << msg }
    call_count = 0
    flaky_copy = lambda do |*_args|
      call_count += 1
      raise("boom") if call_count == 1

      true
    end

    Image::Processor::FileTransfer.stub(:copy_file_to_server, flaky_copy) do
      result = verifier.transfer(Image.where(id: image.id))
      assert_equal(1, result[:failed].size)
      assert_operator(result[:uploaded].size, :>, 0,
                      "later files must still upload after an earlier " \
                      "file's transfer raised")
    end

    assert(messages.any? do |msg|
      msg.include?("Failed to upload") && msg.include?("boom")
    end)
  end

  def test_transfer_takes_an_active_record_relation
    image = images(:turned_over_image)
    seed_locally_complete(image)
    seed_remote(1, image, %w[thumb 320 640 960 1280 orig])
    seed_remote(2, image, %w[thumb 320 640])

    result = Image::Processor::Verifier.new.transfer(
      Image.where(id: image.id)
    )

    assert_includes(result[:completed], image.id)
  end

  def test_ssh_sizes_shells_out_with_every_expected_path_in_one_call
    verifier = Image::Processor::Verifier.new
    captured_args = nil
    fake_capture3 = lambda do |*args|
      captured_args = args
      ["", "", stub_status(true)]
    end

    Open3.stub(:capture3, fake_capture3) do
      verifier.send(:ssh_sizes, :ssh_server, "mo@example.test:/data/mo",
                    ["orig/1.jpg", "thumb/1.jpg"])
    end

    assert_equal(
      ["ssh", "mo@example.test", "find", "-L", "/data/mo/orig/1.jpg",
       "/data/mo/thumb/1.jpg", "-maxdepth", "0", "-printf", "'%p\\t%s\\n'"],
      captured_args
    )
  end

  def test_ssh_sizes_parses_find_output
    verifier = Image::Processor::Verifier.new
    find_output = "/data/mo/orig/1.jpg\t456\n/data/mo/thumb/1.jpg\t789\n"

    Open3.stub(:capture3, [find_output, "", stub_status(true)]) do
      result = verifier.send(:ssh_sizes, :ssh_server,
                             "mo@example.test:/data/mo",
                             ["orig/1.jpg", "thumb/1.jpg"])
      assert_equal({ "orig/1.jpg" => 456, "thumb/1.jpg" => 789 }, result)
    end
  end

  # Regression test for a Copilot finding on PR #4751: `find` exits
  # non-zero whenever ANY requested path is missing (the routine case
  # this method exists to detect), so a bare non-zero-exit check would
  # log a false "Failed to check" on nearly every call. Missing-path
  # stderr noise must NOT trigger the log.
  def test_ssh_sizes_does_not_log_for_ordinary_missing_paths
    messages = []
    verifier = Image::Processor::Verifier.new { |msg| messages << msg }
    stderr = "find: '/data/mo/orig/1.jpg': No such file or directory\n"

    Open3.stub(:capture3, ["", stderr, stub_status(false)]) do
      result = verifier.send(:ssh_sizes, :ssh_server,
                             "mo@example.test:/data/mo", ["orig/1.jpg"])
      assert_equal({}, result)
    end

    assert_empty(messages)
  end

  def test_ssh_sizes_logs_and_returns_empty_on_real_failure
    messages = []
    verifier = Image::Processor::Verifier.new { |msg| messages << msg }
    stderr = "ssh: Could not resolve hostname example.test\n"

    Open3.stub(:capture3, ["", stderr, stub_status(false)]) do
      result = verifier.send(:ssh_sizes, :ssh_server,
                             "mo@example.test:/data/mo", ["orig/1.jpg"])
      assert_equal({}, result)
    end

    assert(messages.any? do |msg|
      msg.start_with?("Failed to check mo@example.test for ssh_server") &&
        msg.include?(stderr)
    end)
  end

  def test_remote_sizes_for_unknown_type_raises
    verifier = Image::Processor::Verifier.new
    verifier.instance_variable_set(
      :@image_server_data,
      { weird_server: { type: "ftp", path: "ftp://example.test" } }
    )

    assert_raises(RuntimeError) do
      verifier.send(:remote_sizes_for, :weird_server, ["orig/1.jpg"])
    end
  end

  private

  def stub_status(success)
    status = Object.new
    status.define_singleton_method(:success?) { success }
    status
  end

  def seed_locally_complete(image)
    image.update_columns(transferred: false)
    SUBDIRS.each do |dir|
      File.write("#{local_root}/#{dir}/#{image.id}.jpg", "local-#{dir}")
    end
  end

  def seed_remote(server_num, image, subdirs)
    root = remote_server_path(server_num)
    subdirs.each do |dir|
      File.write("#{root}/#{dir}/#{image.id}.jpg", "local-#{dir}")
    end
  end
end
