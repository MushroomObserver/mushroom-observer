# frozen_string_literal: true

require_relative "../config/environment"

# Ensure that images imported from iNat have a unique original_name.
# The goal is enabling effiiccent syncing updating of Observations.
# Images imported on or after the cutoff time have the desired original_name.
# This is a one-time backfill operation for images imported before the cutoff.
# The script can be deleted after the backfill is complete.
# This script is intended to be run in the Rails console.
# Usage:
# load "/Users/joe/mushroom-observer/scripts/backfill_inat_img_orig_fname.rb"

class BackfillInatImgOrigFname
  CUTOFF = Time.new(2024, 12, 13, 15, 3, 37, "-08:00")

  def self.run
    obss = Observation.where(source: "mo_inat_import").
           where(Observation[:created_at].lt(CUTOFF))

    obss.each do |obs|
      # potential images to fix
      imgs_to_fix = obs.images.where(Image[:notes] =~ /Imported from iNat /).
                    where(original_name: nil)
      next if imgs_to_fix.empty?

      # corresponding iNat photos
      @photos = inat_photos(obs.inat_id)
      next if @photos.empty?

      # NOTE: The order of imgs_to_fix and @photos is the same because the
      # MO images were created in the same order as the iNat photos.
      imgs_to_fix.each_with_index do |img, index|
        id = @photos[index]["photo_id"]
        uuid = @photos[index]["uuid"]
        img.update(original_name: "iNat photo_id: #{id}, uuid: #{uuid}")
      end
    end
  end

  # iNat photos for an iNat observation
  def self.inat_photos(inat_id)
    sleep(1) # comply with iNat API rate limits
    response = RestClient::Request.execute(
      method: :get,
      url: "https://api.inaturalist.org/v1/observations/#{inat_id}"
    )
    JSON.parse(response.body).
      # account for possibility that iNat obs or its photos have been deleted
      dig("results", 0, "observation_photos")
  end
end

BackfillInatImgOrigFname.run
