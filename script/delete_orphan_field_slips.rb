#!/usr/bin/env ruby
# frozen_string_literal: true

#  USAGE::
#
#    bin/rails runner script/delete_orphan_field_slips.rb -- \
#      [--min-age-hours N]
#    APPLY=1 bin/rails runner script/delete_orphan_field_slips.rb -- ...
#
#  DESCRIPTION::
#
#    Deletes "orphan" field slips — those with no occurrence, and therefore
#    not attached to any observation. An unattached field slip has no
#    purpose (its code can always be re-entered later), and they accumulate
#    from the field-slip entry flow when a user registers a code but never
#    completes an observation.
#
#    Dry run by default (lists what it would delete); APPLY=1 deletes.
#    Idempotent: re-running only removes whatever is currently orphaned.
#
#    --min-age-hours N restricts deletion to orphans created more than N
#    hours ago, so a slip a user is *currently* attaching to an observation
#    (created seconds ago, occurrence not yet saved) is spared. Recommended
#    when running against live production; default 0 (delete all orphans).
#
#    Destroy is safe: a field slip's only occurrence link is `has_one
#    :occurrence, dependent: :nullify`, and orphans have none; there are no
#    destroy callbacks and no other table references field_slip_id.

require "optparse"

class DeleteOrphanFieldSlips
  def initialize(opts)
    @min_age_hours = opts[:min_age_hours] || 0
    @apply = ENV["APPLY"] == "1"
    @deleted = 0
    @errors = 0
  end

  def run
    slips = orphans
    puts("#{@apply ? "APPLY" : "DRY RUN"}: #{slips.count} orphan field " \
         "slips#{age_note}")
    # each (not find_each) so the created_at ordering is honored — find_each
    # batches by primary key and overrides any scope order. Orphans are a
    # small set, so loading them at once is fine.
    slips.each { |slip| handle(slip) }
    summarize
  end

  private

  def orphans
    scope = FieldSlip.where.missing(:occurrence).
            order(:created_at)
    return scope if @min_age_hours.zero?

    scope.where(field_slips: { created_at: ..@min_age_hours.hours.ago })
  end

  def handle(slip)
    line = "field_slip #{slip.id} #{slip.code} " \
           "(project #{slip.project_id.inspect}, created #{slip.created_at})"
    if @apply
      slip.destroy!
      @deleted += 1
      puts("deleted #{line}")
    else
      puts("would delete #{line}")
    end
  rescue StandardError => e
    @errors += 1
    warn("  #{slip.code}: #{e.class}: #{e.message}")
  end

  def age_note
    @min_age_hours.zero? ? "" : " older than #{@min_age_hours}h"
  end

  def summarize
    if @apply
      puts("\nDeleted #{@deleted}; errors #{@errors}.")
    else
      puts("\nDry run: no changes made. Re-run with APPLY=1 to delete.")
    end
  end
end

options = {}
OptionParser.new do |opts|
  opts.on("--min-age-hours N", Integer,
          "Only delete orphans older than N hours") do |n|
    # A negative value would make the cutoff a future time, sweeping in
    # even seconds-old slips — dangerous when APPLY=1.
    abort("--min-age-hours must be >= 0") if n.negative?

    options[:min_age_hours] = n
  end
end.parse!

DeleteOrphanFieldSlips.new(options).run
