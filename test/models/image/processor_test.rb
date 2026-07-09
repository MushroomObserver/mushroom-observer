# frozen_string_literal: true

require("test_helper")

# Exercises Image::Processor directly (no shelling out) -- the Ruby
# replacement for script/process_image, script/rotate_image, and
# script/retransfer_images. See test/classes/image_script_test.rb for the
# equivalent coverage of the still-live shell scripts.
class Image::ProcessorTest < UnitTestCase
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

  def test_requires_image
    assert_raises(RuntimeError) { Image::Processor.new(image: nil) }
  end

  def test_requires_user
    image = images(:in_situ_image)
    image.stub(:user, nil) do
      assert_raises(RuntimeError) { Image::Processor.new(image: image) }
    end
  end
end
