# frozen_string_literal: true

# One-time repair (#5416), and the precondition for the unique index on
# `external_links.import_source` for images.
#
# iNat joins one photo to as many observations as its owner likes, so a
# user who posts the same photos twice produces two iNat observations
# naming one photo. MO imported each faithfully and built a second
# Image for the photo it already held. Measured on production:
# 207 photo ids claimed by two MO images across 20 groups of
# observations, every group sharing an owner and a date.
#
# `Inat::PhotoImporter` reuses the existing image now, so no new
# duplicates arise. This merges the ones already here: the oldest image
# of each photo survives, everything pointing at the others is
# repointed to it, and the others are destroyed.
#
# Dry run (default -- reports, writes nothing):
#   bin/rails runner script/merge_duplicate_inat_images.rb
# Apply:
#   bin/rails runner script/merge_duplicate_inat_images.rb --apply

APPLY = ARGV.delete("--apply") ? true : false
if ARGV.any?
  warn("Unknown argument(s): #{ARGV.join(", ")}")
  warn("Usage: bin/rails runner script/merge_duplicate_inat_images.rb " \
       "[--apply]")
  exit(1)
end

# Merges the MO images that share one remote photo, oldest surviving.
class DuplicateInatImageMerge
  REPORT_EVERY = 25

  def initialize(apply:)
    @apply = apply
    @counts = Hash.new(0)
    @started = Time.zone.now
  end

  def run
    groups = duplicate_groups
    warn("#{groups.size} remote photos claimed by more than one MO image")
    groups.each_with_index do |(site_id, external_id), index|
      merge(site_id, external_id)
      progress(index + 1, groups.size)
    end
    report
  end

  private

  # [[external_site_id, external_id], ...] for every photo more than one
  # MO image claims as its import source.
  def duplicate_groups
    ExternalLink.import.where(target_type: "Image").
      group(:external_site_id, :external_id).
      having(ExternalLink.arel_table[:id].count.gt(1)).count.keys
  end

  def merge(site_id, external_id)
    images = images_for(site_id, external_id)
    return if images.size < 2

    keeper = images.first
    images.drop(1).each { |loser| absorb(keeper, loser, external_id) }
    @counts[:groups] += 1
  end

  # Oldest first: the first import of the photo is the one to keep, and
  # its id is the one any external reference is most likely to name.
  def images_for(site_id, external_id)
    ids = ExternalLink.import.where(target_type: "Image",
                                    external_site_id: site_id,
                                    external_id: external_id).pluck(:target_id)
    Image.where(id: ids).order(:id).to_a
  end

  def absorb(keeper, loser, external_id)
    warn("  photo #{external_id}: image #{loser.id} -> #{keeper.id} " \
         "(#{describe(loser)})")
    return @counts[:images_would_merge] += 1 unless @apply

    repoint(keeper, loser)
    loser.destroy
    @counts[:images_merged] += 1
  end

  def describe(loser)
    [["observations", ObservationImage.where(image_id: loser.id).count],
     ["thumbnails", Observation.where(thumb_image_id: loser.id).count],
     ["projects", ProjectImage.where(image_id: loser.id).count],
     ["votes", ImageVote.where(image_id: loser.id).count]].
      map { |label, count| "#{count} #{label}" }.join(", ")
  end

  # Every reference to the loser becomes a reference to the keeper,
  # skipping the ones the keeper already has -- both images can sit on
  # one observation, and a join table would refuse the duplicate row.
  def repoint(keeper, loser)
    repoint_joins(ObservationImage, :observation_id, keeper, loser)
    repoint_joins(ProjectImage, :project_id, keeper, loser)
    repoint_joins(ImageVote, :user_id, keeper, loser)
    Observation.where(thumb_image_id: loser.id).
      update_all(thumb_image_id: keeper.id)
    GlossaryTermImage.where(image_id: loser.id).
      update_all(image_id: keeper.id)
    VisualGroupImage.where(image_id: loser.id).
      update_all(image_id: keeper.id)
  end

  def repoint_joins(model, owner_column, keeper, loser)
    held = model.where(image_id: keeper.id).pluck(owner_column)
    rows = model.where(image_id: loser.id)
    rows.where(owner_column => held).delete_all
    rows.update_all(image_id: keeper.id)
  end

  def progress(done, total)
    return unless (done % REPORT_EVERY).zero?

    elapsed = (Time.zone.now - @started).round
    warn("  ... #{done}/#{total} groups, #{elapsed}s")
  end

  def report
    warn(@counts.map { |key, count| "#{key}: #{count}" }.join(", "))
    return if @apply

    warn("Dry run - nothing written. To apply: " \
         "bin/rails runner script/merge_duplicate_inat_images.rb --apply")
  end
end

DuplicateInatImageMerge.new(apply: APPLY).run
