# frozen_string_literal: true

# index_external_links_on_target (target_type, target_id) became a
# leftmost prefix of the unique
# index_external_links_on_target_and_site_and_extid (target_type,
# target_id, external_site_id, external_id) when that index was added,
# so the optimizer can no longer prefer it. It still costs a write on
# every insert and a rebuild in every ALTER against this table --
# 20261014140000 issued five of those, each one rebuilding 526MB of
# index over 2.1M rows.
#
# Dropping an index is metadata only: 0.02s, no table rebuild.
class DropRedundantExternalLinksTargetIndex < ActiveRecord::Migration[7.2]
  def up
    remove_index(:external_links, name: "index_external_links_on_target")
  end

  def down
    add_index(:external_links, [:target_type, :target_id],
              name: "index_external_links_on_target")
  end
end
