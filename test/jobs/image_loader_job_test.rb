# frozen_string_literal: true

require("test_helper")

# Mock classes to simulate google cloud storage objects.
class MockStorage
  def initialize
    @buckets = {}
  end

  def bucket(name)
    @buckets[name] ||= MockBucket.new
  end
end

class MockBucket
  def initialize
    @files = {}
  end

  def file(path)
    @files[path] ||= MockFile.new
  end
end

class MockFile
  def download(path)
    # Simulate file download by creating a test file
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, "mock file content")
  end
end

class ImageLoaderJobTest < ActiveJob::TestCase
  include GeneralExtensions

  def setup
    super
    @mock_storage = MockStorage.new
    @test_image = Image.reorder(created_at: :asc).first
    @test_file = "#{download_dir}/#{@test_image.id}.jpg"
    FileUtils.rm_rf(download_dir)
  end

  # Worker-specific download directory for parallel testing
  def download_dir
    @download_dir ||= if (worker_num = database_worker_number)
                        Rails.root.join("tmp/downloads-#{worker_num}")
                      else
                        Rails.root.join("tmp/downloads")
                      end
  end

  def with_stubs(&block)
    Google::Cloud::Storage.stub(:new, @mock_storage) do
      MO.stub(:local_original_image_cache_path, download_dir, &block)
    end
  end

  def teardown
    FileUtils.rm_rf(download_dir)
  end

  test "image download works" do
    rolf_count = users(:rolf).original_image_quota
    admin_count = User.admin.original_image_quota
    with_stubs do
      ImageLoaderJob.perform_now(@test_image.id, users(:rolf).id)
      assert(File.exist?(@test_file))
      assert_equal(rolf_count + 1, users(:rolf).reload.original_image_quota)
      assert_equal(admin_count + 1, User.admin.reload.original_image_quota)
    end
  end

  test "image already there" do
    FileUtils.mkdir_p(File.dirname(@test_file))
    File.write(@test_file, "already cached")
    with_stubs do
      ImageLoaderJob.perform_now(@test_image.id, users(:rolf).id)
      assert_equal("already cached", File.read(@test_file))
    end
  end

  test "image download fails" do
    with_stubs do
      MockBucket.stub(:new, -> { raise("test") }) do
        ImageLoaderJob.perform_now(@test_image.id, users(:rolf).id)
        assert_not(File.exist?(@test_file))
      end
    end
  end
end
