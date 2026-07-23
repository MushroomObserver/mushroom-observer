#!/usr/bin/env ruby
# frozen_string_literal: true

# One-time backfill of ExternalLink (relationship: :export) rows for every
# observations and images already present in MyCoPortal (MCP)
# (Based on a Darwin Core Archive (DwC-A) backup of the MUOB collection)

# The backup must be downloaded manually first (see USAGE below)
# and placed in DEFAULT_DWCA_DIR (tmp/mycoportal_dwca/).

# This script finds the newest such zip and extracts
# occurrences.csv / multimedia.csv
# The extracted CSVs are deleted bye default once the run finishes;
# Pass --keep-csvs to retain them
# Pass --occurrences/--multimedia to skip the zip entirely and use
# already-extracted files instead.
#
# Observations/Images MCP has that don't exist in MO are written to a report,
# bydefault <dwca-dir>/mycoportal_backfill_missing.csv
# pass --missing-out to override.
#
# occurrences.csv's "catalogNumber ("MUOB <id>") is the MO Observation id.
# multimedia.csv's "coreid" joins to occurrences.csv's "id" (occid)
#
# Re-running this script doubles as a reconciliation check:
# in a dry run, a nonzero "would create" count means MCP has images
# MO doesn't think it exported.
#
# USAGE:
#
#   Before running the script, create a backup of the MUOB data and
#   download it to tmp/mycoportal_dwca/
#   using the instructions at
#   https://docs.symbiota.org/Collection_Manager_Guide/Downloading/downloading_copy
#   (The download will have a name like MUOB_backup_2026-07-22_190455_DwC-A.zip
#
#   # Dry run by default
#   bin/rails runner script/backfill_mycoportal_export_links.rb
#
#   # Write to the database (Idempotent)
#   APPLY=1 bin/rails runner script/backfill_mycoportal_export_links.rb
#
#   # Skip the zip, e.g. against a snapshot already on disk:
#   bin/rails runner script/backfill_mycoportal_export_links.rb \
#     --occurrences tmp/MUOB_DwC-A/occurrences.csv \
#     --multimedia tmp/MUOB_DwC-A/multimedia.csv
#
#   # Keep the CSVs instead of deleting them after the run:
#   bin/rails runner script/backfill_mycoportal_export_links.rb --keep-csvs
#
#   # List all options:
#   bin/rails runner script/backfill_mycoportal_export_links.rb -h

require "csv"
require "optparse"
require "fileutils"
require "zip"

