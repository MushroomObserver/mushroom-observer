# frozen_string_literal: true

#  USAGE::
#
#    bin/rails runner script/load_image_provenance.rb CSV_PATH \
#      [-n|--dry-run] [-v|--verbose]
#
#  DESCRIPTION::
#
#    Loads a precomputed (image_id, external_id) provenance mapping (#4529).
#    The position-inference and content-match backfills require hundreds of
#    iNat API fetches; since the dev DB is a faithful copy of production
#    (same image ids) and the mapping is deterministic, we compute it once
#    locally and load the result into production with a fast bulk update —
#    no second inference pass, no API traffic from production.
#
#    Reads any of the backfill scripts' `*_mapped.csv` outputs (they all
#    carry `image_id` + `external_id` columns); concatenate them, or run
#    this once per file. `source_id` is resolved from THIS database's
#    iNaturalist Source, not taken from the CSV.
#
#    Idempotent and safe — each image is classified:
#      applied  : external_id was NULL; set it (+ source_id)
#      already  : external_id already equals the mapped value; skip
#      conflict : external_id already set to a DIFFERENT value; skip + log
#                 (e.g. a go-forward capture, or a stale mapping)
#      missing  : image id not present in this database; skip
#
#    update_columns, so no callbacks/timestamps fire. -n/--dry-run reports
#    without writing. Conflicts -> load_image_provenance_conflicts.csv.
#
################################################################################

require("csv")

# Applies a precomputed image_id -> external_id provenance mapping to the
# local database, idempotently and without clobbering existing values.
class ImageProvenanceLoader
  CONFLICTS = Rails.root.join("load_image_provenance_conflicts.csv")
  CHUNK = 5000

  def initialize(path:, dry_run:, verbose:)
    @path = path
    @dry_run = dry_run
    @verbose = verbose
    @source_id = Source.inaturalist.id
    @stats = Hash.new(0)
    @conflicts = []
  end

  def run
    mapping = read_mapping
    log("#{prefix}#{mapping.size} mapping(s) from #{@path}")
    found = apply(mapping)
    @stats[:missing] = mapping.size - found
    write_conflicts
    summarize
  end

  private

  def read_mapping
    CSV.read(@path, headers: true).each_with_object({}) do |row, hash|
      id = row["image_id"]&.to_i
      external_id = row["external_id"]
      hash[id] = external_id if id && external_id.present?
    end
  end

  def apply(mapping)
    found = 0
    mapping.keys.each_slice(CHUNK) do |ids|
      Image.where(id: ids).select(:id, :external_id).each do |image|
        found += 1
        classify(image, mapping[image.id])
      end
    end
    found
  end

  def classify(image, external_id)
    if image.external_id.nil?
      unless @dry_run
        image.update_columns(source_id: @source_id, external_id: external_id)
      end
      @stats[:applied] += 1
    elsif image.external_id == external_id
      @stats[:already] += 1
    else
      @stats[:conflict] += 1
      @conflicts << [image.id, image.external_id, external_id]
    end
  end

  def write_conflicts
    return if @conflicts.empty?

    CSV.open(CONFLICTS, "w") do |csv|
      csv << %w[image_id db_external_id csv_external_id]
      @conflicts.each { |row| csv << row }
    end
    log("Wrote #{CONFLICTS}")
  end

  def summarize
    log("#{prefix}done: #{@stats.to_h}")
  end

  def prefix
    @dry_run ? "[dry-run] " : ""
  end

  def log(msg)
    puts(msg)
  end
end

path = ARGV.find { |arg| arg.end_with?(".csv") }
abort("usage: load_image_provenance.rb CSV_PATH [-n] [-v]") unless path
ImageProvenanceLoader.new(
  path: path,
  dry_run: ARGV.intersect?(["-n", "--dry-run"]),
  verbose: ARGV.intersect?(["-v", "--verbose"])
).run
