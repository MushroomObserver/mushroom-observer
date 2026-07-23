#!/usr/bin/env ruby
# frozen_string_literal: true

# One-time backfill of ExternalLink (relationship: :export) rows for every
# Observation and Image already present in MyCoPortal (MCP)
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
# Observations/Images already linked (skipped, not recreated) are written
# to a second report, bydefault <dwca-dir>/mycoportal_backfill_skipped.csv
# (columns include the existing ExternalLink's id, for traceability)
# pass --skipped-out to override.
#
# occurrences.csv's "catalogNumber" ("MUOB <id>") is the MO Observation id;
# its own "id" column is MCP's internal occid. multimedia.csv's "coreid"
# joins to that occid.
#
# Images do not live on MCP -- they link out to other sites (MO itself, or
# a mirror). An ExternalLink's url must target the external site itself,
# so Image links get no url and no external_id (no per-image id exists in
# the dump either -- see the plan doc for why).
#
# Re-running this script doubles as a reconciliation check:
# in a dry run, a nonzero "would create" count means MCP has
# observations/images MO doesn't think it exported.
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
  # CLI option parsing, kept in its own nested class rather than a bare
  # top-level `def parse_options` -- other scripts in this directory
  # define exactly that name, and two top-level defs with the same name
  # silently collide if both scripts are ever `require`d into one process
  # (confirmed: this script's own test suite would collide with
  # materialize_external_links.rb's if both defined a top-level method).
  class Options
    DEFAULT_DWCA_DIR = Rails.root.join("tmp/mycoportal_dwca").to_s

    class << self
      def parse(argv)
        opts = default_options
        OptionParser.new do |parser|
          parser.banner = "Usage: bin/rails runner " \
                          "script/backfill_mycoportal_export_links.rb"
          add_dwca_options(parser, opts)
          add_report_options(parser, opts)
        end.parse!(argv)
        opts[:missing_out] ||= default_report_path(opts[:dwca_dir],
                                                   "missing")
        opts[:skipped_out] ||= default_report_path(opts[:dwca_dir],
                                                   "skipped")
        opts
      end

      private

      def default_options
        { apply: ENV["APPLY"] == "1", dwca_dir: DEFAULT_DWCA_DIR,
          occurrences: nil, multimedia: nil, keep_csvs: false,
          missing_out: nil, skipped_out: nil }
      end

      def default_report_path(dwca_dir, name)
        File.join(dwca_dir, "mycoportal_backfill_#{name}.csv")
      end

      def add_report_options(parser, opts)
        parser.on("--missing-out FILE",
                  "Missing report path (default: " \
                  "<dwca-dir>/mycoportal_backfill_missing.csv)") do |val|
          opts[:missing_out] = val
        end
        parser.on("--skipped-out FILE",
                  "Already-present report path (default: " \
                  "<dwca-dir>/mycoportal_backfill_skipped.csv)") do |val|
          opts[:skipped_out] = val
        end
      end

      def add_dwca_options(parser, opts)
        parser.on("--dwca-dir DIR",
                  "Where to find the downloaded DwC-A zip and extract " \
                  "it (default: #{DEFAULT_DWCA_DIR})") do |val|
          opts[:dwca_dir] = val
        end
        parser.on("--occurrences FILE",
                  "Skip the zip; use an already-extracted " \
                  "occurrences.csv (requires --multimedia too)") do |val|
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
  end

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
    @skipped_out = opts.fetch(:skipped_out)
    @site = ExternalSite.mycoportal
    @admin = User.admin
    reset_run_state!
  end

  def reset_run_state!
    @stats = { images: Hash.new(0), observations: Hash.new(0) }
    @missing = []
    @skipped = []
    @images_seen = 0
    @occurrences_seen = 0
  end
  private :reset_run_state!

  def run
    @stopwatch = Stopwatch.new
    extract_dwca_zip! unless @occurrences_csv
    warn("Processing MyCoPortal DwC-A (site=#{@site.name}, " \
         "#{@apply ? "APPLY" : "dry run"}) ...")
    process_occurrences
    each_multimedia_batch { |batch| process_image_batch(batch) }
    write_reports
    print_summary
  ensure
    cleanup_extracted_files
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

  # Single streamed pass over occurrences.csv: builds @mo_id_by_occid (used
  # to annotate the Image missing-report with an MO id) and batch-processes
  # each row as an Observation export-link candidate in the same pass --
  # avoids reading this ~300MB file twice.
  def process_occurrences
    @mo_id_by_occid = {}
    batch = []
    CSV.foreach(@occurrences_csv, headers: true) do |row|
      parsed = parse_occurrence_row(row)
      @mo_id_by_occid[parsed[:occid]] = parsed[:mo_id] if parsed[:mo_id]
      batch << parsed
      next unless batch.size == BATCH

      process_occurrence_batch(batch)
      batch = []
    end
    process_occurrence_batch(batch) if batch.any?
  end

  def parse_occurrence_row(row)
    match = CATALOG_NUMBER_REGEXP.match(row["catalogNumber"].to_s.strip)
    { occid: row["id"], mo_id: match && match[1].to_i,
      date_entered: row["dateEntered"].presence }
  end

  def process_occurrence_batch(batch)
    ids = batch.filter_map { |r| r[:mo_id] }
    known_ids = Observation.where(id: ids).pluck(:id).to_set
    existing = existing_links(target_type: "Observation", ids: ids)
    batch.each { |row| process_occurrence_row(row, known_ids, existing) }
    @occurrences_seen += batch.size
    return unless (@occurrences_seen % PROGRESS_EVERY).zero?

    warn("  #{@occurrences_seen} occurrences processed")
  end

  def process_occurrence_row(row, known_ids, existing)
    return increment_stat("Observation", :unparseable) unless row[:mo_id]
    return record_missing_observation(row) unless
      known_ids.include?(row[:mo_id])
    return record_skipped_observation(row, existing) if
      existing.key?(row[:mo_id])

    create_export_link(target_type: "Observation", target_id: row[:mo_id],
                       external_id: row[:occid],
                       external_created_on: row[:date_entered])
  end

  def record_missing_observation(row)
    record_missing(target_type: "Observation", occid: row[:occid],
                   mo_id: row[:mo_id])
  end

  def record_skipped_observation(row, existing)
    record_skipped(target_type: "Observation", occid: row[:occid],
                   mo_id: row[:mo_id], link_id: existing[row[:mo_id]])
  end

  # stream in batches, never CSV.read the whole file because it's huge.
  def each_multimedia_batch
    batch = []
    CSV.foreach(@multimedia_csv, headers: true) do |row|
      batch << parse_multimedia_row(row)
      next unless batch.size == BATCH

      yield(batch)
      batch = []
    end
    yield(batch) if batch.any?
  end

  def parse_multimedia_row(row)
    { occid: row["coreid"], image_id: image_id_from(row["identifier"]),
      # MetadataDate is the closest available proxy for when MCP created
      # this media record -- not a guaranteed creation date, but the best
      # the DwC-A dump exposes.
      metadata_date: row["MetadataDate"].presence }
  end

  def image_id_from(identifier)
    IMAGE_ID_REGEXP.match(identifier.to_s.strip)&.[](1)&.to_i
  end

  def process_image_batch(batch)
    ids = batch.filter_map { |r| r[:image_id] }
    known_ids = Image.where(id: ids).pluck(:id).to_set
    existing = existing_links(target_type: "Image", ids: ids)
    batch.each { |row| process_image_row(row, known_ids, existing) }
    @images_seen += batch.size
    warn("  #{@images_seen} images processed") if
      (@images_seen % PROGRESS_EVERY).zero?
  end

  def process_image_row(row, known_ids, existing)
    return increment_stat("Image", :unparseable) unless row[:image_id]
    return record_missing_image(row) unless
      known_ids.include?(row[:image_id])
    return record_skipped_image(row, existing) if
      existing.key?(row[:image_id])

    create_export_link(target_type: "Image", target_id: row[:image_id],
                       external_created_on: row[:metadata_date])
  end

  def record_missing_image(row)
    record_missing(target_type: "Image", occid: row[:occid],
                   mo_id: @mo_id_by_occid[row[:occid]],
                   image_id: row[:image_id])
  end

  def record_skipped_image(row, existing)
    record_skipped(target_type: "Image", occid: row[:occid],
                   mo_id: @mo_id_by_occid[row[:occid]],
                   image_id: row[:image_id],
                   link_id: existing[row[:image_id]])
  end

  # Bumps last_synced_at on already-linked records in this batch, so the
  # field reflects the most recent confirmed sync rather than only the
  # first one -- useful for the reconciliation-check use case.
  def existing_links(target_type:, ids:)
    scope = ExternalLink.where(target_type: target_type, target_id: ids,
                               external_site: @site, relationship: :export)
    scope.update_all(last_synced_at: Time.current) if @apply
    scope.pluck(:target_id, :id).to_h
  end

  def create_export_link(target_type:, target_id:, external_id: nil,
                         external_created_on: nil)
    if @apply
      begin
        ExternalLink.create!(user: @admin, target_type: target_type,
                             target_id: target_id, external_site: @site,
                             relationship: :export, external_id: external_id,
                             external_created_on: external_created_on,
                             last_synced_at: Time.current)
      rescue ActiveRecord::RecordInvalid => e
        warn("  #{target_type} #{target_id}: #{e.message}")
        return increment_stat(target_type, :invalid)
      end
    end
    increment_stat(target_type, :created)
  end

  def increment_stat(target_type, key)
    @stats[stat_key(target_type)][key] += 1
  end

  def stat_key(target_type)
    target_type == "Image" ? :images : :observations
  end

  # Referenced by MCP's DwC-A dump but doesn't (or no longer does) exist
  # locally -- report for triage rather than silently skipping.
  def record_missing(target_type:, occid:, mo_id:, image_id: nil)
    increment_stat(target_type, :mo_missing)
    @missing << [target_type, occid, mo_id, image_id]
  end

  # Already linked -- report which ExternalLink covers this record
  # alongside the plain already_present count, for traceability.
  def record_skipped(target_type:, occid:, mo_id:, link_id:, image_id: nil)
    increment_stat(target_type, :already_present)
    @skipped << [target_type, occid, mo_id, image_id, link_id]
  end

  def write_reports
    write_csv(@missing_out, %w[entity_type occid mo_obs_id image_id],
              @missing)
    write_csv(@skipped_out,
              %w[entity_type occid mo_obs_id image_id external_link_id],
              @skipped)
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
    print_entity_summary("Images", @stats[:images])
    print_entity_summary("Observations", @stats[:observations])
    puts("  missing report: -> #{@missing_out}")
    puts("  skipped report: -> #{@skipped_out}")
    puts("  elapsed: #{@stopwatch}")
    puts
    puts(@apply ? "APPLIED." : "Dry run. Re-run with APPLY=1 to write.")
  end

  def print_entity_summary(label, stats)
    puts("  #{label}:")
    puts("    created: #{stats[:created]}")
    puts("    already present (skipped): #{stats[:already_present]}")
    puts("    invalid (see warnings above): #{stats[:invalid]}")
    puts("    not found in MO: #{stats[:mo_missing]}")
    puts("    unparseable: #{stats[:unparseable]}")
  end

  # Elapsed wall-clock time, formatted for the summary. Monotonic clock --
  # immune to system clock adjustments -- not Time.now.
  class Stopwatch
    def initialize
      @started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def to_s
      format_duration(Process.clock_gettime(Process::CLOCK_MONOTONIC) -
                       @started_at)
    end

    private

    def format_duration(seconds)
      total = seconds.round
      hours, remainder = total.divmod(3600)
      minutes, secs = remainder.divmod(60)
      return format("%dh %dm %ds", hours, minutes, secs) if hours.positive?
      return format("%dm %ds", minutes, secs) if minutes.positive?

      format("%ds", secs)
    end
  end
end

if $PROGRAM_NAME == __FILE__
  BackfillMycoportalExportLinks.new(
    BackfillMycoportalExportLinks::Options.parse(ARGV)
  ).run
end
