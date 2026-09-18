# frozen_string_literal: true

class Inat
  class MoObservationBuilder
    # Uploads each iNat observation photo as an MO Image through
    # Inat::PhotoImporter, and collects its counts for end-of-import
    # reporting. Mixed into MoObservationBuilder.
    module ImageHandling
      private

      def add_inat_images(inat_obs_photos)
        importer = Inat::PhotoImporter.new(
          observation: @observation, user: user, owner: !@import_others,
          external_site: @external_site
        )
        inat_obs_photos.each do |obs_photo|
          importer.import(Inat::ObsPhoto.new(obs_photo))
        end
        @created_image_ids.concat(importer.created_image_ids)
        @skipped_images += importer.skipped_images
      end
    end
  end
end