class BackfillMycoportalExportLinks
  DEFAULT_DWCA_DIR = Rails.root.join("tmp/mycoportal_dwca").to_s
  ZIP_NAME_GLOB = "MUOB_backup_*_DwC-A.zip"
  BATCH = 2000
  PROGRESS_EVERY = 100_000
  IMAGE_ID_REGEXP = %r{
    \Ahttps://
    (?:images\.mushroomobserver\.org/1280|mushroomobserver\.org/images/1280)
    /(\d+)\.jpg\z
  }x
  CATALOG_NUMBER_REGEXP = /\AMUOB (\d+)\z/

  def initialize(opts)
    @dwca_dir = opts.fetch(:dwca_dir)
    @occurrences_csv = opts[:occurrences]
    @multimedia_csv = opts[:multimedia]
    validate_occurrences_and_multimedia!

    @apply = opts.fetch(:apply)
    @keep_csvs = opts.fetch(:keep_csvs)
    @missing_out = opts.fetch(:missing_out)
    @site = ExternalSite.mycoportal
    @admin = User.admin
    @stats = Hash.new(0)
    @missing = []
    @seen = 0
  end

  def run
    @started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    extract_dwca_zip! unless @occurrences_csv
    @mo_id_by_occid = load_occurrences
    warn("Loaded #{@mo_id_by_occid.size} occurrences " \
         "(site=#{@site.name}, #{@apply ? "APPLY" : "dry run"})")
    each_multimedia_batch { |batch| process_batch(batch) }
    write_reports
    print_summary
  ensure
    cleanup_extracted_files
  end

  # A class method because other scripts define a top-level `parse_options`
  class << self
    def parse_options(argv)
      opts = default_options
      OptionParser.new do |parser|
        parser.banner = "Usage: bin/rails runner " \
                        "script/backfill_mycoportal_export_links.rb"
        add_dwca_options(parser, opts)
        add_missing_out_option(parser, opts)
      end.parse!(argv)
      opts[:missing_out] ||= default_missing_out(opts[:dwca_dir])
      opts
    end

    private

    def default_options
      { apply: ENV["APPLY"] == "1", dwca_dir: DEFAULT_DWCA_DIR,
        occurrences: nil, multimedia: nil,
        keep_csvs: false, missing_out: nil }
    end

    def default_missing_out(dwca_dir)
      File.join(dwca_dir, "mycoportal_backfill_missing.csv")
    end

    def add_missing_out_option(parser, opts)
      parser.on("--missing-out FILE",
                "Missing-image report path (default: " \
                "<dwca-dir>/mycoportal_backfill_missing.csv)") do |val|
        opts[:missing_out] = val
      end
    end

    def add_dwca_options(parser, opts)
      parser.on("--dwca-dir DIR",
                "Where to find the downloaded DwC-A zip and extract it " \
                "(default: #{DEFAULT_DWCA_DIR})") do |val|
        opts[:dwca_dir] = val
      end
      parser.on("--occurrences FILE",
                "Skip the zip; use an already-extracted occurrences.csv " \
                "(requires --multimedia too)") do |val|
        opts[:occurrences] = val
      end
      parser.on("--multimedia FILE",
                "Skip the zip; use an already-extracted multimedia.csv " \
                "(requires --occurrences too)") do |val|
        opts[:multimedia] = val
      end
      parser.on("--keep-csvs",
                "Keep the extracted occurrences.csv/multimedia.csv " \
                "after the run instead of deleting them") do
        opts[:keep_csvs] = true
      end
    end
  end

  private

  def validate_occurrences_and_multimedia!
    return if @occurrences_csv.nil? == @multimedia_csv.nil?

    raise("--occurrences and --multimedia must both be given, or neither")
  end

  # Find the newest manually-downloaded DwC-A zip in @dwca_dir and extract
  # occurrences.csv / multimedia.csv there, populating @occurrences_csv /
  # @multimedia_csv.
  def extract_dwca_zip!
    zip_path = newest_dwca_zip
    warn("Extracting occurrences.csv, multimedia.csv from #{zip_path} ...")
    extract_dwca(zip_path)
    @extracted = true
  end

  def newest_dwca_zip
    candidates = Dir.glob(File.join(@dwca_dir, ZIP_NAME_GLOB))
    if candidates.empty?
      raise("No #{ZIP_NAME_GLOB} found in #{@dwca_dir} -- download a " \
            "DwC-A backup there first (see USAGE at the top of this file)")
    end

    candidates.max_by { |path| File.mtime(path) }
  end

  def extract_dwca(zip_path)
    Zip::File.open(zip_path) do |zip|
      @occurrences_csv = extract_entry(zip, "occurrences.csv")
      @multimedia_csv = extract_entry(zip, "multimedia.csv")
    end
  end

  # Matches by basename, not a fixed path, in case MCP's archive nests
  # these under a subdirectory rather than at the zip root.
  def extract_entry(zip, filename)
    entry = zip.find_entry(filename) ||
            zip.entries.find { |e| File.basename(e.name) == filename }
    raise("#{filename} not found in DwC-A zip") unless entry

    # Entry#extract's first positional arg is the entry's own path
    # *within* destination_directory, not a full destination path
    # Pass destination_directory instead and let
    # entry_path default to entry.name.
    dest = File.join(@dwca_dir, entry.name)
    FileUtils.mkdir_p(File.dirname(dest))
    entry.extract(destination_directory: @dwca_dir) { true }
    dest
  end

  # Remove files extracted in this run, unless --keep-csvs was given.
  def cleanup_extracted_files
    return unless @extracted
    return if @keep_csvs

    FileUtils.rm_f(@occurrences_csv)
    FileUtils.rm_f(@multimedia_csv)
  end

  # occid (occurrences.csv's own "id") -> MO observation id,
  # read from catalogNumber ("MUOB <id>").
  def load_occurrences
    CSV.foreach(@occurrences_csv, headers: true).
      each_with_object({}) do |row, hash|
        match = CATALOG_NUMBER_REGEXP.match(row["catalogNumber"].to_s.strip)
        hash[row["id"]] = match[1].to_i if match
      end
  end

  # stream in batches, never CSV.read the whole file because it's huge.
  def each_multimedia_batch
    batch = []
    CSV.foreach(@multimedia_csv, headers: true) do |row|
      batch << parse_row(row)
      next unless batch.size == BATCH

      yield(batch)
      batch = []
    end
    yield(batch) if batch.any?
  end

  def parse_row(row)
    { occid: row["coreid"], image_id: image_id_from(row["identifier"]),
      # MetadataDate is the closest available proxy for when MCP created
      # this media record -- not a guaranteed creation date, but the best
      # the DwC-A dump exposes.
      metadata_date: row["MetadataDate"].presence }
  end

  def image_id_from(identifier)
    IMAGE_ID_REGEXP.match(identifier.to_s.strip)&.[](1)&.to_i
  end

  def process_batch(batch)
    ids = batch.filter_map { |r| r[:image_id] }
    known_ids = Image.where(id: ids).pluck(:id).to_set
    existing = existing_image_links(ids)
    batch.each { |row| process_row(row, known_ids, existing.to_set) }
    @seen += batch.size
    warn("  #{@seen} images processed") if (@seen % PROGRESS_EVERY).zero?
  end

  # Bumps last_synced_at on already-linked images in this batch, so the
  # field reflects the most recent confirmed sync rather than only the
  # first one -- useful for the reconciliation-check use case.
  def existing_image_links(ids)
    scope = ExternalLink.where(target_type: "Image", target_id: ids,
                               external_site: @site, relationship: :export)
    scope.update_all(last_synced_at: Time.current) if @apply
    scope.pluck(:target_id)
  end

  def process_row(row, known_ids, existing)
    return (@stats[:unparseable] += 1) unless row[:image_id]
    return record_missing(row) unless known_ids.include?(row[:image_id])
    return (@stats[:already_present] += 1) if existing.include?(row[:image_id])

    create_export_link(row)
  end

  def create_export_link(row)
    if @apply
      begin
        ExternalLink.create!(
          user: @admin, target_type: "Image",
          # images do not live on MCP. Instead they links to other sites.
          # However, an ExternalLink url must target the external site
          # Therefore, do not populate url
          # url: nil
          target_id: row[:image_id], external_site: @site,
          relationship: :export,
          external_created_on: row[:metadata_date],
          last_synced_at: Time.current
        )
      rescue ActiveRecord::RecordInvalid => e
        warn("  Image #{row[:image_id]}: #{e.message}")
        return (@stats[:invalid] += 1)
      end
    end
    @stats[:created] += 1
  end

  # Image referenced by MCP's multimedia dump no longer (or never did)
  # exists locally -- report for triage rather than silently skipping.
  def record_missing(row)
    @stats[:mo_missing] += 1
    @missing << [row[:occid], @mo_id_by_occid[row[:occid]], row[:image_id]]
  end

  def write_reports
    write_csv(@missing_out, %w[occid mo_obs_id image_id], @missing)
  end

  def write_csv(path, header, rows)
    return if rows.empty?

    CSV.open(path, "w") do |csv|
      csv << header
      rows.each { |row| csv << row }
    end
  end

  def print_summary
    puts
    puts("== summary#{" (dry run)" unless @apply} ==")
    puts("  created: #{@stats[:created]}")
    puts("  already present (skipped): #{@stats[:already_present]}")
    puts("  invalid (see warnings above): #{@stats[:invalid]}")
    puts("  image not found in MO: #{@stats[:mo_missing]} -> #{@missing_out}")
    puts("  unparseable identifier: #{@stats[:unparseable]}")
    puts("  elapsed: #{elapsed_summary}")
    puts
    puts(@apply ? "APPLIED." : "Dry run. Re-run with APPLY=1 to write.")
  end

  def elapsed_summary
    format_duration(Process.clock_gettime(Process::CLOCK_MONOTONIC) -
                     @started_at)
  end

  def format_duration(seconds)
    total = seconds.round
    hours, remainder = total.divmod(3600)
    minutes, secs = remainder.divmod(60)
    return format("%dh %dm %ds", hours, minutes, secs) if hours.positive?
    return format("%dm %ds", minutes, secs) if minutes.positive?

    format("%ds", secs)
  end
end

if $PROGRAM_NAME == __FILE__
  BackfillMycoportalExportLinks.new(
    BackfillMycoportalExportLinks.parse_options(ARGV)
  ).run
end
