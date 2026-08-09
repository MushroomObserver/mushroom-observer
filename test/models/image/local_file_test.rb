# frozen_string_literal: true

require("test_helper")

class Image::LocalFileTest < UnitTestCase
  URL = Struct.new(:url)

  def test_resolves_a_file_url_when_the_file_exists
    Tempfile.create(["local_file", ".jpg"]) do |file|
      assert_equal(file.path,
                   Image::LocalFile.path_from_url(
                     URL.new("file://#{file.path}?123")
                   ))
    end
  end

  def test_nil_for_a_file_url_with_nothing_behind_it
    assert_nil(Image::LocalFile.path_from_url(
                 URL.new("file:///no/such/file.jpg")
               ))
  end

  def test_nil_for_a_remote_url
    assert_nil(Image::LocalFile.path_from_url(
                 URL.new("https://images.mushroomobserver.org/1280/1.jpg")
               ))
  end

  # The local source's `read` spec is a web path, mapped onto
  # MO.local_image_files.
  def test_web_path_maps_onto_local_image_files
    sources = MO.image_sources.deep_dup
    sources[:local] ||= {}
    sources[:local][:read] = "/images"
    with_image_sources(sources) do
      FileUtils.mkdir_p(File.join(MO.local_image_files, "1280"))
      path = File.join(MO.local_image_files, "1280", "42.jpg")
      FileUtils.touch(path)

      assert_equal(path,
                   Image::LocalFile.path_from_url(URL.new("/images/1280/42.jpg?7")))
      assert_nil(Image::LocalFile.path_from_url(URL.new("/elsewhere/42.jpg")),
                 "a web path outside the local read prefix is not ours")
    ensure
      FileUtils.rm_f(path)
    end
  end

  # Exercises the image_url plumbing end to end. Writes the file it
  # expects to find rather than asserting on the ambient filesystem --
  # other tests (image uploads, the Gemini adapter's) leave files
  # behind the very URL this image resolves to, so "no file there"
  # depends on test order.
  def test_path_resolves_through_image_url
    image = images(:in_situ_image)
    resolved = image.image_url(:huge).url.sub(/\?\d+\z/, "")
    expected = Image::LocalFile.file_url_path(resolved) ||
               Image::LocalFile.web_path_on_disk(resolved)

    assert(expected.present?, "premise: test env resolves images locally")

    FileUtils.mkdir_p(File.dirname(expected))
    File.binwrite(expected, "jpegbytes")

    assert_equal(expected, Image::LocalFile.path(image, :huge))
  ensure
    FileUtils.rm_f(expected) if expected
  end

  private

  # MO.image_sources reads through IMAGE_CONFIG_DATA, so stub the
  # reader itself rather than assigning config.
  def with_image_sources(sources, &block)
    MO.stub(:image_sources, sources, &block)
  end
end
