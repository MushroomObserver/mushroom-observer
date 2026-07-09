# frozen_string_literal: true

# Perceptual hash (64-bit dHash) per iNat photo, computed from the photo's
# medium rendition by script/hash_inat_photos.rb (#4585). Kept separate from
# inat_obs_extracts.photos so hashes survive extract refetches and can be
# looked up directly by photo id (the same id external_links.external_id
# stores for imported images' provenance).
class CreateInatPhotoHashes < ActiveRecord::Migration[7.2]
  def change
    create_table(:inat_photo_hashes) do |t|
      t.bigint(:inat_photo_id, null: false)
      t.column(:dhash, :bigint, unsigned: true, null: false)
      t.datetime(:fetched_at, null: false)
      t.timestamps
      t.index(:inat_photo_id, unique: true)
      t.index(:dhash)
    end
  end
end
