#!/usr/bin/env ruby
# frozen_string_literal: true

# Delete duplicate ExternalLinks that share (target_type, target_id,
# external_site_id, external_id) -- the exact-duplicate shape #5312's
# migration's new unique index enforces. Two shapes of duplicate,
# found on a fresh checkpoint (4 groups total):
#
#   - identical rows (same relationship too), created seconds apart --
#     an accidental double-submit. Keeps the older row, deletes the
#     rest.
#   - the same correspondence recorded via two different relationship
#     values (e.g. one `manual` row and one `export` row for the same
#     occid). Keeps whichever relationship is higher in
#     RELATIONSHIP_PRIORITY (import/export -- verified automated
#     processes -- rank above manual/remote_manual -- human-entered),
#     deletes the other.
#
# A group that doesn't fit one of these two shapes is reported, not
# deleted -- this script does not guess.
#
#   bin/rails runner script/dedupe_external_links.rb            # dry run
#   bin/rails runner script/dedupe_external_links.rb --apply    # write

require "optparse"

class DedupeExternalLinks
  RELATIONSHIP_PRIORITY = %w[import export mirror copy remote_manual manual
                             unknown].freeze

  def initialize(opts)
    @apply = opts.fetch(:apply, false)
    @counts = Hash.new(0)
    @unresolved = []
  end

  def run
    duplicate_keys.each { |key| process_group(key) }
    report_summary
  end

  private

  def duplicate_keys
    ExternalLink.
      group(:target_type, :target_id, :external_site_id, :external_id).
      count.select { |_, c| c > 1 }.keys
  end

  def process_group(key)
    target_type, target_id, site_id, external_id = key
    links = ExternalLink.where(target_type: target_type, target_id: target_id,
                               external_site_id: site_id,
                               external_id: external_id).order(:created_at)
    relationships = links.map(&:relationship).uniq
    if relationships.size == 1
      dedupe_identical!(links)
    else
      dedupe_by_priority!(links, relationships)
    end
  end

  def dedupe_identical!(links)
    keep, *losers = links.to_a
    delete_losers!(keep, losers, :identical_deduped, "identical duplicates")
  end

  def dedupe_by_priority!(links, relationships)
    unless unambiguous_priority?(relationships)
      return report_unresolved(links, "unrecognized or tied relationship " \
                                       "priority")
    end

    keep = links.min_by { |l| RELATIONSHIP_PRIORITY.index(l.relationship) }
    delete_losers!(keep, links.to_a - [keep], :priority_deduped,
                   "same target/site/external_id, lower-priority " \
                   "relationship")
  end

  def delete_losers!(keep, losers, count_key, reason)
    warn("keep ##{keep.id} (#{keep.relationship}), delete " \
         "#{losers.map { |l| "##{l.id} (#{l.relationship})" }.join(", ")} " \
         "-- #{reason}")
    losers.each { |l| l.destroy! if @apply }
    @counts[count_key] += losers.size
  end

  def unambiguous_priority?(relationships)
    ranks = relationships.map { |r| RELATIONSHIP_PRIORITY.index(r) }
    ranks.none?(nil) && ranks.uniq.size == relationships.size
  end

  def report_unresolved(links, reason)
    @unresolved << { ids: links.map(&:id), reason: reason }
    warn("##{links.map(&:id).join(", ")}: #{reason}, needs human review")
    @counts[:unresolved_group] += 1
  end

  def report_summary
    warn("")
    warn("== Summary (#{@apply ? "APPLIED" : "dry run"}) ==")
    @counts.each { |k, v| warn("  #{k}: #{v}") }
    return if @unresolved.empty?

    warn("")
    warn("Needs human review:")
    @unresolved.each { |r| warn("  #{r[:ids].join(", ")}: #{r[:reason]}") }
  end
end

options = { apply: false }
OptionParser.new do |opts|
  opts.banner =
    "Usage: bin/rails runner script/dedupe_external_links.rb [options]"
  opts.on("--apply", "Write changes (default: dry run)") do
    options[:apply] = true
  end
end.parse!(ARGV)

DedupeExternalLinks.new(options).run
