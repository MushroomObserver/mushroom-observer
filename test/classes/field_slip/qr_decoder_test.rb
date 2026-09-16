# frozen_string_literal: true

require("test_helper")

class FieldSlip::QRDecoderTest < UnitTestCase
  # ---------- what counts as a slip code ----------

  # A bare code is believed only when its prefix names a project: photos
  # contain all kinds of QR codes, and the prefix separates a slip from
  # noise. (open_membership_project's prefix is OPEN.)
  def test_bare_code_with_a_known_project_prefix
    assert_equal("OPEN-0219", FieldSlip::QRDecoder.slip_code_from("open-0219"))
  end

  def test_bare_code_with_an_unknown_prefix_is_noise
    assert_nil(FieldSlip::QRDecoder.slip_code_from("2099-XYZ-0001"))
  end

  def test_mo_qr_urls_are_explicit_enough_on_their_own
    assert_equal("NEMF-10222",
                 FieldSlip::QRDecoder.slip_code_from(
                   "https://mushroomobserver.org/qr/nemf-10222"
                 ))
    assert_nil(FieldSlip::QRDecoder.slip_code_from(
                 "https://example.com/qr/OPEN-0219"
               ),
               "someone else's /qr/ URL is not MO's")
  end

  # MO's own /qr/ URLs can carry query params (AddDispatchController
  # appends ?project=...); the code is the path segment alone.
  def test_mo_qr_url_query_params_are_not_part_of_the_code
    assert_equal("OPEN-0219",
                 FieldSlip::QRDecoder.slip_code_from(
                   "https://mushroomobserver.org/qr/OPEN-0219?project=405"
                 ))
    assert_equal("OPEN-0219",
                 FieldSlip::QRDecoder.slip_code_from(
                   "https://mushroomobserver.org/qr/OPEN-0219#top"
                 ))
  end

  def test_noise_is_rejected
    assert_nil(FieldSlip::QRDecoder.slip_code_from("WIFI:T:WPA;S:cafe;;"))
    assert_nil(FieldSlip::QRDecoder.slip_code_from("12345"),
               "all digits fails FieldSlip's own code validation")
    assert_nil(FieldSlip::QRDecoder.slip_code_from(""))
    assert_nil(FieldSlip::QRDecoder.slip_code_from("a" * 40))
  end

  # ---------- the pipeline ----------

  def test_slip_code_in_reads_the_first_recognizable_code
    FieldSlip::QRDecoder.stub(:available?, true) do
      Image::LocalFile.stub(:path, "/tmp/fake.jpg") do
        FieldSlip::QRDecoder.stub(:scan,
                                  ["https://example.com", "OPEN-0219"]) do
          assert_equal("OPEN-0219",
                       FieldSlip::QRDecoder.slip_code_in(images(:in_situ_image)))
        end
      end
    end
  end

  def test_slip_code_in_nil_when_detection_is_unavailable
    FieldSlip::QRDecoder.stub(:available?, false) do
      assert_nil(FieldSlip::QRDecoder.slip_code_in(images(:in_situ_image)))
    end
  end

  # The test env resolves image URLs to file:// -- nothing local and
  # nothing fetchable means nil, with no fetch attempted.
  def test_slip_code_in_nil_without_a_local_file
    FieldSlip::QRDecoder.stub(:available?, true) do
      Image::LocalFile.stub(:path, nil) do
        assert_nil(FieldSlip::QRDecoder.slip_code_in(images(:in_situ_image)))
      end
    end
  end

  # A local copy can vanish within seconds of upload (transfer to the
  # image server can outrun the scan); the size gets fetched from the
  # image server instead.
  def test_fetches_a_no_longer_local_size_from_the_image_server
    image = images(:in_situ_image)
    file = Tempfile.new(["qr", ".jpg"])
    file.binmode
    file.write("jpegbytes")
    file.rewind
    response = Struct.new(:file).new(file)
    fake_url = Struct.new(:url).new("https://images.example.com/1280/1.jpg")

    FieldSlip::QRDecoder.stub(:available?, true) do
      FieldSlip::QRDecoder.stub(:local_file, nil) do
        image.stub(:image_url, fake_url) do
          RestClient::Request.stub(:execute, response) do
            FieldSlip::QRDecoder.stub(:scan, ["OPEN-0219"]) do
              assert_equal("OPEN-0219",
                           FieldSlip::QRDecoder.slip_code_in(image))
            end
          end
        end
      end
    end
  end

  # An archived original is gone from the image server deliberately;
  # the fetch 404s and the scan counts it as a miss, never reaching
  # into the archive.
  def test_a_failed_fetch_is_a_miss_not_an_error
    image = images(:in_situ_image)
    fake_url = Struct.new(:url).new("https://images.example.com/orig/1.jpg")
    raise_404 = ->(*) { raise(RestClient::NotFound) }

    FieldSlip::QRDecoder.stub(:available?, true) do
      FieldSlip::QRDecoder.stub(:local_file, nil) do
        image.stub(:image_url, fake_url) do
          RestClient::Request.stub(:execute, raise_404) do
            assert_nil(FieldSlip::QRDecoder.slip_code_in(image))
          end
        end
      end
    end
  end

  # Production resolves a transferred image's URL to the image server,
  # so the URL-based lookup goes nil within a second of upload -- but
  # the file is still on this machine's disk, and the direct path
  # finds it.
  def test_falls_back_to_the_direct_disk_path_when_the_url_goes_remote
    image = images(:in_situ_image)
    path = image.full_filepath(:full_size)
    FileUtils.mkdir_p(File.dirname(path))
    File.binwrite(path, "jpegbytes")

    FieldSlip::QRDecoder.stub(:available?, true) do
      Image::LocalFile.stub(:path, nil) do
        FieldSlip::QRDecoder.stub(:scan, ["OPEN-0219"]) do
          assert_equal("OPEN-0219",
                       FieldSlip::QRDecoder.slip_code_in(image))
        end
      end
    end
  ensure
    FileUtils.rm_f(path)
  end

  # A slip printed in light gray (the NAMA 2026 template) reads as
  # blank paper to zbar's binarizer -- every raw pass misses, and the
  # contrast-enhanced retry is what finds the code.
  def test_enhanced_pass_rescues_a_low_contrast_slip
    FieldSlip::QRDecoder.stub(:available?, true) do
      Image::LocalFile.stub(:path, "/tmp/fake.jpg") do
        FieldSlip::QRDecoder.stub(:scan, []) do
          FieldSlip::QRDecoder.stub(:enhanced_scan, ["OPEN-0219"]) do
            assert_equal("OPEN-0219",
                         FieldSlip::QRDecoder.slip_code_in(
                           images(:in_situ_image)
                         ))
          end
        end
      end
    end
  end

  # Without ImageMagick there is no enhanced pass -- a miss, not an
  # error.
  def test_enhanced_scan_empty_without_imagemagick
    FieldSlip::QRDecoder.stub(:magick_binary, nil) do
      assert_empty(FieldSlip::QRDecoder.enhanced_scan("/x.jpg"))
    end
  end

  # The enhanced pass converts into a tempfile and scans that; a
  # failed conversion is a miss, not an error.
  def test_enhanced_scan_scans_the_converted_tempfile
    ok = Struct.new(:success?).new(true)
    FieldSlip::QRDecoder.stub(:magick_binary, "magick") do
      Open3.stub(:capture3, ["", "", ok]) do
        FieldSlip::QRDecoder.stub(:scan, ["OPEN-0219"]) do
          assert_equal(["OPEN-0219"],
                       FieldSlip::QRDecoder.enhanced_scan("/x.jpg"))
        end
      end
    end
  end

  def test_enhanced_scan_empty_when_conversion_fails
    failed = Struct.new(:success?).new(false)
    FieldSlip::QRDecoder.stub(:magick_binary, "magick") do
      Open3.stub(:capture3, ["", "boom", failed]) do
        assert_empty(FieldSlip::QRDecoder.enhanced_scan("/x.jpg"))
      end
    end
  end

  # Probes for IMv7's `magick`, then IMv6's `convert`; memoized, nil
  # when neither exists. Runs the real probe (whichever binaries this
  # machine has), then pins the memoization.
  def test_magick_binary_probes_and_memoizes
    if FieldSlip::QRDecoder.instance_variable_defined?(:@magick_binary)
      FieldSlip::QRDecoder.remove_instance_variable(:@magick_binary)
    end

    probed = FieldSlip::QRDecoder.magick_binary

    assert_includes(["magick", "convert", nil], probed)
    assert_equal(probed, FieldSlip::QRDecoder.magick_binary)
  end

  # ---------- zbarimg plumbing ----------

  def test_scan_parses_zbar_output
    ok = Struct.new(:success?).new(true)
    Open3.stub(:capture3, ["OPEN-1\nOPEN-2\n\n", "", ok]) do
      assert_equal(%w[OPEN-1 OPEN-2], FieldSlip::QRDecoder.scan("/x.jpg"))
    end
  end

  # zbarimg exits nonzero when it finds no symbols; that is an empty
  # answer, not an error.
  def test_scan_empty_when_zbar_finds_nothing
    none = Struct.new(:success?).new(false)
    Open3.stub(:capture3, ["", "", none]) do
      assert_empty(FieldSlip::QRDecoder.scan("/x.jpg"))
    end
  end

  # The config flag gates detection regardless of the binary (it is off
  # in the test environment, so nothing here depends on zbar being
  # installed).
  def test_available_requires_the_config_flag
    assert_not(FieldSlip::QRDecoder.available?)
    assert_includes([true, false], FieldSlip::QRDecoder.zbarimg?)
  end

  # ---------- reading: slip code + QR presence ----------

  def stub_reading(codes)
    FieldSlip::QRDecoder.stub(:available?, true) do
      Image::LocalFile.stub(:path, "/tmp/fake.jpg") do
        FieldSlip::QRDecoder.stub(:scan, codes) do
          FieldSlip::QRDecoder.reading(images(:in_situ_image))
        end
      end
    end
  end

  def test_reading_returns_the_slip_code_and_qr_presence
    read = stub_reading(["https://example.com", "OPEN-0219"])

    assert_equal("OPEN-0219", read.slip_code)
    assert(read.qr_present)
  end

  # A QR whose payload is not a slip code (a DNA-sticker code, a
  # product label): no slip code, but a QR is present -- the signal
  # that drives the model-read fallback.
  def test_reading_flags_a_qr_that_is_not_a_slip_code
    read = stub_reading(["2099-XYZ-0001"])

    assert_nil(read.slip_code)
    assert(read.qr_present)
  end

  def test_reading_reports_no_qr_when_nothing_decodes
    read = stub_reading([])

    assert_nil(read.slip_code)
    assert_not(read.qr_present)
  end
end
