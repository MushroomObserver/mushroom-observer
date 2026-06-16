# frozen_string_literal: true

# Structured per-image import provenance (#4529). Records the source and
# the source-system photo id for imported images, mirroring the
# observations.source_id / external_id pair. Replaces the fragile use of
# images.original_name to carry the iNat photo id — API2::ImageAPI nulls
# original_name out for users whose keep_filenames preference is "toss",
# which dropped provenance on ~87% of imported images.
class AddSourceProvenanceToImages < ActiveRecord::Migration[7.2]
  def change
    change_table(:images, bulk: true) do |t|
      t.bigint(:source_id)
      t.string(:external_id, limit: 64)
      t.index([:source_id, :external_id])
    end
  end
end
