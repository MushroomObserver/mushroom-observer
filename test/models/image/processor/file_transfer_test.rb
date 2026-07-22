# frozen_string_literal: true

require("test_helper")

# Exercises Image::Processor::FileTransfer's copy_file_to_server directly
# at the module level -- test env's configured remotes are both "file"
# type (see config/image_config.yml), so the "ssh" and "unknown type"
# branches aren't reachable through Verifier/TransferImagesJob's own
# tests, which only ever run against those file-type test servers.
class Image::Processor::FileTransferTest < UnitTestCase
  def local_root
    Image::Processor.local_images_path
  end

  def remote_server_path(num)
    if (worker_num = database_worker_number)
      Rails.public_path.join("test_server#{num}-#{worker_num}").to_s
    else
      Rails.public_path.join("test_server#{num}").to_s
    end
  end

  def setup
    FileUtils.mkpath("#{local_root}/thumb")
    FileUtils.mkpath("#{remote_server_path(1)}/thumb")
    super
  end

  def teardown
    FileUtils.rm_rf(remote_server_path(1))
    super
  end

  def test_copy_file_to_server_ssh_type_uses_rsync
    image = images(:in_situ_image)
    File.write("#{local_root}/thumb/#{image.id}.jpg", "rsync me")
    fake_data = { ssh_server: { type: "ssh", path: remote_server_path(1) } }

    Image::Processor.stub(:image_server_data, fake_data) do
      Image::Processor::FileTransfer.copy_file_to_server(
        :ssh_server, "thumb/#{image.id}.jpg"
      )
    end

    assert_equal(
      "rsync me",
      File.read("#{remote_server_path(1)}/thumb/#{image.id}.jpg")
    )
  end

  def test_copy_file_to_server_ssh_type_raises_rsync_error_with_detail
    # No local source file exists, so the real rsync exits non-zero; the
    # failure must raise RsyncError carrying the exit code and stderr,
    # never swallow it as a bare false.
    fake_data = { ssh_server: { type: "ssh", path: remote_server_path(1) } }

    error = Image::Processor.stub(:image_server_data, fake_data) do
      assert_raises(Image::Processor::FileTransfer::RsyncError) do
        Image::Processor::FileTransfer.copy_file_to_server(
          :ssh_server, "thumb/does-not-exist.jpg"
        )
      end
    end

    assert_match(/rsync exited \d+:/, error.message)
  end

  def test_copy_file_to_server_unknown_type_raises
    fake_data = { weird: { type: "ftp", path: "/tmp" } }

    Image::Processor.stub(:image_server_data, fake_data) do
      assert_raises(RuntimeError) do
        Image::Processor::FileTransfer.copy_file_to_server(:weird, "x.jpg")
      end
    end
  end
end
