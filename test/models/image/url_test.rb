# frozen_string_literal: true

require("test_helper")

# See test/models/image_test.rb, the
# test_url_placeholder_for_untransferred_missing_images test, for the
# pre-existing placeholder-fallback coverage this builds on.
class Image::URLTest < UnitTestCase
  def local_root
    if (worker_num = database_worker_number)
      Rails.public_path.join("test_images-#{worker_num}").to_s
    else
      Rails.public_path.join("test_images").to_s
    end
  end

  def setup
    FileUtils.mkpath("#{local_root}/orig")
    FileUtils.mkpath("#{local_root}/640")
    super
  end

  def teardown
    FileUtils.rm_rf("#{local_root}/orig")
    FileUtils.rm_rf("#{local_root}/640")
    super
  end

  def args(id)
    { id: id, transferred: false, extension: "jpg", original_extension: "jpg",
      original_fallback_allowed: true }
  end

  def test_serves_original_instead_of_placeholder_when_available
    id = 555_001
    File.write("#{local_root}/orig/#{id}.jpg", "original bytes")

    url = Image::URL.new(args(id).merge(size: :medium))

    assert_equal("/test_images/orig/#{id}.jpg", url.url.sub(/-\d+/, ""))
  end

  def test_no_fallback_when_original_extension_not_browser_safe
    id = 555_002
    File.write("#{local_root}/orig/#{id}.tiff", "original bytes")

    url = Image::URL.new(
      args(id).merge(size: :medium, original_extension: "tiff")
    )

    assert_not_includes(url.url, "orig/#{id}.tiff")
  end

  def test_no_fallback_when_not_allowed
    id = 555_003
    File.write("#{local_root}/orig/#{id}.jpg", "original bytes")

    url = Image::URL.new(
      args(id).merge(size: :medium, original_fallback_allowed: false)
    )

    assert_not_includes(url.url, "orig/#{id}.jpg")
  end

  def test_no_fallback_for_full_size_itself
    id = 555_004
    # No local orig file, and :remote1's transferred_flag test also fails --
    # the normal source_order has nothing to find. serve_original_instead?
    # must not try to serve full_size "as its own fallback" (size !=
    # :full_size guards this), so this must resolve via the ordinary
    # fallback_source path, not recurse into `original`.
    url = Image::URL.new(args(id).merge(size: :full_size))

    assert_equal(url.source_url(:remote1), url.url)
  end

  def test_no_fallback_when_original_missing_locally_either
    id = 555_005

    url = Image::URL.new(args(id).merge(size: :medium))

    assert_not_includes(url.url, "orig/#{id}.jpg")
  end

  def test_falls_back_to_real_size_when_it_actually_exists
    id = 555_006
    File.write("#{local_root}/orig/#{id}.jpg", "original bytes")
    File.write("#{local_root}/640/#{id}.jpg", "medium bytes")

    url = Image::URL.new(args(id).merge(size: :medium))

    assert_equal("/test_images/640/#{id}.jpg", url.url.sub(/-\d+/, ""))
  end

  def test_original_fallback_allowed_lazy_proc_only_called_when_reached
    id = 555_007
    File.write("#{local_root}/orig/#{id}.jpg", "original bytes")
    File.write("#{local_root}/640/#{id}.jpg", "medium bytes")
    called = false

    url = Image::URL.new(
      args(id).merge(size: :medium, original_fallback_allowed: lambda {
        called = true
      })
    )
    url.url

    assert_not(called, "should not evaluate the gate when the normal " \
                        "source_order already succeeded")
  end

  def test_source_exists_raises_for_invalid_spec
    url = Image::URL.new(args(555_008).merge(size: :medium))

    url.stub(:format_spec, "weird://foo") do
      assert_raises(RuntimeError) { url.source_exists?(:remote1) }
    end
  end

  def test_source_exists_true_when_remote_http_head_returns_200
    url = Image::URL.new(args(555_009).merge(size: :medium))
    fake_response = Object.new
    fake_response.define_singleton_method(:code) { "200" }
    fake_http = Object.new
    fake_http.define_singleton_method(:request_head) { |_path| fake_response }

    url.stub(:format_spec, "https://example.test/orig/1.jpg") do
      Net::HTTP.stub(:new, fake_http) do
        assert(url.source_exists?(:remote1))
      end
    end
  end

  def test_source_exists_false_when_remote_http_head_returns_non_200
    url = Image::URL.new(args(555_010).merge(size: :medium))
    fake_response = Object.new
    fake_response.define_singleton_method(:code) { "404" }
    fake_http = Object.new
    fake_http.define_singleton_method(:request_head) { |_path| fake_response }

    url.stub(:format_spec, "https://example.test/orig/1.jpg") do
      Net::HTTP.stub(:new, fake_http) do
        assert_not(url.source_exists?(:remote1))
      end
    end
  end
end
