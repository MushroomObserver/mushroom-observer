# frozen_string_literal: true

# The importer's any-relationship duplicate gate looks links up by
# (external_site_id, target_type, external_id). The existing
# index_external_links_on_site_rel_target_extid has `relationship` second,
# so that lookup can only use its first column — a large per-observation
# scan across ~360k iNaturalist links. Index the exact lookup.
class AddSiteTargetExtidIndexToExternalLinks < ActiveRecord::Migration[7.2]
  def change
    add_index(:external_links, [:external_site_id, :target_type, :external_id],
              name: "index_external_links_on_site_target_extid")
  end
end
