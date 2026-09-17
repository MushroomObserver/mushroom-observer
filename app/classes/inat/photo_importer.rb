# frozen_string_literal: true

class Inat
  # Uploads iNat observation photos as MO Images attached to an
  # observation. Shared by the importer and the resync's image engine
  # (#4215), so both apply the same rules:
  #
  #   - a licensed photo keeps its iNat license;
  #   - an unlicensed photo on an iNat observation the importer made gets
  #     the importer's default MO license;
  #   - an unlicensed photo on someone else's observation is skipped.
  #
  # Each created image records its iNat photo id on an import
  # ExternalLink, which is how the resync matches it later (#4529).
  class PhotoImporter
    MAX_UPLOAD_RETRIES = 3       # per image, on transient download failure
    UPLOAD_RETRY_BASE_SLEEP = 2  # seconds; doubles each retry (2, 4, 8)

    attr_reader :created_image_ids, :skipped_images

    # A photo's copyright holder as MO stores it: imported images all get
    # a license, so iNat's "all rights reserved" is dropped.
    def self.copyright_holder(photo)
      photo.copyright_holder.sub("all rights reserved", "").strip.
        truncate(255)
    end

    # owner: whether the importer made the iNat observation.
    def initialize(observation:, user:, owner:,
                   external_site: ExternalSite.inaturalist)
      @observation = observation
      @user = user
      @owner = owner
      @external_site = external_site
      @created_image_ids = []
      @skipped_images = 0
    end

    # The MO license an image of this photo should carry, or nil when the
    # photo is not importable.
    def license_id_for(photo)
      return photo.license_id if photo.license_code.present?

      @owner ? @user.license_id : nil
    end

    # The created Image, or nil when the photo was skipped. Raises when
    # the upload fails after retries.
    def import(photo)
      license_id = license_id_for(photo)
      unless license_id
        @skipped_images += 1
        return nil
      end

      image = upload(upload_params(photo, license_id), photo.external_id)
      record_provenance(image, photo)
      image
    end

    private

    # external_id identifies which iNat photo failed, since an
    # observation can have several.
    def upload(params, external_id, attempt: 1)
      api = API2.execute(params)
      return finish_upload(api) if api.errors.empty?

      retry_or_raise(api, params, external_id, attempt)
    end

    def finish_upload(api)
      image = api.results.first
      @created_image_ids << image.id
      image
    end

    # AWS/S3 is occasionally unavailable for a moment (#5183); retry a
    # download failure before giving up on the photo.
    def retry_or_raise(api, params, external_id, attempt)
      if retryable?(api.errors) && attempt <= MAX_UPLOAD_RETRIES
        backoff(external_id, attempt)
        return upload(params, external_id, attempt: attempt + 1)
      end

      raise("Failed to import image #{external_id}: " \
            "#{api.errors.join(", ")}")
    end

    def retryable?(errors)
      errors.any?(API2::CouldntDownloadURL)
    end

    def backoff(external_id, attempt)
      seconds = UPLOAD_RETRY_BASE_SLEEP * (2**(attempt - 1))
      warn("  iNat image #{external_id} download failed; " \
           "retry #{attempt}/#{MAX_UPLOAD_RETRIES} in #{seconds}s")
      sleep(seconds)
    end

    # Recorded on the image so it survives regardless of the uploader's
    # `keep_filenames` preference, which the Image API applies to the
    # filename-bearing `original_name`.
    def record_provenance(image, photo)
      ExternalLink.create!(
        user: @user, target: image, external_site: @external_site,
        external_id: photo.external_id, relationship: :import
      )
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.warn(
        "InatImport: failed to create ExternalLink for Image #{image.id} " \
        "(iNat #{photo.external_id}): #{e.message}"
      )
    end

    def upload_params(photo, license_id)
      {
        method: :post,
        action: :image,
        api_key: api_key,
        upload_url: photo.url,
        notes: photo.notes,
        copyright_holder: self.class.copyright_holder(photo),
        license: license_id,
        observations: @observation.id
      }
    end

    # The key the import controller creates; recreated if it was deleted
    # since, so a resync can still upload.
    def api_key
      notes = Inat::Constants::MO_API_KEY_NOTES
      (APIKey.find_by(user: @user, notes: notes) ||
        APIKey.create!(user: @user, notes: notes)).key
    end
  end
end
