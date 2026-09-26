# frozen_string_literal: true

require("test_helper")

# Uploading by URL is the one place that knows both the host MO asked and
# the bytes it returned, which is what an external site's media budget is
# measured in (#5416).
class API2::UploadsTest < UnitTestCase
  INAT_URL = "https://inaturalist-open-data.s3.amazonaws.com/photos/1/" \
             "original.jpeg"

  def setup
    super
    @site = external_sites(:inaturalist)
  end

  def stub_photo(url, bytes)
    stub_request(:get, url).to_return(
      body: "x" * bytes, status: 200,
      headers: { "Content-Length" => bytes.to_s,
                 "Content-Type" => "image/jpeg" }
    )
  end

  def upload(url)
    up = API2::Uploads::UploadFromURL.new(url)
    up.clean_up
    up
  end

  def test_counts_media_downloaded_from_inat
    stub_photo(INAT_URL, 4_096)

    upload(INAT_URL)

    assert_equal(4_096, ExternalSiteUsage.media_bytes_since(@site, 1.hour))
  end

  def test_accumulates_across_photos
    stub_photo(INAT_URL, 1_000)
    other = "https://static.inaturalist.org/photos/2/original.jpeg"
    stub_photo(other, 2_000)

    upload(INAT_URL)
    upload(other)

    assert_equal(3_000, ExternalSiteUsage.media_bytes_since(@site, 1.hour))
  end

  # MO uploads by URL from elsewhere too, and those count against nobody.
  def test_ignores_an_upload_from_an_untracked_host
    url = "https://example.org/photo.jpg"
    stub_photo(url, 8_192)

    upload(url)

    assert_empty(ExternalSiteUsage.all)
  end

  # Accounting is bookkeeping; an upload must still succeed without it.
  def test_an_accounting_failure_does_not_break_the_upload
    stub_photo(INAT_URL, 512)

    ExternalSiteUsage.stub(:record_media, ->(*) { raise("boom") }) do
      assert_equal(512, upload(INAT_URL).content_length)
    end
  end

  def test_a_download_failure_still_raises_its_own_error
    stub_request(:get, INAT_URL).to_return(status: 500)

    assert_raises(API2::CouldntDownloadURL) { upload(INAT_URL) }
  end
end
