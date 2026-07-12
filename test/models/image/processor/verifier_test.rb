# frozen_string_literal: true

require("test_helper")

# Ruby port of script/verify_images -- see test/classes/image_script_test.rb
# for the equivalent shell-script coverage this fixture data is drawn from.
class Image::Processor::VerifierTest < UnitTestCase
  SUBDIRS = %w[thumb 320 640 960 1280 orig].freeze

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

  def test_verify_uploads_mismatches_and_deletes_fully_synced_files
    in_situ = images(:in_situ_image).id
    turned_over = images(:turned_over_image).id
    commercial = images(:commercial_inquiry_image).id
    disconnected = images(:disconnected_coprinus_comatus_image).id
    seed_local_files(turned_over, commercial, disconnected)
    seed_remote1_files(in_situ, turned_over, commercial, disconnected)
    seed_remote2_files(in_situ, turned_over, commercial)

    result = Image::Processor.verify_images

    assert_uploads(result, turned_over, commercial, disconnected)
    assert_deletes(result, turned_over, commercial)
  end

  # Regression test for a Copilot finding on PR #4751: a failed upload
  # must not be recorded in the summary as if it succeeded -- otherwise
  # a real transfer failure is silently masked in the job's log/summary.
  def test_upload_mismatches_does_not_record_failed_uploads
    turned_over = images(:turned_over_image).id
    seed_local_files(turned_over, images(:commercial_inquiry_image).id,
                     images(:disconnected_coprinus_comatus_image).id)
    messages = []
    verifier = Image::Processor::Verifier.new { |msg| messages << msg }

    Image::Processor::FileTransfer.stub(:copy_file_to_server, false) do
      result = verifier.run
      assert_empty(result[:uploaded])
    end

    assert(messages.any? { |msg| msg.start_with?("Failed to upload") })
  end

  def test_verify_yields_log_lines_to_the_given_block
    lines = []
    Image::Processor.verify_images { |msg| lines << msg }
    assert_includes(lines, "Listing local thumb")
  end

  def test_list_server_dispatches_ssh_type_to_ssh_listing
    fake_data = {
      ssh_server: { type: "ssh", path: "mo@example.test:/data/mo",
                    subdirs: %w[orig] }
    }

    Image::Processor.stub(:image_server_data, fake_data) do
      verifier = Image::Processor::Verifier.new
      Open3.stub(:capture2, ["remote.jpg\t99\n", stub_status(true)]) do
        result = verifier.send(:list_server, :ssh_server)
        assert_equal({ "orig/remote.jpg" => 99 }, result)
      end
    end
  end

  def test_list_subdir_unknown_type_raises
    verifier = Image::Processor::Verifier.new
    data = { type: "ftp", path: "ftp://example.test" }

    assert_raises(RuntimeError) do
      verifier.send(:list_subdir, :weird_server, data, "orig")
    end
  end

  def test_list_ssh_subdir_shells_out_to_ssh_find
    verifier = Image::Processor::Verifier.new
    captured_args = nil
    fake_capture2 = lambda do |*args|
      captured_args = args
      ["", stub_status(true)]
    end

    Open3.stub(:capture2, fake_capture2) do
      verifier.send(:list_ssh_subdir, :ssh_server,
                    "mo@example.test:/data/mo", "orig")
    end

    assert_equal(
      ["ssh", "mo@example.test", "find", "-L", "/data/mo/orig",
       "-maxdepth", "1", "-type", "f", "-printf", "%f\\t%s\\n"],
      captured_args
    )
  end

  def test_list_ssh_subdir_parses_find_output
    verifier = Image::Processor::Verifier.new
    find_output = "123.jpg\t456\n124.jpg\t789\n"

    Open3.stub(:capture2, [find_output, stub_status(true)]) do
      result = verifier.send(:list_ssh_subdir, :ssh_server,
                             "mo@example.test:/data/mo", "orig")
      assert_equal({ "123.jpg" => 456, "124.jpg" => 789 }, result)
    end
  end

  def test_list_ssh_subdir_logs_and_returns_empty_on_failure
    messages = []
    verifier = Image::Processor::Verifier.new { |msg| messages << msg }

    Open3.stub(:capture2, ["", stub_status(false)]) do
      result = verifier.send(:list_ssh_subdir, :ssh_server,
                             "mo@example.test:/data/mo", "orig")
      assert_equal({}, result)
    end

    assert_includes(
      messages, "Failed to list mo@example.test:/data/mo/orig on ssh_server"
    )
  end

  private

  def stub_status(success)
    status = Object.new
    status.define_singleton_method(:success?) { success }
    status
  end

  def seed_local_files(turned_over, commercial, disconnected)
    File.write("#{local_root}/orig/#{turned_over}.tiff", "A")
    File.write("#{local_root}/orig/#{turned_over}.jpg", "AB")
    File.write("#{local_root}/960/#{turned_over}.jpg", "ABC")
    File.write("#{local_root}/640/#{turned_over}.jpg", "ABCD")
    File.write("#{local_root}/320/#{turned_over}.jpg", "ABCDE")
    File.write("#{local_root}/960/#{commercial}.jpg", "ABCDEF")
    File.write("#{local_root}/640/#{commercial}.jpg", "ABCDEFG")
    File.write("#{local_root}/320/#{commercial}.jpg", "ABCDEFGH")
    File.write("#{local_root}/960/#{disconnected}.jpg", "ABCDEFGHI")
    File.write("#{local_root}/640/#{disconnected}.jpg", "ABCDEFGHIJ")
    File.write("#{local_root}/320/#{disconnected}.jpg", "ABCDEFGHIJK")
  end

  def seed_remote1_files(in_situ, turned_over, commercial, disconnected)
    root = remote_server_path(1)
    File.write("#{root}/960/#{in_situ}.jpg", "correct")
    File.write("#{root}/640/#{in_situ}.jpg", "correct")
    File.write("#{root}/320/#{in_situ}.jpg", "correct")
    File.write("#{root}/960/#{turned_over}.jpg", "ABC")
    File.write("#{root}/640/#{turned_over}.jpg", "ABCD")
    File.write("#{root}/320/#{turned_over}.jpg", "ABCDE")
    File.write("#{root}/960/#{commercial}.jpg", "ABCDEF")
    File.write("#{root}/640/#{commercial}.jpg", "ABCDEFG")
    File.write("#{root}/320/#{commercial}.jpg", "ABCDEFGH")
    File.write("#{root}/960/#{disconnected}.jpg", "allcorrupted!")
    File.write("#{root}/640/#{disconnected}.jpg", "allcorrupted!")
    File.write("#{root}/320/#{disconnected}.jpg", "allcorrupted!")
  end

  def seed_remote2_files(in_situ, turned_over, commercial)
    root = remote_server_path(2)
    File.write("#{root}/640/#{in_situ}.jpg", "correct")
    File.write("#{root}/320/#{in_situ}.jpg", "correct")
    File.write("#{root}/640/#{turned_over}.jpg", "ABCD")
    File.write("#{root}/320/#{turned_over}.jpg", "ABCDE")
    File.write("#{root}/640/#{commercial}.jpg", "allcorrupted!")
    File.write("#{root}/320/#{commercial}.jpg", "allcorrupted!")
  end

  def assert_uploads(result, turned_over, commercial, disconnected)
    expected = [
      [:remote1, "320/#{disconnected}.jpg"],
      [:remote2, "320/#{commercial}.jpg"],
      [:remote2, "320/#{disconnected}.jpg"],
      [:remote1, "640/#{disconnected}.jpg"],
      [:remote2, "640/#{commercial}.jpg"],
      [:remote2, "640/#{disconnected}.jpg"],
      [:remote1, "960/#{disconnected}.jpg"],
      [:remote1, "orig/#{turned_over}.jpg"],
      [:remote1, "orig/#{turned_over}.tiff"]
    ]
    expected.each { |entry| assert_includes(result[:uploaded], entry) }
    assert_equal(expected.size, result[:uploaded].size)

    assert_equal("ABCDEFGHIJK",
                 File.read("#{remote_server_path(1)}/320/#{disconnected}.jpg"))
    assert_equal("ABCDEFGH",
                 File.read("#{remote_server_path(2)}/320/#{commercial}.jpg"))
    assert_equal("AB",
                 File.read("#{remote_server_path(1)}/orig/#{turned_over}.jpg"))
    assert_equal(
      "A", File.read("#{remote_server_path(1)}/orig/#{turned_over}.tiff")
    )
  end

  def assert_deletes(result, turned_over, commercial)
    expected = ["640/#{turned_over}.jpg", "960/#{turned_over}.jpg",
                "960/#{commercial}.jpg"]
    expected.each { |path| assert_includes(result[:deleted], path) }
    assert_equal(expected.size, result[:deleted].size)
    expected.each do |path|
      assert_not(File.exist?("#{local_root}/#{path}"), "#{path} should be gone")
    end

    # "small" (320) is in MO.keep_these_image_sizes_local -- never deleted,
    # even though it's fully synced everywhere relevant.
    assert_path_exists("#{local_root}/320/#{turned_over}.jpg")
    # 640/commercial mismatches on remote2 -- not eligible for deletion.
    assert_path_exists("#{local_root}/640/#{commercial}.jpg")
  end
end
