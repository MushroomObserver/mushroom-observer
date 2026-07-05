# frozen_string_literal: true

# Perceptual hash (Image::Dhash) of one iNat photo, keyed by the iNat photo
# id (#4585). Computed from the photo's medium rendition by
# script/hash_inat_photos.rb and matched against MO images' dhashes to
# establish image identity across resolution differences. Kept separate from
# inat_obs_extracts.photos so hashes survive extract refetches.
class InatPhotoHash < ApplicationRecord
  validates :inat_photo_id, presence: true,
                            uniqueness: true
  validates :dhash, presence: true
  validates :fetched_at, presence: true
end
