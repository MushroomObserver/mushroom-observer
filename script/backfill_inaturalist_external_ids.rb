#!/usr/bin/env ruby
# frozen_string_literal: true

# Backfill external_id on legacy iNaturalist ExternalLinks that only
# have a stored url (#5312, part of #4592's external_id-is-the-sole-
# identity migration). iNaturalist urls are already id-addressable --
# no crawl needed, unlike MyCoPortal's list.php search case (see
# script/resolve_mycoportal_links.rb) -- so every candidate resolves
# via ExternalSite#id_from_url or is reported for manual review.
#
# Idempotent: only selects links with external_id nil and url present,
# so an already-resolved row is skipped on re-run.
#
#   bin/rails runner script/backfill_inaturalist_external_ids.rb
#   bin/rails runner script/backfill_inaturalist_external_ids.rb --apply
#   bin/rails runner \
#     script/backfill_inaturalist_external_ids.rb --apply --limit 20

require "optparse"

class BackfillInaturalistExternalIds
  def initialize(opts)
    @apply = opts.fetch(:apply, false)
    @limit = opts[:limit]
    @site = begin
              ExternalSite.inaturalist
            rescue ActiveRecord::RecordNotFound
              abort("No iNaturalist external site found")
            end
    @counts = Hash.new(0)
    @unresolved = []
  end

  def run
    candidates.find_each { |link| process_safely(link) }
    report_summary
  end

  private

  def candidates
    scope = ExternalLink.where(external_site_id: @site.id, external_id: nil).
            where.not(url: [nil, ""])
    @limit ? scope.limit(@limit) : scope
  end

  # One bad row shouldn't abort an unattended run -- log it as an error
  # to review and move on to the rest.
  def process_safely(link)
    process(link)
  rescue StandardError => e
    @unresolved << { id: link.id, url: link.url, error: e.message }
    warn("##{link.id}: unhandled error (#{e.class}: #{e.message}), skipping")
    @counts[:unhandled_error] += 1
  end

  def process(link)
    id = @site.id_from_url(link.url)
    return resolve!(link, id) if id

    @unresolved << { id: link.id, url: link.url, error: "no match" }
    warn("##{link.id}: #{link.url} -> does not match iNaturalist's " \
         "url shape, needs manual review")
    @counts[:unresolved] += 1
  end

  def resolve!(link, id)
    warn("##{link.id}: #{link.url} -> external_id=#{id}")
    link.update!(external_id: id) if @apply # callback clears url
    @counts[:resolved] += 1
  end

  def report_summary
    warn("")
    warn("== Summary (#{@apply ? "APPLIED" : "dry run"}) ==")
    @counts.each { |k, v| warn("  #{k}: #{v}") }
    report_needs_review
  end

  def report_needs_review
    return if @unresolved.empty?

    warn("")
    warn("Needs human review:")
    @unresolved.each { |r| warn("  ##{r[:id]}: #{r[:error]} -- #{r[:url]}") }
  end
end

options = { apply: false }
OptionParser.new do |opts|
  opts.banner =
    "Usage: bin/rails runner " \
    "script/backfill_inaturalist_external_ids.rb [options]"
  opts.on("--apply", "Write changes (default: dry run)") do
    options[:apply] = true
  end
  opts.on("--limit N", Integer, "Process at most N links (trial run)") do |n|
    options[:limit] = n
  end
end.parse!(ARGV)

BackfillInaturalistExternalIds.new(options).run
