# frozen_string_literal: true

# Perceptual hash (64-bit dHash) for content-based image identity across
# resolution/recompression differences (#4585 reflection resolution, #4673
# duplicate detection). Null until computed; populated at upload going
# forward and backfilled by script/backfill_image_dhashes.rb for images in
# comparison scope. The index serves exact-duplicate lookup; near-duplicate
# (Hamming distance) search necessarily scans candidates.
class AddDhashToImages < ActiveRecord::Migration[7.2]
  def change
    change_table(:images, bulk: true) do |t|
      t.column(:dhash, :bigint, unsigned: true)
      t.index(:dhash)
    end
  end
end
