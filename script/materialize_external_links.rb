#!/usr/bin/env ruby
# frozen_string_literal: true

# Materialize MO<->iNat correspondences as typed ExternalLinks (#4565), from
# the iNat "Mushroom Observer URL" observation field (5005) report.
#
# For each row (an iNat obs whose field 5005 points at an MO obs URL):
#   - parse the MO obs id from the URL; if the obs doesn't exist -> mo_missing
#     (skip + report; deferred per #4576 orphan triage).
#   - if the MO obs already has an iNat ExternalLink:
#       * same iNat id  -> already materialized (import from #4529, or our own
#         link on a re-run) -> skip. Idempotent.
#       * different iNat id -> CONFLICT (the obs is linked to a *different*
#         iNat obs). Should not happen; written in full to the conflicts CSV
#         for review (≈ the analysis's import_diff multi-link bucket).
#   - otherwise create ONE admin-owned link (one link per (obs, site)), typed
#     from the MO-side note signal:
#       "Mirrored on iNaturalist"  -> mirror
#       contains an inaturalist.org URL -> manual
#       else (no iNat URL in notes) -> copy   (the historical bulk back-refs)
#
# URL is left derived (ExternalSite#observation_url from external_id).
#
# Dry run by default; APPLY=1 writes. Idempotent.
#   bin/rails runner script/materialize_external_links.rb
#   APPLY=1 bin/rails runner script/materialize_external_links.rb --csv FILE

require "csv"
require "optparse"

class MaterializeExternalLinks
  BATCH = 2000
  PROGRESS_EVERY = 20_000
  URL_RE = %r{mushroomobserver\.org/
              (?:observations/|obs/|observer/show_observation/)?(\d+)}x
  MIRROR_RE = /Mirrored on iNaturalist/i
  MANUAL_RE = /inaturalist\.org/i
  # Pre-#4299 manual links stored only a url (no external_id); recover the
  # iNat obs id from it so dedup compares correctly.
  INAT_URL_RE = %r{inaturalist\.org/observations/(\d+)}

  def initialize(opts)
    @csv = opts.fetch(:csv)
    @apply = opts.fetch(:apply)
    @conflicts_out = opts.fetch(:conflicts_out)
    @missing_out = opts.fetch(:missing_out)
    @site = ExternalSite.inaturalist
    @admin = User.admin
    @stats = Hash.new(0)
    @conflicts = []
    @missing = []
    @materialized = {} # mo_id => iNat id created this run (intra-run dedup)
    @seen = 0
  end

  def run
    rows = load_rows
    @total = rows.size
    warn("Materializing #{@total} correspondences (site=#{@site.name}, " \
         "#{@apply ? "APPLY" : "dry run"})")
    rows.each_slice(BATCH) { |batch| process_batch(batch) }
    write_reports
    print_summary
  end

  private

  def load_rows
    CSV.read(@csv, headers: true).map do |r|
      url = r["field:mushroom observer url"].to_s.strip
      { inat_id: r["id"].to_s.strip, mo_id: mo_id_from_url(url), url: url }
    end
  end

  def mo_id_from_url(url)
    m = URL_RE.match(url)
    m && m[1].to_i
  end

  def process_batch(batch)
    ids = batch.filter_map { |r| r[:mo_id] }
    obs_by_id = Observation.where(id: ids).index_by(&:id)
    links = ExternalLink.where(target_type: "Observation", target_id: ids,
                               external_site_id: @site.id).index_by(&:target_id)
    batch.each { |row| process_row(row, obs_by_id, links) }
    @seen += batch.size
    warn("  #{@seen}/#{@total} processed") if (@seen % PROGRESS_EVERY).zero?
  end

  def process_row(row, obs_by_id, links)
    return (@stats[:unparseable] += 1) unless row[:mo_id]

    obs = obs_by_id[row[:mo_id]]
    return record_missing(row) unless obs

    existing_id, link = existing_inat_id(row[:mo_id], links)
    if existing_id.nil?
      create_link(obs, row)
    elsif existing_id == row[:inat_id]
      @stats[:already_present] += 1
    else
      record_conflict(row, existing_id, link)
    end
  end

  # The iNat id this obs is already linked to (DB link or one created this
  # run), plus the DB link if any.
  def existing_inat_id(mo_id, links)
    if (link = links[mo_id])
      [link_inat_id(link), link]
    else
      [@materialized[mo_id], nil]
    end
  end

  # The iNat obs id a link points at: its external_id, or — for legacy
  # manual links that only stored a url — parsed from the url.
  def link_inat_id(link)
    (link.external_id.presence || link.url.to_s[INAT_URL_RE, 1]).to_s
  end

  def create_link(obs, row)
    type = classify(obs)
    if @apply
      ExternalLink.create!(user: @admin, target: obs, external_site: @site,
                           external_id: row[:inat_id], relationship: type)
    end
    @materialized[row[:mo_id]] = row[:inat_id]
    @stats[type] += 1
  end

  # Mirror notes also contain an inaturalist.org URL, so check mirror first.
  def classify(obs)
    blob = notes_blob(obs)
    return :mirror if blob.match?(MIRROR_RE)
    return :manual if blob.match?(MANUAL_RE)

    :copy
  end

  def notes_blob(obs)
    notes = obs.notes
    notes.is_a?(Hash) ? notes.values.join("\n") : notes.to_s
  end

  def record_missing(row)
    @stats[:mo_missing] += 1
    @missing << [row[:mo_id], row[:inat_id], row[:url]]
  end

  def record_conflict(row, existing_id, link)
    @stats[:conflict] += 1
    @conflicts << [row[:mo_id], row[:url], row[:inat_id], existing_id,
                   link&.relationship, link&.id]
  end

  def write_reports
    write_csv(@conflicts_out,
              %w[mo_obs_id mo_url row_inat_id existing_inat_id
                 existing_relationship existing_link_id], @conflicts)
    write_csv(@missing_out,
              %w[mo_obs_id row_inat_id mo_url], @missing)
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
    [:copy, :mirror, :manual].each { |t| puts("  created #{t}: #{@stats[t]}") }
    puts("  already present (skipped): #{@stats[:already_present]}")
    puts("  conflicts: #{@stats[:conflict]} -> #{@conflicts_out}")
    puts("  mo_missing: #{@stats[:mo_missing]} -> #{@missing_out}")
    puts("  unparseable url: #{@stats[:unparseable]}")
    puts
    puts(@apply ? "APPLIED." : "Dry run. Re-run with APPLY=1 to write.")
  end
end

def parse_options(argv)
  opts = { apply: ENV["APPLY"] == "1", csv: "observations-750205.csv",
           conflicts_out: "external_link_conflicts.csv",
           missing_out: "external_link_mo_missing.csv" }
  OptionParser.new do |o|
    o.banner = "Usage: bin/rails runner script/materialize_external_links.rb"
    o.on("--csv FILE",
         "Field-5005 report (default observations-750205.csv)") do |v|
      opts[:csv] = v
    end
    o.on("--conflicts-out FILE") { |v| opts[:conflicts_out] = v }
    o.on("--missing-out FILE") { |v| opts[:missing_out] = v }
  end.parse!(argv)
  opts
end

if $PROGRAM_NAME == __FILE__
  MaterializeExternalLinks.new(parse_options(ARGV)).run
end
