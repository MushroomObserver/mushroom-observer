# frozen_string_literal: true

require("test_helper")

# Exercises Image::Processor directly (no shelling out) -- the Ruby
# replacement for script/process_image, script/rotate_image, and
# script/retransfer_images. See test/classes/image_script_test.rb for the
# equivalent coverage of the still-live shell scripts.
class Image::ProcessorTest < UnitTestCase
  include ActiveJob::TestHelper

  TIFF_FIXTURE = Rails.root.join("test/images/pleopsidium.tiff").to_s
  JPG_FIXTURE = Rails.root.join("test/images/sticky.jpg").to_s
  GEOTAGGED_FIXTURE = Rails.root.join("test/images/geotagged.jpg").to_s

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

  SUBDIRS = %w[thumb 320 640 960 1280 orig].freeze

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

  def test_image_server_data_matches_config
    assert_equal(local_root, Image::Processor.local_images_path)
    assert_equal(remote_server_path(1),
                 Image::Processor.image_server_data[:remote1][:path])
    assert_equal(remote_server_path(2),
                 Image::Processor.image_server_data[:remote2][:path])
    assert_equal([:remote1, :remote2], Image::Processor.image_servers,
                 ":local must never be a transfer target")
  end

  def test_write_target_path
    file_uri = Addressable::URI.parse("file://#{local_root}")
    assert_equal(local_root,
                 Image::Processor::ServerData.write_target_path(file_uri))

    ssh_uri = Addressable::URI.parse("ssh://mo@images.example.org:/data/mo")
    assert_equal(
      "mo@images.example.org:/data/mo",
      Image::Processor::ServerData.write_target_path(ssh_uri)
    )
  end

  def test_write_target_subdirs_translates_sizes_to_subdirs
    assert_equal(
      %w[thumb 320 640],
      Image::Processor::ServerData.write_target_subdirs(
        [:thumbnail, :small, :medium], Image::Processor::IMAGE_SUBDIRS
      )
    )
    assert_equal(
      Image::Processor::IMAGE_SUBDIRS,
      Image::Processor::ServerData.write_target_subdirs(
        nil, Image::Processor::IMAGE_SUBDIRS
      )
    )
  end

  def test_write_target_subdirs_raises_on_unknown_size
    assert_raises(RuntimeError) do
      Image::Processor::ServerData.write_target_subdirs(
        [:thumbnail, :bogus_size], Image::Processor::IMAGE_SUBDIRS
      )
    end
  end

  def test_process_jpg_resizes_and_transfers
    image = images(:in_situ_image)
    image.update_columns(transferred: false, width: nil, height: nil)
    FileUtils.cp(JPG_FIXTURE, "#{local_root}/orig/#{image.id}.jpg")
    obs = observations(:detailed_unknown_obs)
    obs.update_columns(updated_at: 1.day.ago)

    Image::Processor.new(image: image, ext: "jpg", set_size: true,
                         strip_gps: false).process

    image.reload
    assert_equal(407, image.width)
    assert_equal(500, image.height)
    assert(image.transferred)

    %w[thumb 320 640 960 1280 orig].each do |subdir|
      assert_path_exists("#{local_root}/#{subdir}/#{image.id}.jpg")
      assert_path_exists(
        "#{remote_server_path(1)}/#{subdir}/#{image.id}.jpg",
        "#{subdir} should have gone to remote1"
      )
    end
    %w[thumb 320 640].each do |subdir|
      assert_path_exists(
        "#{remote_server_path(2)}/#{subdir}/#{image.id}.jpg",
        "#{subdir} should have gone to remote2"
      )
    end
    %w[960 1280 orig].each do |subdir|
      assert_not(
        File.exist?("#{remote_server_path(2)}/#{subdir}/#{image.id}.jpg"),
        "#{subdir} should NOT have gone to remote2"
      )
    end

    assert_operator(obs.reload.updated_at, :>, 1.hour.ago,
                    "processing should touch observations for cache busting")
  end

  def test_process_converts_non_jpg_original
    image = images(:turned_over_image)
    image.update_columns(transferred: false, width: nil, height: nil)
    FileUtils.cp(TIFF_FIXTURE, "#{local_root}/orig/#{image.id}.tiff")

    Image::Processor.new(image: image, ext: "tiff", set_size: true,
                         strip_gps: false).process

    image.reload
    assert_equal(2560, image.width)
    assert_equal(1920, image.height)
    assert(image.transferred)
    assert_path_exists("#{local_root}/orig/#{image.id}.jpg")
    assert_path_exists("#{remote_server_path(1)}/orig/#{image.id}.tiff")
    assert_path_exists("#{remote_server_path(1)}/orig/#{image.id}.jpg")
  end

  def test_process_strips_gps_before_transfer
    image = images(:in_situ_image)
    image.update_columns(transferred: false)
    FileUtils.cp(GEOTAGGED_FIXTURE, "#{local_root}/orig/#{image.id}.jpg")
    assert(MiniExiftool.new("#{local_root}/orig/#{image.id}.jpg").gps_latitude,
           "fixture should start with GPS data")

    Image::Processor.new(image: image, ext: "jpg", set_size: false,
                         strip_gps: true).process

    stripped = MiniExiftool.new("#{local_root}/orig/#{image.id}.jpg")
    assert_nil(stripped.gps_latitude)
  end

  def test_rotate_reorients_and_reprocesses
    image = images(:in_situ_image)
    image.update_columns(transferred: false, width: 1000, height: 1000)
    FileUtils.cp(JPG_FIXTURE, "#{local_root}/orig/#{image.id}.jpg")

    Image::Processor.new(image: image, ext: "jpg").rotate("+90")

    image.reload
    assert_equal(500, image.width)
    assert_equal(407, image.height)
    assert(image.transferred)
    assert_path_exists("#{remote_server_path(1)}/thumb/#{image.id}.jpg")
  end

  def test_rotate_fetches_full_size_from_remote_if_missing_locally
    image = images(:in_situ_image)
    image.update_columns(transferred: false, width: 1000, height: 1000)
    FileUtils.cp(JPG_FIXTURE, "#{remote_server_path(1)}/orig/#{image.id}.jpg")

    Image::Processor.new(image: image, ext: "jpg").rotate("+90")

    assert_path_exists("#{local_root}/orig/#{image.id}.jpg")
    assert(image.reload.transferred)
  end

  # Regression test for a Copilot finding on PR #4751: a silently-failed
  # fetch (e.g. an ssh/rsync remote missing the file, which doesn't raise
  # on its own) must not be allowed to proceed to MiniExiftool/MiniMagick
  # -- those would fail on a missing file with a far less clear error.
  # script/rotate_image aborted immediately on this failure.
  def test_make_sure_we_have_full_size_locally_raises_if_fetch_fails
    image = images(:in_situ_image)
    processor = Image::Processor.new(image: image, ext: "jpg")

    processor.stub(:copy_file_from_server, nil) do
      assert_raises(RuntimeError) do
        processor.send(:make_sure_we_have_full_size_locally)
      end
    end
  end

  def test_retransfer_images_only_touches_untransferred_images
    in_situ = images(:in_situ_image)
    turned_over = images(:turned_over_image)
    assert_not(in_situ.transferred)
    assert_not(turned_over.transferred)

    File.write("#{local_root}/orig/#{in_situ.id}.jpg", "A")
    File.write("#{local_root}/960/#{in_situ.id}.jpg", "B")
    File.write("#{local_root}/640/#{in_situ.id}.jpg", "C")
    File.write("#{local_root}/320/#{in_situ.id}.jpg", "D")
    File.write("#{local_root}/thumb/#{in_situ.id}.jpg", "E")
    File.write("#{local_root}/1280/#{in_situ.id}.jpg", "F")
    File.write("#{local_root}/960/#{turned_over.id}.jpg", "G")
    File.write("#{local_root}/640/#{turned_over.id}.jpg", "H")
    File.write("#{local_root}/320/#{turned_over.id}.jpg", "I")
    File.write("#{local_root}/thumb/#{turned_over.id}.jpg", "J")
    File.write("#{local_root}/1280/#{turned_over.id}.jpg", "K")
    File.write("#{local_root}/orig/#{turned_over.id}.jpg", "L")

    Image::Processor.retransfer_images

    assert(in_situ.reload.transferred)
    assert(turned_over.reload.transferred)
    assert_equal("A",
                 File.read("#{remote_server_path(1)}/orig/#{in_situ.id}.jpg"))
    assert_equal("E",
                 File.read("#{remote_server_path(1)}/thumb/#{in_situ.id}.jpg"))
    assert_equal("E",
                 File.read("#{remote_server_path(2)}/thumb/#{in_situ.id}.jpg"))
    assert_not(
      File.exist?("#{remote_server_path(2)}/960/#{in_situ.id}.jpg"),
      "large should NOT go to remote2 (not in its configured :sizes)"
    )
  end

  def test_retransfer_images_does_not_mark_transferred_on_failure
    in_situ = images(:in_situ_image)
    File.write("#{local_root}/orig/#{in_situ.id}.jpg", "A")

    Image::Processor::FileTransfer.stub(:copy_file_to_server, false) do
      Image::Processor.retransfer_images
    end

    assert_not(in_situ.reload.transferred)
  end

  # Regression test: a failed GPS strip leaves #process's early return
  # (see test_process_strip_gps_failure_does_not_transfer_files) with
  # only "orig" present locally -- no derivatives, since make_file_sizes
  # never ran. retransfer_images must not treat that as "just needs a
  # retry" and push the (possibly still GPS-tainted) "orig" file alone;
  # it must skip the image entirely until #process actually completes.
  def test_retransfer_images_skips_partially_processed_image
    in_situ = images(:in_situ_image)
    # Only "orig" exists -- exactly what a failed GPS strip leaves behind.
    File.write("#{local_root}/orig/#{in_situ.id}.jpg", "still has GPS data")

    Image::Processor.retransfer_images

    assert_not(
      File.exist?("#{remote_server_path(1)}/orig/#{in_situ.id}.jpg"),
      "Must not transfer a partially-processed image's files anywhere"
    )
    assert_not(in_situ.reload.transferred)
  end

  def test_requires_image
    assert_raises(RuntimeError) { Image::Processor.new(image: nil) }
  end

  def test_requires_user
    image = images(:in_situ_image)
    image.stub(:user, nil) do
      assert_raises(RuntimeError) { Image::Processor.new(image: image) }
    end
  end

  def test_process_strip_gps_failure_emails_webmaster
    image = images(:in_situ_image)
    image.update_columns(transferred: false)
    FileUtils.cp(JPG_FIXTURE, "#{local_root}/orig/#{image.id}.jpg")
    processor = Image::Processor.new(image: image, ext: "jpg",
                                     strip_gps: true)

    processor.stub(:system, false) do
      assert_enqueued_with(job: ActionMailer::MailDeliveryJob) do
        processor.process
      end
    end

    # A failed transfer must not mark the image transferred -- otherwise
    # RetransferImagesJob's `Image.where(transferred: false)` safety net
    # would never pick this image up again.
    assert_not(image.reload.transferred)
  end

  # Regression test for a Copilot finding on PR #4751: a failed GPS strip
  # must stop processing before any file reaches a remote image server --
  # otherwise the exact data the user asked to strip leaks to public
  # storage anyway. script/process_image's `set -e` aborted immediately
  # on the same failure; #process must match that, not just skip marking
  # the image transferred.
  def test_process_strip_gps_failure_does_not_transfer_files
    image = images(:in_situ_image)
    image.update_columns(transferred: false)
    FileUtils.cp(JPG_FIXTURE, "#{local_root}/orig/#{image.id}.jpg")
    processor = Image::Processor.new(image: image, ext: "jpg",
                                     strip_gps: true)

    processor.stub(:system, false) do
      processor.process
    end

    assert_not(
      File.exist?("#{remote_server_path(1)}/thumb/#{image.id}.jpg"),
      "Files must not reach a remote server when GPS stripping failed"
    )
  end

  def test_rotate_non_jpg_original_does_not_undo_rotation
    image = images(:turned_over_image)
    image.update_columns(transferred: false, width: 1000, height: 1000)
    FileUtils.cp(TIFF_FIXTURE, "#{local_root}/orig/#{image.id}.tiff")
    # Simulate a full-size JPG derivative already produced by an earlier
    # #process run -- #rotate transforms only this file in place. The bug
    # this guards: the trailing #process call inside #rotate used to
    # reconvert from the raw tiff whenever ext != "jpg", silently
    # discarding the rotation just applied to this file.
    FileUtils.cp(JPG_FIXTURE, "#{local_root}/orig/#{image.id}.jpg")

    Image::Processor.new(image: image, ext: "tiff").rotate("+90")

    width, height = FastImage.size("#{local_root}/orig/#{image.id}.jpg")
    assert_equal(500, width)
    assert_equal(407, height)
  end

  def test_rotate_mirror_horizontal
    image = images(:in_situ_image)
    image.update_columns(transferred: false, width: 1000, height: 1000)
    FileUtils.cp(JPG_FIXTURE, "#{local_root}/orig/#{image.id}.jpg")

    Image::Processor.new(image: image, ext: "jpg").rotate("-h")

    image.reload
    assert_equal(407, image.width)
    assert_equal(500, image.height)
    assert(image.transferred)
  end

  def test_rotate_mirror_vertical
    image = images(:in_situ_image)
    image.update_columns(transferred: false, width: 1000, height: 1000)
    FileUtils.cp(JPG_FIXTURE, "#{local_root}/orig/#{image.id}.jpg")

    Image::Processor.new(image: image, ext: "jpg").rotate("-v")

    image.reload
    assert_equal(407, image.width)
    assert_equal(500, image.height)
    assert(image.transferred)
  end

  def test_salvage_first_layer_if_multilayer_picks_one_and_cleans_up
    image = images(:in_situ_image)
    processor = Image::Processor.new(image: image, ext: "tiff")
    File.write("#{local_root}/orig/#{image.id}-0.jpg", "first layer")
    File.write("#{local_root}/orig/#{image.id}-1.jpg", "second layer")

    processor.send(:salvage_first_layer_if_multilayer)

    assert_path_exists("#{local_root}/orig/#{image.id}.jpg")
    assert_includes(["first layer", "second layer"],
                    File.read("#{local_root}/orig/#{image.id}.jpg"))
    assert_not(File.exist?("#{local_root}/orig/#{image.id}-0.jpg"))
    assert_not(File.exist?("#{local_root}/orig/#{image.id}-1.jpg"))
  end

  # Regression test for a Copilot finding on PR #4751: script/process_image
  # picked the LARGEST layer by file size (`ls -rS ... | tail -1`), not
  # whichever one Dir.glob happens to return first (filesystem/lexicographic
  # order, unrelated to size or image content).
  def test_salvage_first_layer_if_multilayer_picks_largest_by_size
    image = images(:in_situ_image)
    processor = Image::Processor.new(image: image, ext: "tiff")
    # "-0" sorts first alphabetically/by glob order, but is the smaller
    # file -- proves the choice is size-based, not order-based.
    File.write("#{local_root}/orig/#{image.id}-0.jpg", "small")
    File.write("#{local_root}/orig/#{image.id}-1.jpg", "much bigger layer")

    processor.send(:salvage_first_layer_if_multilayer)

    assert_equal("much bigger layer",
                 File.read("#{local_root}/orig/#{image.id}.jpg"))
  end

  def test_copy_file_to_server_ssh_type_uses_rsync
    image = images(:in_situ_image)
    processor = Image::Processor.new(image: image, ext: "jpg")
    File.write("#{local_root}/thumb/#{image.id}.jpg", "rsync me")
    fake_data = { ssh_server: { type: "ssh", path: remote_server_path(1) } }

    Image::Processor.stub(:image_server_data, fake_data) do
      processor.send(:copy_file_to_server, :ssh_server,
                     "thumb/#{image.id}.jpg")
    end

    assert_equal(
      "rsync me",
      File.read("#{remote_server_path(1)}/thumb/#{image.id}.jpg")
    )
  end

  def test_copy_file_to_server_unknown_type_raises
    image = images(:in_situ_image)
    processor = Image::Processor.new(image: image, ext: "jpg")
    fake_data = { weird: { type: "ftp", path: "/tmp" } }

    Image::Processor.stub(:image_server_data, fake_data) do
      assert_raises(RuntimeError) do
        processor.send(:copy_file_to_server, :weird, "x.jpg")
      end
    end
  end

  def test_copy_file_from_server_ssh_type_uses_rsync
    image = images(:in_situ_image)
    processor = Image::Processor.new(image: image, ext: "jpg")
    File.write("#{remote_server_path(1)}/thumb/#{image.id}.jpg",
               "remote data")
    fake_data = { ssh_server: { type: "ssh", path: remote_server_path(1) } }

    Image::Processor.stub(:image_server_data, fake_data) do
      processor.send(:copy_file_from_server, :ssh_server,
                     "thumb/#{image.id}.jpg")
    end

    assert_equal("remote data",
                 File.read("#{local_root}/thumb/#{image.id}.jpg"))
  end

  def test_copy_file_from_server_http_type_stringio_response
    image = images(:in_situ_image)
    processor = Image::Processor.new(image: image, ext: "jpg")
    fake_data = { http_server: { type: "http", path: "http://example.test" } }
    fake_uri = Object.new
    fake_uri.define_singleton_method(:open) { StringIO.new("http body") }

    Image::Processor.stub(:image_server_data, fake_data) do
      URI.stub(:parse, fake_uri) do
        processor.send(:copy_file_from_server, :http_server,
                       "thumb/#{image.id}.jpg")
      end
    end

    assert_equal("http body",
                 File.read("#{local_root}/thumb/#{image.id}.jpg"))
  end

  def test_copy_file_from_server_http_type_creates_missing_destination_dir
    image = images(:in_situ_image)
    processor = Image::Processor.new(image: image, ext: "jpg")
    fake_data = { http_server: { type: "http", path: "http://example.test" } }
    fake_uri = Object.new
    fake_uri.define_singleton_method(:open) { StringIO.new("http body") }
    # "new_subdir" is not among the subdirs `setup` pre-creates.
    assert_not(File.directory?("#{local_root}/new_subdir"))

    Image::Processor.stub(:image_server_data, fake_data) do
      URI.stub(:parse, fake_uri) do
        processor.send(:copy_file_from_server, :http_server,
                       "new_subdir/#{image.id}.jpg")
      end
    end

    assert_equal("http body",
                 File.read("#{local_root}/new_subdir/#{image.id}.jpg"))
  end

  def test_copy_file_from_server_http_type_tempfile_response
    image = images(:in_situ_image)
    processor = Image::Processor.new(image: image, ext: "jpg")
    fake_data = { http_server: { type: "http", path: "http://example.test" } }
    tempfile = Tempfile.new("http_test")
    tempfile.write("tempfile body")
    tempfile.rewind
    fake_uri = Object.new
    fake_uri.define_singleton_method(:open) { tempfile }

    Image::Processor.stub(:image_server_data, fake_data) do
      URI.stub(:parse, fake_uri) do
        processor.send(:copy_file_from_server, :http_server,
                       "thumb/#{image.id}.jpg")
      end
    end

    assert_equal("tempfile body",
                 File.read("#{local_root}/thumb/#{image.id}.jpg"))
  end

  def test_copy_file_from_server_unknown_type_raises
    image = images(:in_situ_image)
    processor = Image::Processor.new(image: image, ext: "jpg")
    fake_data = { weird: { type: "ftp", path: "/tmp" } }

    Image::Processor.stub(:image_server_data, fake_data) do
      assert_raises(RuntimeError) do
        processor.send(:copy_file_from_server, :weird, "x.jpg")
      end
    end
  end
end
