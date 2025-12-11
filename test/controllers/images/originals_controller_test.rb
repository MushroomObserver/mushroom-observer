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

# tests of Images controller
module Images
  class OriginalsControllerTest < FunctionalTestCase
    def setup
      super
      @mock_storage = MockStorage.new
      @test_image = Image.reorder(created_at: :asc).first
      @test_file = "#{download_dir}/#{@test_image.id}.jpg"
      @id_cutoff = @test_image.id + 1
      FileUtils.rm_rf(download_dir)
    end

    # Worker-specific download directory for parallel testing
    def download_dir
      @download_dir ||= begin
        if (worker_num = database_worker_number)
          Rails.root.join("tmp/downloads-#{worker_num}")
        else
          Rails.root.join("tmp/downloads")
        end
      end
    end

    def database_worker_number
      return nil unless ActiveRecord::Base.connected?

      db_name = ActiveRecord::Base.connection_db_config.configuration_hash[:database]
      match = db_name.to_s.match(/-(\d+)$/)
      match ? match[1] : nil
    rescue
      nil
    end

    def with_stubs(&block)
      stub_request(:post, "https://oauth2.googleapis.com/token").
        to_return(status: 200, body: "", headers: {})

      Google::Cloud::Storage.stub(:new, @mock_storage) do
        MO.stub(:local_original_image_cache_path, download_dir) do
          MO.stub(:next_image_id_to_go_to_cloud, @id_cutoff, &block)
        end
      end
    end

    def teardown
      FileUtils.rm_rf(download_dir)
    end

    def test_normal_html_request
      login("rolf")
      with_stubs do
        count = OriginalImageRequest.count
        get(:show, params: { id: @test_image.id })
        assert_redirected_to(@test_image.cached_original_url)
        assert_equal(count + 1, OriginalImageRequest.count)
      end
    end

    def test_normal_json_request
      login("rolf")
      assert_false(File.exist?(@test_file))
      with_stubs do
        count = OriginalImageRequest.count
        get(:show, format: :json, params: { id: @test_image.id })
        json = @response.parsed_body
        assert_equal("loading", json["status"])
        assert_not_nil(assigns(:job))
        assigns(:job).perform_now
        assert_true(File.exist?(@test_file))
        assert_equal(count + 1, OriginalImageRequest.count)
      end
    end

    def test_not_logged_in
      with_stubs do
        count = OriginalImageRequest.count
        get(:show, format: :json, params: { id: @test_image.id })
        json = @response.parsed_body
        assert_equal("ready", json["status"])
        assert_equal(@test_image.url(:huge), json["url"])
        assert_nil(assigns(:job))
        assert_equal(count + 1, OriginalImageRequest.count)
      end
    end

    def test_image_doesnt_exist
      login("rolf")
      @test_image.destroy
      with_stubs do
        count = OriginalImageRequest.count
        assert_raises(RuntimeError) do
          get(:show, format: :json, params: { id: @test_image.id })
        end
        assert_equal(count, OriginalImageRequest.count)
      end
    end

    def test_not_on_image_server
      login("rolf")
      assert_false(File.exist?(@test_file))
      @id_cutoff = 0
      with_stubs do
        count = OriginalImageRequest.count
        get(:show, format: :json, params: { id: @test_image.id })
        json = @response.parsed_body
        assert_equal("ready", json["status"])
        assert_equal(@test_image.original_url, json["url"])
        assert_nil(assigns(:job))
        assert_equal(count + 1, OriginalImageRequest.count)
      end
    end

    def test_already_cached
      login("rolf")
      FileUtils.mkdir_p(File.dirname(@test_file))
      File.write(@test_file, "test")
      assert_true(File.exist?(@test_file))
      with_stubs do
        get(:show, format: :json, params: { id: @test_image.id })
        json = @response.parsed_body
        assert_equal("ready", json["status"])
        assert_equal(@test_image.cached_original_url, json["url"])
        assert_nil(assigns(:job))
      end
    end

    def test_already_queued
      assert_false(File.exist?(@test_file))
      with_stubs do
        login("rolf")
        get(:show, format: :json, params: { id: @test_image.id })
        json = @response.parsed_body
        assert_equal("loading", json["status"])
        assert_not_nil(assigns(:job))

        login("mary")
        get(:show, format: :json, params: { id: @test_image.id })
        json = @response.parsed_body
        assert_equal("loading", json["status"])
        assert_nil(assigns(:job))
      end
    end

    def test_user_maxed_out
      login("rolf")
      User.current.update(original_image_quota: MO.original_image_user_quota)
      with_stubs do
        get(:show, format: :json, params: { id: @test_image.id })
        json = @response.parsed_body
        assert_equal("maxed_out", json["status"])
        assert_nil(assigns(:job))

        User.current.decrement!(:original_image_quota)
        get(:show, format: :json, params: { id: @test_image.id })
        json = @response.parsed_body
        assert_equal("loading", json["status"])
        assert_not_nil(assigns(:job))
      end
    end

    def test_site_maxed_out
      login("rolf")
      User.admin.update(original_image_quota: MO.original_image_site_quota)
      with_stubs do
        get(:show, format: :json, params: { id: @test_image.id })
        json = @response.parsed_body
        assert_equal("maxed_out", json["status"])
        assert_nil(assigns(:job))

        User.admin.decrement!(:original_image_quota)
        get(:show, format: :json, params: { id: @test_image.id })
        json = @response.parsed_body
        assert_equal("loading", json["status"])
        assert_not_nil(assigns(:job))
      end
    end
  end
end
