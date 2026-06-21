# frozen_string_literal: true

# Backfill the polymorphic ExternalLink relationship model from the legacy
# Source FK (#4299, phase-1 data migration). Run after the additive migration
# and before the phase-2 drop migration.
#
# For each (Source -> matching ExternalSite by name):
#   - Observations with source_id: upgrade an existing cross_reference link
#     for the same (obs, site) to import in place (the "redundant iNat link"
#     fix), then create import links for any observation that lacks one.
#   - Images with source_id AND a non-blank external_id (the iNat photo id):
#     create an import link (target = the image). Images with source_id but
#     no external_id can't form a useful import link (no id to sync against,
#     the #4529 provenance gap) — they're skipped and counted.
#
# All writes are set-based SQL (one statement per category), not per-row, and
# guarded by NOT EXISTS / relationship checks so re-running is idempotent.
# The import URL is derived (ExternalSite#observation_url), so no url is set.
#
# Dry run by default (prints the row counts each statement WOULD affect);
# set APPLY=1 to execute:
#   bin/rails runner script/backfill_external_links_from_sources.rb
#   APPLY=1 bin/rails runner script/backfill_external_links_from_sources.rb

# Run context: DB connection, apply flag, the INSERT column list, and tallies.
Ctx = Struct.new(:conn, :apply, :cols, :stats) do
  def run_or_count(label, count_sql, dml_sql)
    stats[label] =
      apply ? conn.exec_update(dml_sql) : conn.select_value(count_sql).to_i
  end

  def count(label, sql)
    stats[label] = conn.select_value(sql).to_i
  end
end

def upgrade_obs_links(ctx, src, site)
  join = "external_links el JOIN observations o " \
         "ON o.id = el.target_id AND el.target_type = 'Observation'"
  # Only upgrade when the obs has a real external_id — an import link must be
  # syncable/dedupable by id (mirrors the create path's filter).
  where = "o.source_id = #{src.id} AND el.external_site_id = #{site.id} " \
          "AND el.relationship = 0 AND o.external_id IS NOT NULL " \
          "AND o.external_id <> ''"
  ctx.run_or_count(
    :obs_link_upgraded,
    "SELECT COUNT(*) FROM #{join} WHERE #{where}",
    "UPDATE #{join} SET el.relationship = 1, el.external_id = o.external_id, " \
    "el.updated_at = NOW() WHERE #{where}"
  )
end

def create_obs_links(ctx, src, site)
  where = "o.source_id = #{src.id} AND o.external_id IS NOT NULL " \
          "AND o.external_id <> '' AND NOT EXISTS (SELECT 1 FROM " \
          "external_links el WHERE el.target_type = 'Observation' " \
          "AND el.target_id = o.id AND el.external_site_id = #{site.id})"
  select = "SELECT o.user_id, o.id, 'Observation', #{site.id}, " \
           "o.external_id, 1, NOW(), NOW() FROM observations o WHERE #{where}"
  ctx.run_or_count(
    :obs_link_created,
    "SELECT COUNT(*) FROM observations o WHERE #{where}",
    "INSERT INTO external_links #{ctx.cols} #{select}"
  )
end

def create_image_links(ctx, src, site)
  where = "i.source_id = #{src.id} AND i.external_id IS NOT NULL " \
          "AND i.external_id <> '' AND NOT EXISTS (SELECT 1 FROM " \
          "external_links el WHERE el.target_type = 'Image' " \
          "AND el.target_id = i.id AND el.relationship = 1)"
  select = "SELECT i.user_id, i.id, 'Image', #{site.id}, i.external_id, " \
           "1, NOW(), NOW() FROM images i WHERE #{where}"
  ctx.run_or_count(
    :image_link_created,
    "SELECT COUNT(*) FROM images i WHERE #{where}",
    "INSERT INTO external_links #{ctx.cols} #{select}"
  )
  ctx.count(
    :image_skipped_no_external_id,
    "SELECT COUNT(*) FROM images i WHERE i.source_id = #{src.id} " \
    "AND (i.external_id IS NULL OR i.external_id = '')"
  )
end

ctx = Ctx.new(
  ActiveRecord::Base.connection,
  ENV["APPLY"] == "1",
  "(user_id, target_id, target_type, external_site_id, external_id, " \
  "relationship, created_at, updated_at)",
  Hash.new(0)
)

sites_by_name = ExternalSite.all.index_by { |s| s.name.downcase }
mapping = {}
Source.find_each do |src|
  site = sites_by_name[src.name.downcase]
  mapping[src.name] = site&.name
  next unless site

  upgrade_obs_links(ctx, src, site)
  create_obs_links(ctx, src, site)
  create_image_links(ctx, src, site)
end

puts("Source -> ExternalSite map: #{mapping.inspect}")
puts
puts("== summary#{" (dry run — rows that WOULD change)" unless ctx.apply} ==")
ctx.stats.sort.each { |k, v| puts("  #{k}: #{v}") }
puts
puts(ctx.apply ? "APPLIED." : "Dry run. Re-run with APPLY=1 to write.")
