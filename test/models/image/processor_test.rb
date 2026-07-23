# frozen_string_literal: true

require("test_helper")

# Exercises Image::Processor directly (no shelling out) -- the Ruby
# replacement for script/process_image and script/rotate_image. See
# test/models/image/processor/verifier_test.rb for the retransfer/verify
# coverage (Verifier now owns that, see #4791), and
# test/classes/image_script_test.rb for the equivalent coverage of the
# still-live shell scripts.
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

  # Transfer is no longer part of #process (see #4791 -- TransferImagesJob
  # owns that now, asynchronously) -- this only exercises the local resize
  # side. See test/jobs/transfer_images_job_test.rb for transfer coverage.
  def test_process_jpg_resizes
    image = images(:in_situ_image)
    image.update_columns(transferred: false, width: nil, height: nil)
    FileUtils.cp(JPG_FIXTURE, "#{local_root}/orig/#{image.id}.jpg")

    Image::Processor.new(image: image, ext: "jpg", set_size: true).process

    image.reload
    assert_equal(407, image.width)
    assert_equal(500, image.height)
    assert_not(image.transferred, "#process must not mark transferred")

    %w[thumb 320 640 960 1280 orig].each do |subdir|
      assert_path_exists("#{local_root}/#{subdir}/#{image.id}.jpg")
    end
  end

  # #process hashes the small rendition inline, while it is still local,
  # instead of leaving it to a separate job that could race the transfer
  # (#4796).
  def test_process_computes_dhash
    unless system("command -v convert >/dev/null 2>&1")
      skip("ImageMagick `convert` not available")
    end

    image = images(:in_situ_image)
    image.update_columns(dhash: nil)
    FileUtils.cp(JPG_FIXTURE, "#{local_root}/orig/#{image.id}.jpg")

    Image::Processor.new(image: image, ext: "jpg", set_size: true).process

    assert_not_nil(image.reload.dhash, "#process must compute the dhash")
  end

  def test_process_converts_non_jpg_original
    image = images(:turned_over_image)
    image.update_columns(transferred: false, width: nil, height: nil)
    FileUtils.cp(TIFF_FIXTURE, "#{local_root}/orig/#{image.id}.tiff")

    Image::Processor.new(image: image, ext: "tiff", set_size: true).process

    image.reload
    assert_equal(2560, image.width)
    assert_equal(1920, image.height)
    assert_not(image.transferred, "#process must not mark transferred")
    assert_path_exists("#{local_root}/orig/#{image.id}.jpg")
  end

  def test_strip_original_gps_success
    image = images(:in_situ_image)
    FileUtils.cp(GEOTAGGED_FIXTURE, "#{local_root}/orig/#{image.id}.jpg")
    assert(MiniExiftool.new("#{local_root}/orig/#{image.id}.jpg").gps_latitude,
           "fixture should start with GPS data")
    assert_not(image.gps_stripped)

    error = Image::Processor.strip_original_gps(image, ext: "jpg")

    assert_nil(error)
    stripped = MiniExiftool.new("#{local_root}/orig/#{image.id}.jpg")
    assert_nil(stripped.gps_latitude)
    assert(image.reload.gps_stripped,
           "gps_stripped should be true once the strip actually succeeds")
  end

  # Regression test for Copilot/adversarial-review finding: gps_stripped
  # must stay false on a failed strip, not just "not yet set true" --
  # otherwise #strip_gps!'s `return nil if gps_stripped` guard would
  # permanently block ever retrying a failed strip.
  def test_strip_original_gps_missing_file
    image = images(:in_situ_image)

    error = Image::Processor.strip_original_gps(image, ext: "jpg")

    assert(error.present?)
    assert_not(image.reload.gps_stripped)
  end

  def test_rotate_reorients_and_reprocesses
    image = images(:in_situ_image)
    image.update_columns(transferred: false, width: 1000, height: 1000)
    FileUtils.cp(JPG_FIXTURE, "#{local_root}/orig/#{image.id}.jpg")

    Image::Processor.new(image: image, ext: "jpg").rotate("+90")

    image.reload
    assert_equal(500, image.width)
    assert_equal(407, image.height)
    assert_not(image.transferred, "#rotate's #process must not transfer")
  end

  def test_rotate_fetches_full_size_from_remote_if_missing_locally
    image = images(:in_situ_image)
    image.update_columns(transferred: false, width: 1000, height: 1000)
    FileUtils.cp(JPG_FIXTURE, "#{remote_server_path(1)}/orig/#{image.id}.jpg")

    Image::Processor.new(image: image, ext: "jpg").rotate("+90")

    assert_path_exists("#{local_root}/orig/#{image.id}.jpg")
  end

  # Regression test for the plan's fix to #4791: a single unreachable
  # server must not abort the fetch when a LATER configured server has
  # the same file -- the original code broke out of the loop after the
  # first server with an "orig" subdir, even if that copy silently failed
  # (returned false, without raising).
  def test_make_sure_we_have_full_size_locally_tries_every_server
    image = images(:in_situ_image)
    FileUtils.cp(JPG_FIXTURE, "#{remote_server_path(1)}/orig/#{image.id}.jpg")
    processor = Image::Processor.new(image: image, ext: "jpg")
    fake_data = {
      unreachable: { type: "file", path: "/nonexistent", subdirs: ["orig"] },
      remote1: { type: "file", path: remote_server_path(1),
                 subdirs: ["orig"] }
    }
    real_copy = Image::Processor::FileTransfer.method(:copy_file_from_server)
    flaky_fetch = lambda do |server, remote_file|
      next false if server == :unreachable

      real_copy.call(server, remote_file)
    end

    Image::Processor.stub(:image_server_data, fake_data) do
      Image::Processor.stub(:image_servers, [:unreachable, :remote1]) do
        Image::Processor::FileTransfer.stub(:copy_file_from_server,
                                            flaky_fetch) do
          processor.make_sure_we_have_full_size_locally
        end
      end
    end

    assert_path_exists("#{local_root}/orig/#{image.id}.jpg")
  end

  # Regression test for a Copilot finding on PR #4751: a silently-failed
  # fetch (e.g. an ssh/rsync remote missing the file, which doesn't raise
  # on its own) must not be allowed to proceed to MiniExiftool/MiniMagick
  # -- those would fail on a missing file with a far less clear error.
  # script/rotate_image aborted immediately on this failure.
  def test_make_sure_we_have_full_size_locally_raises_if_fetch_fails
    image = images(:in_situ_image)
    processor = Image::Processor.new(image: image, ext: "jpg")

    Image::Processor::FileTransfer.stub(:copy_file_from_server, false) do
      assert_raises(RuntimeError) do
        processor.make_sure_we_have_full_size_locally
      end
    end
  end

  # Regression test for a second Copilot finding on PR #4751:
  # copy_file_from_server can RAISE (e.g. Errno::ENOENT via FileUtils.cp,
  # or Rsync.run raising if rsync/ssh is unavailable), not just return
  # false. A raised exception on one server must not abort the loop any
  # more than a returned false does -- the next server must still get
  # its chance.
  def test_make_sure_we_have_full_size_locally_tries_next_server_after_raise
    image = images(:in_situ_image)
    FileUtils.cp(JPG_FIXTURE, "#{remote_server_path(1)}/orig/#{image.id}.jpg")
    processor = Image::Processor.new(image: image, ext: "jpg")
    fake_data = {
      unreachable: { type: "file", path: "/nonexistent", subdirs: ["orig"] },
      remote1: { type: "file", path: remote_server_path(1),
                 subdirs: ["orig"] }
    }
    real_copy = Image::Processor::FileTransfer.method(:copy_file_from_server)
    raising_fetch = lambda do |server, remote_file|
      raise(Errno::ENOENT) if server == :unreachable

      real_copy.call(server, remote_file)
    end

    Image::Processor.stub(:image_server_data, fake_data) do
      Image::Processor.stub(:image_servers, [:unreachable, :remote1]) do
        Image::Processor::FileTransfer.stub(:copy_file_from_server,
                                            raising_fetch) do
          processor.make_sure_we_have_full_size_locally
        end
      end
    end

    assert_path_exists("#{local_root}/orig/#{image.id}.jpg")
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
  end

  def test_rotate_mirror_vertical
    image = images(:in_situ_image)
    image.update_columns(transferred: false, width: 1000, height: 1000)
    FileUtils.cp(JPG_FIXTURE, "#{local_root}/orig/#{image.id}.jpg")

    Image::Processor.new(image: image, ext: "jpg").rotate("-v")

    image.reload
    assert_equal(407, image.width)
    assert_equal(500, image.height)
  end

  # Regression for a bug found testing #4824: a mirror leaves
  # width/height unchanged, and transferred can already be false (any
  # environment with no writable image servers, or a not-yet-transferred
  # image) -- with no dirty attribute, Rails skipped the UPDATE
  # entirely, so updated_at (and the #4808 cache-busting URL token
  # derived from it) never changed and browsers kept serving the
  # pre-mirror bytes. Rotations dodged this only because width/height
  # swap. The record must be touched whenever the files are rewritten.
  def test_rotate_mirror_bumps_updated_at_when_no_attribute_changes
    image = images(:in_situ_image)
    FileUtils.cp(JPG_FIXTURE, "#{local_root}/orig/#{image.id}.jpg")
    width, height = FastImage.size("#{local_root}/orig/#{image.id}.jpg")
    image.update_columns(transferred: false, width: width, height: height,
                         updated_at: 1.day.ago)
    old_updated_at = image.reload.updated_at
    old_url = image.url(:small)

    Image::Processor.new(image: image, ext: "jpg").rotate("-h")

    image.reload
    assert_operator(image.updated_at, :>, old_updated_at,
                    "mirror must bump updated_at so the cache-busting " \
                    "URL token changes")
    assert_not_equal(old_url, image.url(:small))
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
