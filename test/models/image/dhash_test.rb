# frozen_string_literal: true

require("test_helper")

class Image::DhashTest < UnitTestCase
  FIXTURE = Rails.root.join("test/images/Coprinus_comatus.jpg").to_s

  def setup
    return if system("command -v convert >/dev/null 2>&1")

    skip("ImageMagick `convert` not available")
  end

  def test_from_file_is_stable
    hash = Image::Dhash.from_file(FIXTURE)

    assert_kind_of(Integer, hash)
    assert_operator(hash, :>, 0)
    assert_equal(hash, Image::Dhash.from_file(FIXTURE))
  end

  def test_resolution_invariance
    hash = Image::Dhash.from_file(FIXTURE)

    Tempfile.create(["small", ".jpg"]) do |file|
      system("convert", FIXTURE, "-resize", "240x240", file.path)
      resized = Image::Dhash.from_file(file.path)

      assert_operator(Image::Dhash.distance(hash, resized), :<=, 2)
    end
  end

  def test_different_images_differ
    hash_a = Image::Dhash.from_file(FIXTURE)
    hash_b = Image::Dhash.from_file(
      Rails.root.join("test/images/geotagged.jpg").to_s
    )

    assert_operator(Image::Dhash.distance(hash_a, hash_b), :>, 5)
  end

  def test_distance
    assert_equal(0, Image::Dhash.distance(0b1010, 0b1010))
    assert_equal(2, Image::Dhash.distance(0b1010, 0b0110))
    assert_equal(64, Image::Dhash.distance(0, (2**64) - 1))
  end

  def test_min_distance
    assert_equal(0, Image::Dhash.min_distance(0b1010, [0b0000, 0b1010]))
    assert_equal(1, Image::Dhash.min_distance(0b1010, [0b1110, 0b0000]))
    # A bare hash is treated as a one-element candidate set.
    assert_equal(2, Image::Dhash.min_distance(0b1010, 0b0110))
  end

  def test_rotation_invariant_matching
    # A 90-degree-rotated copy does not match the original directly...
    original = Image::Dhash.from_file(FIXTURE)
    rotated = Image::Dhash.from_file(FIXTURE, rotate: 90)

    assert_operator(Image::Dhash.distance(original, rotated), :>, 5)

    # ...but matches the original's four-rotation set (rotating back).
    set = Image::Dhash::ROTATIONS.map do |deg|
      Image::Dhash.from_file(FIXTURE, rotate: deg)
    end

    assert_equal(0, Image::Dhash.min_distance(rotated, set))
  end

  def test_from_file_error
    assert_raises(Image::Dhash::Error) do
      Image::Dhash.from_file("no_such_file.jpg")
    end
  end

  def test_from_url_fetches_and_hashes
    url = "https://images.example.org/photo.jpg"
    stub_request(:get, url).
      to_return(status: 200, body: File.binread(FIXTURE))

    assert_equal(Image::Dhash.from_file(FIXTURE), Image::Dhash.from_url(url))
  end
end
