# frozen_string_literal: true

require("test_helper")

# The upload rules shared by the importer and the resync's image engine.
class Inat::PhotoImporterTest < UnitTestCase
  FakeAPI2Response = Struct.new(:errors, :results)
  FakePhoto = Struct.new(:copyright_holder)

  def setup
    @obs = observations(:minimal_unknown_obs)
    @user = users(:rolf)
    @image = images(:in_situ_image)
  end

  def test_copyright_holder_drops_all_rights_reserved
    assert_equal("(c) cactusdan,", holder("(c) cactusdan, all rights reserved"))
    assert_equal(
      "(c) jo_bone, , uploaded by jo_bone",
      holder("(c) jo_bone, all rights reserved, uploaded by jo_bone")
    )
    attribution = "(c) Tim C., some rights reserved (CC BY-NC)"
    assert_equal(attribution, holder(attribution),
                 "a licensed attribution is left as is")
    assert_equal(255, holder("x" * 300).length,
                 "copyright_holder is capped at 255 chars")
  end

  def test_license_id_for_follows_the_import_rules
    licensed = photo(license_code: "cc-by-nc")
    unlicensed = photo(license_code: nil)

    assert_equal(licensed.license_id,
                 importer(owner: false).license_id_for(licensed))
    assert_equal(@user.license_id,
                 importer(owner: true).license_id_for(unlicensed),
                 "the importer's default license for their observation")
    assert_nil(importer(owner: false).license_id_for(unlicensed),
               "someone else's unlicensed photo is not importable")
  end

  def test_import_skips_unimportable_photos
    importer = importer(owner: false)

    API2.stub(:execute, ->(_) { flunk("should not upload") }) do
      assert_nil(importer.import(photo(license_code: nil)))
    end
    assert_equal(1, importer.skipped_images)
    assert_empty(importer.created_image_ids)
  end

  # created_image_ids is what the import job and the resync read to
  # enqueue TransferImagesJob.
  def test_import_uploads_and_records_the_photo_id
    importer = importer(owner: false)
    sent = nil

    result = API2.stub(:execute, lambda { |params|
      sent = params
      FakeAPI2Response.new([], [@image])
    }) do
      importer.import(photo(license_code: "cc-by", id: 987_654))
    end

    assert_equal(@image, result)
    assert_equal([@image.id], importer.created_image_ids)
    assert_equal(@obs.id, sent[:observations])
    assert_not_nil(
      ExternalLink.find_by(target: @image, external_id: "987654",
                           relationship: :import),
      "the image records its iNat photo id"
    )
  end

  # A photo link that can't be saved is logged; the upload still counts.
  def test_import_logs_a_rejected_photo_link
    ExternalLink.create!(user: @user, target: @image,
                         external_site: external_sites(:inaturalist),
                         external_id: "555", relationship: :import)
    logged = nil

    result = Rails.logger.stub(:warn, ->(msg) { logged = msg }) do
      API2.stub(:execute, ->(_) { FakeAPI2Response.new([], [@image]) }) do
        importer(owner: false).import(photo(license_code: "cc-by", id: 555))
      end
    end

    assert_equal(@image, result)
    assert_match(/failed to create ExternalLink for Image #{@image.id}/,
                 logged)
  end

  def test_import_recreates_a_missing_api_key
    APIKey.where(user: @user, notes: Inat::Constants::MO_API_KEY_NOTES).
      delete_all
    sent = nil

    API2.stub(:execute, lambda { |params|
      sent = params
      FakeAPI2Response.new([], [@image])
    }) do
      importer(owner: false).import(photo(license_code: "cc-by"))
    end

    key = APIKey.find_by(user: @user, notes: Inat::Constants::MO_API_KEY_NOTES)
    assert_not_nil(key)
    assert_equal(key.key, sent[:api_key])
  end

  def test_import_raises_a_descriptive_error_on_api_failure
    error = API2::MissingParameter.new(:upload_url)
    calls = 0

    err = API2.stub(:execute, lambda { |_|
      calls += 1
      FakeAPI2Response.new([error], nil)
    }) do
      assert_raises(RuntimeError) do
        importer(owner: false).import(photo(license_code: "cc-by", id: 377))
      end
    end

    assert_match(/Failed to import image 377/, err.message)
    assert_match(/#{Regexp.escape(error.to_s)}/, err.message)
    assert_equal(1, calls, "a non-download error is not retried")
  end

  # AWS/S3 is occasionally unavailable for a moment (#5183).
  def test_import_retries_a_transient_download_failure
    responses = [FakeAPI2Response.new([download_error], nil),
                 FakeAPI2Response.new([download_error], nil),
                 FakeAPI2Response.new([], [@image])]
    importer, warnings = quiet_importer

    result = API2.stub(:execute, ->(_) { responses.shift }) do
      importer.import(photo(license_code: "cc-by"))
    end

    assert_equal(@image, result)
    assert_equal(2, warnings.size, "one warning per retry")
  end

  def test_import_raises_after_exhausting_retries
    importer, warnings = quiet_importer
    calls = 0

    API2.stub(:execute, lambda { |_|
      calls += 1
      FakeAPI2Response.new([download_error], nil)
    }) do
      assert_raises(RuntimeError) do
        importer.import(photo(license_code: "cc-by"))
      end
    end

    retries = Inat::PhotoImporter::MAX_UPLOAD_RETRIES
    assert_equal(retries, warnings.size)
    assert_equal(retries + 1, calls)
  end

  private

  def holder(attribution)
    Inat::PhotoImporter.copyright_holder(FakePhoto.new(attribution))
  end

  def importer(owner:)
    Inat::PhotoImporter.new(observation: @obs, user: @user, owner: owner,
                            external_site: external_sites(:inaturalist))
  end

  # An importer whose backoff doesn't sleep or print; returns
  # [importer, warnings].
  def quiet_importer
    importer = importer(owner: false)
    warnings = []
    importer.define_singleton_method(:sleep) { |*| nil }
    importer.define_singleton_method(:warn) { |msg| warnings << msg }
    [importer, warnings]
  end

  def photo(license_code:, id: 377_332_865)
    Inat::ObsPhoto.new(
      photo_id: id,
      photo: { id: id, license_code: license_code,
               attribution: "(c) someone, some rights reserved",
               url: "https://inaturalist-open-data.s3.amazonaws.com/" \
                    "photos/#{id}/square.jpeg" }
    )
  end

  def download_error
    API2::CouldntDownloadURL.new(
      "https://inaturalist-open-data.s3.amazonaws.com/photos/1/original.jpeg",
      StandardError.new("simulated S3 outage")
    )
  end
end
