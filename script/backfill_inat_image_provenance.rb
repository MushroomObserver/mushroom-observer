# frozen_string_literal: true

#  USAGE::
#
#    bin/rails runner script/backfill_inat_image_provenance.rb \
#      [-n|--dry-run] [-v|--verbose]
#
#  DESCRIPTION::
#
#    Backfill of #4529, parse path. iNat-imported images created before
#    PR #4555 carried their provenance in `original_name` as
#    "iNat photo_id: <id>, uuid: <uuid>". Where that string survives,
#    copy the iNat photo id into the structured `external_id` column and
#    point `source_id` at the iNaturalist Source — the same values the
#    importer now writes directly.
#
#    Images whose `original_name` was nulled by the uploader's
#    keep_filenames="toss" preference (~159k) carry no parseable id and
#    are left for the separate position-order inference backfill.
#
#    Idempotent: only touches images that still lack `external_id`. Writes
#    via update_columns, so no callbacks, timestamps, or notifications
#    fire. -n/--dry-run reports without writing. Affected ids are written
#    to backfill_inat_image_provenance.csv.
#
################################################################################

require("csv")

# Copies the iNat photo id out of legacy `original_name` provenance into
# the structured (source_id, external_id) columns (#4529).
class InatImageProvenanceBackfill
  PHOTO_ID = /\AiNat photo_id:\s*(\d+)/
  LIKE = "iNat photo_id: %"
  REPORT = Rails.root.join("backfill_inat_image_provenance.csv")

  def initialize(dry_run:, verbose:)
    @dry_run = dry_run
    @verbose = verbose
    @rows = []
    @source_id = Source.inaturalist.id
  end

  def run
    scope = Image.where("original_name LIKE ?", LIKE).where(external_id: nil)
    log("#{prefix}#{scope.count} image(s) with parseable iNat provenance")
    scope.find_each(batch_size: 1000) { |image| process(image) }
    write_report
    log("#{prefix}backfilled #{@rows.size} image(s)")
  end

  private

  def process(image)
    photo_id = image.original_name[PHOTO_ID, 1]
    return unless photo_id

    unless @dry_run
      image.update_columns(source_id: @source_id, external_id: photo_id)
    end
    @rows << [image.id, photo_id]
    vlog("image #{image.id}: #{prefix}external_id=#{photo_id}")
  end

  def write_report
    CSV.open(REPORT, "w") do |csv|
      csv << %w[image_id external_id dry_run]
      @rows.each { |id, ext| csv << [id, ext, @dry_run] }
    end
    log("Wrote #{REPORT}")
  end

  def prefix
    @dry_run ? "[dry-run] " : ""
  end

  def log(msg)
    puts(msg)
  end

  def vlog(msg)
    log(msg) if @verbose
  end
end

InatImageProvenanceBackfill.new(
  dry_run: ARGV.intersect?(["-n", "--dry-run"]),
  verbose: ARGV.intersect?(["-v", "--verbose"])
).run
