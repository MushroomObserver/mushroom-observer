#!/usr/bin/env ruby
# frozen_string_literal: true

#  USAGE::
#
#    # Step 1 (dev box): Run
#    rails runner script/backfill_mycoportal_export_links.rb --apply
#
#    # Step 2 (read the links from the database and writes a CSV file)
#    bin/rails runner script/transfer_mycoportal_export_links.rb \
#      --export mycoportal_export_links.csv
#
#    # Step 3 Transfer the CSV to production. Example:
#    scp tmp/mycoportal_dwca/mycoportal_export_links.csv \
#      your_username@mushroomobserver.org:/path/on/production/
#
#    # Step 4 (production): Apply the transferred CSV:
#    # (reads the CSV and creates any missing rows in the production DB)
#    rails runner script/transfer_mycoportal_export_links.rb \
#      --apply mycoportal_export_links.csv
#
#  DESCRIPTION::
#
#    Moves ExternalLink (relationship: :export) rows created by
#    backfill_mycoportal_export_links.rb from a dev box to production
#    without running that script's DwC-A parse (~300MB of CSVs) against
#    the production DB.
#
#    --export dumps every local ExternalLink(external_site: mycoportal,
#    relationship: :export) row as CSV (target_type, target_id,
#    external_id, external_created_on).
#
#    --apply reads that CSV and creates any rows missing on production,
#    owned by User.admin. Existing rows (same target_type/target_id/
#    external_site/relationship key the backfill script itself uses to
#    detect "already present") are left untouched and counted as
#    already_present. Idempotent and resumable -- re-running the same
#    CSV is harmless. Lookups are batched (BATCH rows/query) and new
#    rows are validated in memory, then written with a single insert_all
#    per batch rather than one ExternalLink.create! per row (#4877
#    review) -- keeps production DB round trips to a handful per BATCH
#    instead of one per row.

require "optparse"
require "csv"

class TransferMycoportalExportLinks
  BATCH = 2000
  TARGET_CLASSES = { "Observation" => Observation, "Image" => Image }.freeze

  class << self
    def parse_argv(argv)
      options = {}
      OptionParser.new do |opts|
        opts.on("--export FILE", "Write target_type,target_id," \
                                 "external_id,external_created_on CSV " \
                                 "of local export links") do |f|
          options[:export] = f
        end
        opts.on("--apply FILE",
                "Apply CSV (creates missing rows only)") do |f|
          options[:apply] = f
        end
      end.parse!(argv)
      raise("Unrecognized argument(s): #{argv.join(" ")}") if argv.any?

      options
    end
  end

  def initialize(opts)
    @export = opts[:export]
    @apply = opts[:apply]
    abort("Give exactly one of --export FILE or --apply FILE") unless
      @export.nil? ^ @apply.nil?
    @site = ExternalSite.mycoportal
    @admin = User.admin
    @stats = Hash.new(0)
  end

  def run
    @export ? run_export : run_apply
  end

  private

  def run_export
    count = 0
    CSV.open(@export, "w") do |csv|
      csv << %w[target_type target_id external_id external_created_on]
      local_links.find_each do |link|
        csv << [link.target_type, link.target_id, link.external_id,
                link.external_created_on]
        count += 1
      end
    end
    puts("Exported #{count} MyCoPortal export links to #{@export}")
  end

  def local_links
    ExternalLink.where(external_site: @site, relationship: :export)
  end

  def run_apply
    rows = CSV.read(@apply, headers: true).map { |row| parse_row(row) }
    puts("Applying #{rows.length} MyCoPortal export links...")
    rows.each_slice(BATCH) { |batch| apply_batch(batch) }
    summarize
  end

  def parse_row(row)
    { target_type: row["target_type"], target_id: row["target_id"].to_i,
      external_id: row["external_id"].presence,
      external_created_on: row["external_created_on"].presence }
  end

  def apply_batch(batch)
    existing = existing_keys(batch)
    candidates = batch.reject { |row| existing.include?(row_key(row)) }
    @stats[:already_present] += batch.size - candidates.size
    return if candidates.empty?

    valid, invalid = build_links(candidates).partition(&:valid?)
    invalid.each { |link| log_invalid(link) }
    insert_links(valid)
  end

  # Includes external_id (the MCP occid) in the key -- a target can
  # legitimately carry more than one export link when it's attached to
  # multiple distinct MCP occurrence records (#4819 follow-up), so
  # dedup can't collapse down to [target_type, target_id] alone.
  def row_key(row)
    [row[:target_type], row[:target_id], row[:external_id]]
  end

  def ids_by_type(rows)
    rows.group_by { |row| row[:target_type] }.
      transform_values { |type_rows| type_rows.map { |row| row[:target_id] } }
  end

  # One batched query per target_type present in the batch, rather than
  # one exists? query per row -- keeps production round trips low.
  def existing_keys(batch)
    ids_by_type(batch).each_with_object(Set.new) do |(type, ids), keys|
      ExternalLink.where(target_type: type, target_id: ids,
                         external_site: @site, relationship: :export).
        pluck(:target_type, :target_id, :external_id).
        each { |key| keys << key }
    end
  end

  # Loads the real target records (not just ids), one query per
  # target_type in the batch, so #build_link can cache each row's target
  # directly on the association below -- otherwise #valid?'s
  # target-presence check would issue its own query per row, right back
  # to the per-row cost this batching is meant to avoid.
  def preload_targets(candidates)
    ids_by_type(candidates).each_with_object({}) do |(type, ids), targets|
      klass = TARGET_CLASSES[type]
      targets[type] = klass ? klass.where(id: ids).index_by(&:id) : {}
    end
  end

  def build_links(candidates)
    targets = preload_targets(candidates)
    candidates.map { |row| build_link(row, targets) }
  end

  def build_link(row, targets)
    link = ExternalLink.new(
      target_type: row[:target_type], target_id: row[:target_id],
      user: @admin, external_site: @site, relationship: :export,
      external_id: row[:external_id],
      external_created_on: row[:external_created_on]
    )
    target_association = link.association(:target)
    target_association.target =
      targets.dig(row[:target_type], row[:target_id])
    target_association.loaded!
    link
  end

  def log_invalid(link)
    warn("  #{link.target_type} #{link.target_id}: " \
         "#{link.errors.full_messages.join(", ")}")
    @stats[:invalid] += 1
  end

  def insert_links(links)
    return if links.empty?

    now = Time.current
    rows = links.map { |link| insert_attributes(link, now) }
    ExternalLink.insert_all(rows)
    @stats[:created] += rows.size
  end

  def insert_attributes(link, now)
    { user_id: @admin.id, target_type: link.target_type,
      target_id: link.target_id, external_site_id: @site.id,
      relationship: ExternalLink.relationships[:export],
      external_id: link.external_id,
      external_created_on: link.external_created_on,
      created_at: now, updated_at: now }
  end

  def summarize
    totals = @stats.sort.map { |k, v| "#{k}: #{v}" }.join(", ")
    puts("Totals: #{totals}")
  end
end

if $PROGRAM_NAME == __FILE__
  TransferMycoportalExportLinks.new(
    TransferMycoportalExportLinks.parse_argv(ARGV)
  ).run
end
