# frozen_string_literal: true

#  USAGE::
#
#    bin/rails runner script/infer_inat_image_provenance.rb \
#      [-n|--dry-run] [-v|--verbose] [--limit N]
#
#  DESCRIPTION::
#
#    Backfill of #4529, position-order inference path. iNat-imported
#    images whose `original_name` provenance was nulled by the uploader's
#    keep_filenames="toss" preference (~159k) carry no parseable iNat
#    photo id. For each imported observation, fetch the current iNat
#    observation's photos (ordered by `position`), order that
#    observation's imported MO images by creation, and map them one-to-one
#    by position — the importer adds photos in iNat position order, so MO
#    image order tracks it. The mapped iNat photo id is written to each
#    image's `external_id` (with `source_id` = iNaturalist).
#
#    Only maps when the counts line up. Anything that can't be mapped
#    safely is logged, not guessed:
#      - not_found       : iNat observation gone/inaccessible
#      - fetch_error     : batch fetch failed after retries (retryable)
#      - count_mismatch  : MO imported-image count != iNat photo count
#                          (deleted on either side — overlaps the #4543
#                          orphan triage)
#      - position_conflict: an already-known external_id (from the parse
#                          backfill) disagrees with its positional photo,
#                          so the position assumption is unsafe here
#
#    Run script/backfill_inat_image_provenance.rb (the parse path) first.
#    Idempotent: only writes images still lacking `external_id`. Uses the
#    audit's batched, rate-limited, public iNat Fetcher. update_columns,
#    so no callbacks/timestamps fire. -n/--dry-run reports without writing;
#    --limit N processes at most N observations (for staging). Two CSV
#    reports: infer_image_provenance_mapped.csv and
#    infer_image_provenance_unmapped.csv.
#
################################################################################

require("csv")

# Infers each imported image's iNat photo id by aligning MO image order
# with iNat photo `position`, for images whose provenance was lost (#4529).
class InatImageProvenanceInference
  BATCH = Inat::ImportAudit::Fetcher::PAGE_SIZE
  MAPPED = Rails.root.join("infer_image_provenance_mapped.csv")
  UNMAPPED = Rails.root.join("infer_image_provenance_unmapped.csv")

  def initialize(dry_run:, verbose:, limit:)
    @dry_run = dry_run
    @verbose = verbose
    @limit = limit
    @fetcher = Inat::ImportAudit::Fetcher.new
    @source_id = Source.inaturalist.id
    @mapped = []
    @unmapped = []
  end

  def run
    scope = observations_to_process
    log("#{prefix}#{scope.size} observation(s) with images needing inference")
    scope.each_slice(BATCH) { |batch| process_batch(batch) }
    write_reports
    summarize
  end

  private

  def observations_to_process
    scope = Observation.where(source_id: @source_id).
            where.not(external_id: [nil, ""]).
            where(id: obs_ids_with_unbackfilled_images).
            order(:id)
    @limit ? scope.limit(@limit) : scope
  end

  def obs_ids_with_unbackfilled_images
    ObservationImage.joins(:image).
      where(images: { external_id: nil }).
      where("images.notes LIKE ?", "Imported from iNat%").
      select(:observation_id)
  end

  def process_batch(observations)
    by_id, failed = @fetcher.fetch_batch(observations.map(&:external_id))
    observations.each do |obs|
      process_obs(obs, by_id[obs.external_id.to_s], failed)
    end
  end

  def process_obs(obs, raw, failed)
    return record_unmapped(obs, failed ? "fetch_error" : "not_found") unless raw

    inat_photo_ids = ordered_inat_photo_ids(raw)
    images = imported_images(obs)
    return record_unmapped(obs, "count_mismatch", images, inat_photo_ids) \
      if images.size != inat_photo_ids.size
    return record_unmapped(obs, "position_conflict", images, inat_photo_ids) \
      if position_conflict?(images, inat_photo_ids)

    map_images(obs, images, inat_photo_ids)
  end

  def ordered_inat_photo_ids(raw)
    (raw[:observation_photos] || []).
      sort_by { |op| op[:position].to_i }.
      map { |op| op[:photo_id].to_s }
  end

  # All of the observation's iNat-imported images, in import (creation)
  # order — the order the importer added them, which tracks iNat position.
  def imported_images(obs)
    obs.images.where("notes LIKE ?", "Imported from iNat%").order(:id).to_a
  end

  # An image already carrying external_id (from the parse backfill) whose
  # value disagrees with its positional photo means the alignment is wrong.
  def position_conflict?(images, inat_photo_ids)
    images.zip(inat_photo_ids).any? do |image, photo_id|
      image.external_id.present? && image.external_id != photo_id
    end
  end

  def map_images(obs, images, inat_photo_ids)
    images.zip(inat_photo_ids).each do |image, photo_id|
      next if image.external_id.present?

      unless @dry_run
        image.update_columns(source_id: @source_id, external_id: photo_id)
      end
      @mapped << [image.id, photo_id, obs.id]
    end
    vlog("obs #{obs.id}: #{prefix}mapped #{inat_photo_ids.size} photo(s)")
  end

  def record_unmapped(obs, reason, images = nil, inat_photo_ids = nil)
    @unmapped << [obs.id, obs.external_id, reason,
                  images&.size, inat_photo_ids&.size]
    vlog("obs #{obs.id}: #{reason}")
  end

  def write_reports
    CSV.open(MAPPED, "w") do |csv|
      csv << %w[image_id external_id observation_id]
      @mapped.each { |row| csv << row }
    end
    CSV.open(UNMAPPED, "w") do |csv|
      csv << %w[observation_id inat_id reason mo_images inat_photos]
      @unmapped.each { |row| csv << row }
    end
    log("Wrote #{MAPPED} and #{UNMAPPED}")
  end

  def summarize
    log("#{prefix}mapped #{@mapped.size} image(s)")
    @unmapped.group_by { |row| row[2] }.
      sort_by { |_reason, rows| -rows.size }.
      each { |reason, rows| log("  unmapped #{reason}: #{rows.size} obs") }
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

limit = ARGV.each_cons(2).find { |flag, _| flag == "--limit" }&.last&.to_i
InatImageProvenanceInference.new(
  dry_run: ARGV.intersect?(["-n", "--dry-run"]),
  verbose: ARGV.intersect?(["-v", "--verbose"]),
  limit: limit
).run
