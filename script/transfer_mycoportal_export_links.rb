#!/usr/bin/env ruby
# frozen_string_literal: true

#  USAGE::
#
#    # Phase 1 (dev box): after running
#    # backfill_mycoportal_export_links.rb with APPLY=1 locally, export
#    # the resulting links:
#    bin/rails runner script/transfer_mycoportal_export_links.rb \
#      --export mycoportal_export_links.csv
#
#    # Transfer the CSV to production, then apply it there:
#    bin/rails runner script/transfer_mycoportal_export_links.rb \
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
#    CSV is harmless. Lookups and inserts are batched (BATCH rows/query)
#    to keep production DB load low.

require "optparse"
require "csv"

class TransferMycoportalExportLinks
  BATCH = 2000

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
    batch.each { |row| apply_one(row, existing) }
  end

  # One batched query per target_type present in the batch, rather than
  # one exists? query per row -- keeps production round trips low.
  def existing_keys(batch)
    batch.group_by { |row| row[:target_type] }.
      each_with_object(Set.new) do |(type, rows), keys|
        ids = rows.map { |row| row[:target_id] }
        ExternalLink.where(target_type: type, target_id: ids,
                           external_site: @site, relationship: :export).
          pluck(:target_type, :target_id).each { |key| keys << key }
      end
  end

  def apply_one(row, existing)
    key = [row[:target_type], row[:target_id]]
    return @stats[:already_present] += 1 if existing.include?(key)

    create_link(row)
  end

  def create_link(row)
    ExternalLink.create!(
      user: @admin, target_type: row[:target_type],
      target_id: row[:target_id], external_site: @site,
      relationship: :export, external_id: row[:external_id],
      external_created_on: row[:external_created_on]
    )
    @stats[:created] += 1
  rescue ActiveRecord::RecordInvalid => e
    warn("  #{row[:target_type]} #{row[:target_id]}: #{e.message}")
    @stats[:invalid] += 1
  end

  def summarize
    puts("Totals: #{@stats.sort.map { |k, v| "#{k}: #{v}" }.join(", ")}")
  end
end

if $PROGRAM_NAME == __FILE__
  TransferMycoportalExportLinks.new(
    TransferMycoportalExportLinks.parse_argv(ARGV)
  ).run
end
