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
end
