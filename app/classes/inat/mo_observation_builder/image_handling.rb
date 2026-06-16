# frozen_string_literal: true

class Inat
  class MoObservationBuilder
    # Uploads each iNat observation photo as an MO Image (applying the
    # user's default license to unlicensed own-observation photos, skipping
    # unlicensed others'-observation photos) and records structured import
    # provenance — source + iNat photo id — directly on the created image.
    # Mixed into MoObservationBuilder.
    module ImageHandling
      private

      def add_inat_images(inat_obs_photos)
        inat_obs_photos.each do |obs_photo|
          photo = Inat::ObsPhoto.new(obs_photo)
          image = create_inat_image(photo)
          record_image_provenance(image, photo) if image
        end
      end

      def create_inat_image(photo)
        if photo.license_code.blank?
          handle_unlicensed_image(photo)
        else
          upload_inat_image(post_photo_params(photo))
        end
      end

      # Own-observation imports: apply user's default MO license.
      # Others' observations: skip and count for end-of-import reporting.
      def handle_unlicensed_image(photo)
        if @import_others
          @skipped_images += 1
          nil
        else
          upload_inat_image(post_photo_params(photo, license: @user.license_id))
        end
      end

      def upload_inat_image(params)
        API2.execute(params).results.first
      end

      # Recorded directly on the image so it survives regardless of the
      # uploader's `keep_filenames` preference (which the Image API applies
      # to the filename-bearing `original_name`). See #4529.
      def record_image_provenance(image, photo)
        image.update_columns(source_id: @inat_source.id,
                             external_id: photo.external_id)
      end

      def post_photo_params(photo, license: photo.license_id)
        {
          method: :post,
          action: :image,
          api_key: user_api_key,
          upload_url: photo.url,
          notes: photo.notes,
          copyright_holder: photo.copyright_holder,
          license: license,
          observations: @observation.id
        }
      end
    end
  end
end
