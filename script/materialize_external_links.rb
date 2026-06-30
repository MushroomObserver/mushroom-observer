#!/usr/bin/env ruby
# frozen_string_literal: true

# Materialize MO<->iNat correspondences as typed ExternalLinks (#4565), from
# the iNat "Mushroom Observer URL" observation field (5005) report.
#
# An MO obs may correspond to several iNat obs (iNat-side duplicates of one
# collection), so it can carry multiple iNat links; dedup is per correspondence
# (obs + iNat id), not per obs. Per row (iNat obs X -> MO obs M):
#   1. M missing -> mo_missing (skip + report; #4576 orphan triage).
#   2. M already links to X (same iNat id) -> skip (idempotent).
#   3. M has an import link (to a different iNat obs) -> remote_manual: the
#      importer only stamps the obs it created, so an extra ref was hand-set on
#      the iNat side. (Unless M's notes carry a "Mirrored on iNaturalist" stamp
#      -> mirror.)
#   4. M has no import link:
#        "Mirrored on iNaturalist" note -> mirror
#        notes contain an inaturalist.org URL -> manual (MO-side cross-ref)
#        else -> copy ONLY for the oldest (lowest-id) iNat obs of M, and only
#          if it predates the copy-service cutoff (2022): the copy service made
#          a single copy. Every newer link — and the oldest itself when it
#          postdates the cutoff — is remote_manual (hand-set on the iNat side).
#          So an MO obs has at most one copy link. (Re-runs demote any extra
#          copy links left by earlier runs.)
#
# import + copy can never co-occur on one obs (step 3 short-circuits). Obs that
# end up with 2+ iNat links are written to the multi-link report — the input to
# reflection resolution (#4585). URL is left derived from external_id.
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
  # The iNat-team copy service ran through 2021 (multi-user machine bursts). An
  # iNat obs created on/after this in the residual bucket is a hand-set link on
  # the iNat side (remote_manual), not a copy. See #4565.
  COPY_CUTOFF = "2022-01-01"

  def initialize(opts)
    @csv = opts.fetch(:csv)
    @apply = opts.fetch(:apply)
    @multi_out = opts.fetch(:multi_out)
    @missing_out = opts.fetch(:missing_out)
    @site = ExternalSite.inaturalist
    @admin = User.admin
    @stats = Hash.new(0)
    @missing = []
    @refs = {} # mo_id => Set of iNat ids it links to (existing + created)
    @seen = 0
  end

  def run
    rows = load_rows
    @total = rows.size
    @oldest_inat_by_mo = compute_oldest_inat(rows)
    warn("Materializing #{@total} correspondences (site=#{@site.name}, " \
         "#{@apply ? "APPLY" : "dry run"})")
    rows.each_slice(BATCH) { |batch| process_batch(batch) }
    @multi = multilink_rows
    write_reports
    print_summary
  end

  private

  def load_rows
    CSV.read(@csv, headers: true).map do |r|
      url = r["field:mushroom observer url"].to_s.strip
      { inat_id: r["id"].to_s.strip, mo_id: mo_id_from_url(url), url: url,
        inat_created: r["created_at"].to_s[0, 10] }
    end
  end

  def mo_id_from_url(url)
    m = URL_RE.match(url)
    m && m[1].to_i
  end

  # The oldest (lowest-id) iNat obs per MO obs — its sole copy candidate. iNat
  # ids are assigned chronologically, so the lowest id is the earliest obs.
  def compute_oldest_inat(rows)
    oldest = {}
    rows.each do |r|
      next unless r[:mo_id]

      cur = oldest[r[:mo_id]]
      oldest[r[:mo_id]] = r[:inat_id] if cur.nil? || r[:inat_id].to_i < cur.to_i
    end
    oldest
  end

  def process_batch(batch)
    ids = batch.filter_map { |r| r[:mo_id] }
    obs_by_id = Observation.where(id: ids).index_by(&:id)
    links = ExternalLink.where(target_type: "Observation", target_id: ids,
                               external_site_id: @site.id).
            group_by(&:target_id)
    batch.each { |row| process_row(row, obs_by_id, links) }
    @seen += batch.size
    warn("  #{@seen}/#{@total} processed") if (@seen % PROGRESS_EVERY).zero?
  end

  def process_row(row, obs_by_id, links)
    return (@stats[:unparseable] += 1) unless row[:mo_id]

    obs = obs_by_id[row[:mo_id]]
    obs ? materialize(obs, row, links) : record_missing(row)
  end

  def materialize(obs, row, links)
    db_links = links[row[:mo_id]] || []
    refs = refs_for(row[:mo_id], db_links)
    if refs.include?(row[:inat_id])
      backfill_external_date(db_links, row)
      demote_extra_copy(db_links, row)
      return (@stats[:already_present] += 1)
    end

    create_link(obs, row, classify(obs, db_links, row))
    refs << row[:inat_id]
  end

  # Repair data from earlier runs that allowed multiple copies per MO obs: any
  # copy link that is not the designated copy (the oldest iNat obs) becomes
  # remote_manual. At most one copy survives per MO obs.
  def demote_extra_copy(db_links, row)
    return if copy?(row)

    link = db_links.find { |l| l.external_id.to_s == row[:inat_id] }
    return unless link&.copy?

    link.update!(relationship: :remote_manual) if @apply
    @stats[:demoted_copy] += 1
  end

  # Idempotency for the external_created_on column: a link materialized before
  # the column existed has external_id but a nil date. Backfill it from the
  # report. Legacy url-only manual links have no external_id and keep their
  # own created_at as the relationship date, so they are left untouched.
  def backfill_external_date(db_links, row)
    return if row[:inat_created].blank?

    link = db_links.find { |l| l.external_id.to_s == row[:inat_id] }
    return unless link && link.external_created_on.nil?

    link.update_column(:external_created_on, row[:inat_created]) if @apply
    @stats[:backfilled_date] += 1
  end

  # Accumulated set of iNat ids this obs links to — seeded from its existing
  # DB links (across re-runs / multi-link batches) and grown as we create more.
  def refs_for(mo_id, db_links)
    set = (@refs[mo_id] ||= Set.new)
    db_links.each { |link| set << link_inat_id(link) }
    set
  end

  # The iNat obs id a link points at: its external_id, or — for legacy manual
  # links that only stored a url — parsed from the url.
  def link_inat_id(link)
    (link.external_id.presence || link.url.to_s[INAT_URL_RE, 1]).to_s
  end

  def create_link(obs, row, type)
    if @apply
      ExternalLink.create!(user: @admin, target: obs, external_site: @site,
                           external_id: row[:inat_id], relationship: type,
                           external_created_on: row[:inat_created].presence)
    end
    @stats[type] += 1
  end

  # Order matters — see the file header. Mirror stamp first (mirror notes also
  # contain an inaturalist.org URL). An extra ref on an import obs is a hand-set
  # link on the iNat side (remote_manual). A notes URL is an MO-side manual. The
  # residual is the historic copy service only for the oldest iNat obs of the
  # MO obs and only when it predates the cutoff (see copy?); every other
  # residual row is iNat-side manual (remote_manual).
  def classify(obs, db_links, row)
    blob = notes_blob(obs)
    return :mirror if blob.match?(MIRROR_RE)
    return :remote_manual if db_links.any?(&:import?)
    return :manual if blob.match?(MANUAL_RE)

    copy?(row) ? :copy : :remote_manual
  end

  # Copy applies to at most the oldest iNat obs of an MO obs (the copy service
  # made a single copy), and only if it predates the cutoff. Newer links — and
  # the oldest itself when it postdates the cutoff — are remote_manual.
  def copy?(row)
    @oldest_inat_by_mo[row[:mo_id]] == row[:inat_id] &&
      historic_copy?(row[:inat_created])
  end

  def historic_copy?(inat_created)
    inat_created.present? && inat_created < COPY_CUTOFF
  end

  def notes_blob(obs)
    notes = obs.notes
    notes.is_a?(Hash) ? notes.values.join("\n") : notes.to_s
  end

  def record_missing(row)
    @stats[:mo_missing] += 1
    @missing << [row[:mo_id], row[:inat_id], row[:url]]
  end

  def multilink_rows
    @refs.select { |_id, set| set.size >= 2 }.
      map { |id, set| [id, set.size, set.to_a.sort.join(" ")] }.
      sort_by(&:first)
  end

  def write_reports
    write_csv(@multi_out, %w[mo_obs_id inat_link_count inat_ids], @multi)
    write_csv(@missing_out, %w[mo_obs_id row_inat_id mo_url], @missing)
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
    print_created_counts
    print_other_counts
    puts
    puts(@apply ? "APPLIED." : "Dry run. Re-run with APPLY=1 to write.")
  end

  def print_created_counts
    [:copy, :mirror, :manual, :remote_manual].each do |t|
      puts("  created #{t}: #{@stats[t]}")
    end
    puts("  already present (skipped): #{@stats[:already_present]}")
    puts("  backfilled external date: #{@stats[:backfilled_date]}")
    puts("  demoted extra copy -> remote_manual: #{@stats[:demoted_copy]}")
  end

  def print_other_counts
    puts("  multi-link obs (2+ iNat links): #{@multi.size} -> #{@multi_out}")
    puts("  mo_missing: #{@stats[:mo_missing]} -> #{@missing_out}")
    puts("  unparseable url: #{@stats[:unparseable]}")
  end
end

def parse_options(argv)
  opts = { apply: ENV["APPLY"] == "1", csv: "inat-obs-report.csv",
           multi_out: "external_link_multilink.csv",
           missing_out: "external_link_mo_missing.csv" }
  OptionParser.new do |o|
    o.banner = "Usage: bin/rails runner script/materialize_external_links.rb"
    o.on("--csv FILE",
         "Field-5005 report (default inat-obs-report.csv)") do |v|
      opts[:csv] = v
    end
    o.on("--multi-out FILE") { |v| opts[:multi_out] = v }
    o.on("--missing-out FILE") { |v| opts[:missing_out] = v }
  end.parse!(argv)
  opts
end

if $PROGRAM_NAME == __FILE__
  MaterializeExternalLinks.new(parse_options(ARGV)).run
end
