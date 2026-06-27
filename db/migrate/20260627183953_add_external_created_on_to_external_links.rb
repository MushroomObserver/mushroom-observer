# frozen_string_literal: true

# Creation date of the *external* record (e.g. the iNaturalist observation)
# this link points to. Captured when materializing iNat correspondences so the
# observation page can show when the relationship arose (see
# ExternalLink#relationship_date). Nullable: links whose external record's date
# is unknown (imports, legacy manual cross-refs) fall back to created_at.
class AddExternalCreatedOnToExternalLinks < ActiveRecord::Migration[7.2]
  def change
    add_column(:external_links, :external_created_on, :date)
  end
end
