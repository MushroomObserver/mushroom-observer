# frozen_string_literal: true

class Inat
  class ReflectionResync
    # Mirrors an iNat observation's photos onto its reflection (#4215).
    # Each imported image records its iNat photo id on an import
    # ExternalLink, so photos and images match by id:
    #
    #   - a photo no longer on iNat, or one that lost its license on
    #     someone else's observation, is removed: the image is destroyed,
    #     unless another observation, glossary term or profile uses it,
    #     in which case it is only detached from the reflection and
    #     reported;
    #   - a kept photo's license and copyright holder follow iNat;
    #   - a new photo is imported by Inat::PhotoImporter, under the same
    #     rules as the importer;
    #   - the thumbnail follows iNat's first photo, unless it points at an
    #     image that isn't one of this observation's iNat photos.
    #
    # "Someone else's observation" means the importer's inat_username
    # doesn't match the iNat observer; an importer with no inat_username
    # (a super importer) counts as someone else.
    class ImageSync
      # Same photo at MO's and iNat's resolutions measures 0-5; burst shots
      # of one specimen can measure as low as 2, so a match says "one of
      # this observation's photos", not which one.
      DHASH_MATCH_DISTANCE = 5

      Outcome = Data.define(:added, :removed, :updated, :thumbnail_changed,
                            :alerts) do
        def changed?
          added.positive? || removed.positive? || logs_resync?
        end

        # Changes Image's callbacks don't log on the observation.
        def logs_resync?
          updated.positive? || thumbnail_changed
        end
      end

      def initialize(dhash_for: ->(url) { Image::Dhash.from_url(url) })
        @dhash_for = dhash_for
      end

      def call(obs, inat_obs)
        start(obs, inat_obs)
        remove_dropped_images
        update_kept_images
        add_new_photos
        sync_thumbnail
        Outcome.new(added: @added, removed: @removed, updated: @updated,
                    thumbnail_changed: @thumbnail_changed, alerts: @alerts)
      end

      private

      def start(obs, inat_obs)
        @obs = obs
        @site = ReflectionResync.inat_link(obs).external_site
        @photos = inat_obs[:observation_photos].to_a.
                  sort_by { |photo| photo[:position].to_i }.
                  map { |photo| Inat::ObsPhoto.new(photo) }
        @importer = Inat::PhotoImporter.new(
          observation: obs, user: obs.user, owner: owner?(inat_obs),
          external_site: @site
        )
        @added = @removed = @updated = 0
        @thumbnail_changed = false
        @alerts = []
      end

      def owner?(inat_obs)
        login = @obs.user.inat_username.to_s
        login.present? && login.casecmp?(inat_obs[:user].to_h[:login].to_s)
      end

      # {iNat photo id (String) => Image} for the reflection's images.
      def linked_images
        @obs.images.includes(:external_links).each_with_object({}) do |img, h|
          link = img.external_links.find do |l|
            l.import? && l.external_site_id == @site.id
          end
          h[link.external_id.to_s] = img if link
        end
      end

      def photos_by_id
        @photos.index_by { |photo| photo.external_id.to_s }
      end

      def remove_dropped_images
        photos = photos_by_id
        linked_images.each do |photo_id, image|
          photo = photos[photo_id]
          next if photo && @importer.license_id_for(photo)

          remove_image(image, photo_id)
        end
      end

      def remove_image(image, photo_id)
        @removed += 1
        return destroy_image(image) unless used_elsewhere?(image)

        @obs.remove_image(image)
        @alerts << "image #{image.id} (iNat photo #{photo_id}) is gone " \
                   "or unlicensed at iNat but used elsewhere on MO; " \
                   "detached from the reflection, not destroyed"
      end

      # Image#update_thumbnails (before_destroy) refills every
      # observation whose thumbnail pointed at it.
      def destroy_image(image)
        image.current_user = User.admin
        image.log_destroy
        image.destroy!
      end

      def used_elsewhere?(image)
        ObservationImage.where(image_id: image.id).
          where.not(observation_id: @obs.id).exists? ||
          GlossaryTermImage.where(image_id: image.id).exists? ||
          GlossaryTerm.where(thumb_image_id: image.id).exists? ||
          User.where(image_id: image.id).exists?
      end

      # Image#track_copyright_changes records each change, attributed to
      # the image's current_user.
      def update_kept_images
        photos = photos_by_id
        linked_images.each do |photo_id, image|
          attrs = source_attributes(photos[photo_id])
          next if attrs.all? { |key, value| image[key] == value }

          image.current_user = User.admin
          image.update!(attrs)
          @updated += 1
        end
      end

      def source_attributes(photo)
        { license_id: @importer.license_id_for(photo),
          copyright_holder: Inat::PhotoImporter.copyright_holder(photo) }
      end

      def add_new_photos
        linked = linked_images
        @photos.reject { |photo| linked.key?(photo.external_id.to_s) }.
          each { |photo| import_photo(photo) }
        created = @importer.created_image_ids
        @added = created.size
        TransferImagesJob.perform_later(image_ids: created) if created.any?
      end

      def import_photo(photo)
        @importer.import(photo)
      rescue StandardError => e
        @alerts << "iNat photo #{photo.external_id} not imported: " \
                   "#{e.message}"
      end

      def sync_thumbnail
        @obs.reload
        target = first_photo_image
        current = @obs.thumb_image_id
        return if target.nil? || current == target.id
        return if current && !inat_image?(current)

        set_thumbnail(current, target)
      end

      def first_photo_image
        linked = linked_images
        @photos.lazy.filter_map { |p| linked[p.external_id.to_s] }.first
      end

      # Moves the reflection, and any occurrence member sharing its old
      # thumbnail, to the new one.
      def set_thumbnail(current, target)
        now = Time.zone.now
        @obs.update_columns(thumb_image_id: target.id, updated_at: now)
        if current && @obs.occurrence_id
          Observation.where(occurrence_id: @obs.occurrence_id,
                            thumb_image_id: current).
            where.not(id: @obs.id).
            update_all(thumb_image_id: target.id, updated_at: now)
        end
        @thumbnail_changed = true
      end

      # One of this observation's iNat photos: linked by photo id, or --
      # for an image with no link -- a dhash match. An image not attached
      # to the reflection is not its photo.
      def inat_image?(image_id)
        image = @obs.images.find { |img| img.id == image_id }
        return false unless image
        return true if linked_images.value?(image)

        dhash_match?(image)
      end

      def dhash_match?(image)
        return false unless image.dhash

        @photos.any? do |photo|
          hash = @dhash_for.call(photo.medium_url)
          Image::Dhash.distance(image.dhash, hash) <= DHASH_MATCH_DISTANCE
        rescue StandardError => e
          @alerts << "iNat photo #{photo.external_id} not hashed: " \
                     "#{e.message}"
          false
        end
      end
    end
  end
end
