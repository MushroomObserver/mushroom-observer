# frozen_string_literal: true

require("test_helper")

# See GpsLeakDetectorJob for the recurring job that drives this, and
# GitHub issue #4859 for the leak mechanisms the tripwire exists to
# catch.
class Image::Processor::GpsLeakScanTest < UnitTestCase
  SERVER_DATA = {
    local: { type: "file", path: "/local", subdirs: %w[orig] },
    sshbox: { type: "ssh", path: "mo@example.test:/data/mo",
              subdirs: %w[thumb 320 640 960 1280 orig] },
    thumbs_only: { type: "ssh", path: "mo@thumbs.test:/data/thumbs",
                   subdirs: %w[thumb 320] }
  }.freeze

  def test_scans_ssh_servers_with_orig_and_parses_hit_ids
    image = images(:in_situ_image)
    captured = nil
    fake_capture3 = lambda do |*args|
      captured = args
      ["/data/mo/orig/#{image.id}.jpg\n", "", nil]
    end

    hits = Image::Processor.stub(:image_server_data, SERVER_DATA) do
      Open3.stub(:capture3, fake_capture3) do
        Image::Processor.detect_gps_leaks([image])
      end
    end

    assert_equal([image.id], hits)
    assert_equal("ssh", captured[0])
    assert_includes(captured, "BatchMode=yes",
                    "ssh must fail fast, never hang on a prompt")
    assert_equal("mo@example.test", captured[-2],
                 "only the ssh server with an orig subdir should be " \
                 "scanned -- never thumbs_only or the file-type local")
    assert_includes(captured[-1], "$GPS:GPSLatitude or $GPS:GPSLongitude")
    assert_includes(captured[-1], "-fast2")
    assert_includes(captured[-1], "/data/mo/orig/#{image.id}.jpg")
  end

  def test_includes_raw_original_path_for_non_jpg_images
    image = images(:in_situ_image)
    commands = []
    fake_capture3 = lambda do |*args|
      commands << args[-1]
      ["", "", nil]
    end

    image.stub(:original_extension, "tiff") do
      Image::Processor.stub(:image_server_data, SERVER_DATA) do
        Open3.stub(:capture3, fake_capture3) do
          assert_empty(Image::Processor.detect_gps_leaks([image]))
        end
      end
    end

    assert_includes(commands.first, "/data/mo/orig/#{image.id}.jpg")
    assert_includes(commands.first, "/data/mo/orig/#{image.id}.tiff")
  end

  def test_missing_file_stderr_is_silent_but_real_errors_are_logged
    image = images(:in_situ_image)
    messages = []
    stderr = "Error: File not found - /data/mo/orig/#{image.id}.jpg\n"

    Image::Processor.stub(:image_server_data, SERVER_DATA) do
      Open3.stub(:capture3, ["", stderr, nil]) do
        Image::Processor.detect_gps_leaks([image]) { |msg| messages << msg }
      end
    end
    assert_empty(messages, "missing files are routine, not loggable errors")

    ssh_error = "ssh: Could not resolve hostname example.test\n"
    Image::Processor.stub(:image_server_data, SERVER_DATA) do
      Open3.stub(:capture3, ["", ssh_error, nil]) do
        Image::Processor.detect_gps_leaks([image]) { |msg| messages << msg }
      end
    end
    assert(messages.any? do |msg|
      msg.start_with?("Errors checking mo@example.test") &&
        msg.include?(ssh_error.strip)
    end)
  end

  def test_returns_empty_for_no_images_without_shelling_out
    Image::Processor.stub(:image_server_data, SERVER_DATA) do
      Open3.stub(:capture3, ->(*) { raise("must not shell out") }) do
        assert_empty(Image::Processor.detect_gps_leaks([]))
      end
    end
  end
end
