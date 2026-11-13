# frozen_string_literal: true

# One-time repair, the precondition for the unique indexes on
# project_observations and project_images (#4181). Each duplicate is the
# same link written twice, so the oldest row of each pair survives.
#
# Dry run (default -- reports, writes nothing):
#   bin/rails runner script/dedupe_project_links.rb
# Apply:
#   bin/rails runner script/dedupe_project_links.rb --apply

APPLY = ARGV.delete("--apply") ? true : false
if ARGV.any?
  warn("Unknown argument(s): #{ARGV.join(", ")}")
  warn("Usage: bin/rails runner script/dedupe_project_links.rb [--apply]")
  exit(1)
end

# Deletes all but the oldest row of each duplicated project link.
class ProjectLinkDedupe
  TABLES = [[ProjectObservation, :observation_id],
            [ProjectImage, :image_id]].freeze
  REPORT_EVERY = 100

  def initialize(apply:)
    @apply = apply
    @started = Time.zone.now
  end

  def run
    puts(@apply ? "APPLYING changes." : "DRY RUN.")
    totals = TABLES.map { |model, column| dedupe(model, column) }
    summarize(totals)
  end

  private

  def dedupe(model, column)
    groups = duplicate_groups(model, column)
    puts("\n#{model.table_name}: #{groups.size} duplicated pairs")
    extra = groups.each_with_index.sum do |(pair, ids), index|
      removed = dedupe_pair(model, column, pair, ids)
      progress(model, index + 1, groups.size)
      removed
    end
    [model.table_name, groups.size, extra]
  end

  # Returns the number of rows deleted (or that would be).
  def dedupe_pair(model, column, (project_id, target_id), ids)
    keep, *drop = ids.sort
    puts("  project #{project_id} #{column} #{target_id}: " \
         "keep #{keep}, delete #{drop.join(", ")}")
    model.where(id: drop).delete_all if @apply
    drop.size
  end

  # {[project_id, target_id] => [row ids]} for every pair with more
  # than one row.
  def duplicate_groups(model, column)
    pairs = model.group(:project_id, column).
            having(Arel.star.count.gt(1)).count.keys
    pairs.to_h do |project_id, target_id|
      [[project_id, target_id],
       model.where(project_id: project_id, column => target_id).pluck(:id)]
    end
  end

  def progress(model, done, total)
    return unless (done % REPORT_EVERY).zero? || done == total

    elapsed = (Time.zone.now - @started).round
    warn("#{model.table_name}: #{done}/#{total} pairs, #{elapsed}s")
  end

  def summarize(totals)
    puts("\nSummary:")
    verb = @apply ? "deleted" : "would delete"
    totals.each do |table, pairs, extra|
      puts("  #{table}: #{pairs} duplicated pairs, #{verb} #{extra} rows")
    end
    return if @apply

    puts("Dry run - nothing written. To apply: " \
         "bin/rails runner script/dedupe_project_links.rb --apply")
  end
end

ProjectLinkDedupe.new(apply: APPLY).run
