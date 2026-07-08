# frozen_string_literal: true

# Finds + fixes + alerts for #4171: observations whose `vote_cache` is
# stuck near 0 even though their consensus-name Naming has a real positive
# `vote_cache`. The map popup reads `obs.vote_cache` directly, so the stale
# value shows up there as "0% confidence" even though the obs show page
# reads correctly.
#
# Repairs affected obs by calling
# `Observation::NamingConsensus#calc_consensus` (which recomputes from the
# live Naming/Vote rows and saves), then emails `MO.webmaster_email_address`
# with a per-obs detail block of what was fixed. Safe to re-run;
# `calc_consensus` has an idempotent early-return when nothing changed.
#
# Pass `dry_run: true` to find affected obs without repairing or emailing
# (e.g. to gauge a historical backlog before the first real run), and
# `no_email: true` to repair without emailing (e.g. to clear a known
# historical backlog silently on deploy).
class RepairObservationVoteCacheJob < ApplicationJob
  queue_as :maintenance

  EPSILON = 1e-4

  def perform(dry_run: false, no_email: false, verbose: false)
    @dry_run = dry_run
    @no_email = no_email
    @verbose = verbose

    rows = stale_observations
    log("Found #{rows.size} observation(s) with stale vote_cache")
    return if rows.empty?

    tally, repaired_rows = repair_all(rows)
    log("Done: #{tally[:repaired]} #{repaired_verb}, " \
        "#{tally[:unchanged]} unchanged, #{tally[:missing]} missing, " \
        "#{tally[:errors]} errors")
    alert_if_needed(repaired_rows)
  end

  private

  def repair_all(rows)
    tally = { repaired: 0, unchanged: 0, missing: 0, errors: 0 }
    repaired_rows = []
    rows.each_with_index do |row, i|
      log("  #{i}/#{rows.size} processed") if (i % 200).zero? && i.positive?
      repair_one(row, tally, repaired_rows)
    end
    [tally, repaired_rows]
  end

  def repair_one(row, tally, repaired_rows)
    status = process_obs(row[0])
    tally[status] += 1
    repaired_rows << row if status == :repaired
  rescue StandardError => e
    tally[:errors] += 1
    log("  ! obs #{row[0]}: #{e.class}: #{e.message}")
  end

  def repaired_verb
    @dry_run ? "would be repaired" : "repaired"
  end

  # `repaired_rows` are the specific rows that were actually repaired (not
  # just the first N of `rows` — some stale-looking rows can turn out
  # :unchanged after recompute, so a positional slice would mislabel them).
  def alert_if_needed(repaired_rows)
    return if repaired_rows.empty? || @dry_run || @no_email

    send_alert(repaired_rows)
    log("Sent alert email to #{MO.webmaster_email_address}")
  end

  # Find affected obs with everything the email needs. `candidate_observations`
  # pushes "has a matching naming with a real vote_cache" into a real SQL
  # join, so this only ever loads observations that are plausibly stale -
  # not every observation with a nil/near-zero vote_cache (most unreviewed
  # observations legitimately have one). `stale_row`/`representative_naming`
  # then apply the exact original semantics (representative = lowest-id
  # matching naming, regardless of which naming's vote_cache triggered the
  # join) on that much smaller set. `find_each` keeps memory bounded and
  # batches by id, so the result isn't ordered - sort by created_at after.
  def stale_observations
    rows = []
    candidate_observations.find_each { |obs| rows << stale_row(obs) }
    rows.compact.sort_by { |row| row[1] }.reverse
  end

  def candidate_observations
    Observation.joins(candidate_naming_join).where(stale_vote_cache).
      distinct.includes(:user, :namings)
  end

  # A matching naming (same obs, same consensus name_id) with a real
  # vote_cache - a coarse SQL-level pre-filter; `representative_naming`
  # applies the exact original semantics afterward.
  def candidate_naming_join
    obs = Observation.arel_table
    namings = Naming.arel_table
    condition = namings[:observation_id].eq(obs[:id]).
                and(namings[:name_id].eq(obs[:name_id])).
                and(namings[:vote_cache].gt(0.01))
    obs.join(namings).on(condition).join_sources
  end

  def stale_vote_cache
    obs = Observation.arel_table
    obs[:vote_cache].eq(nil).
      or(obs[:vote_cache].gteq(-0.01).and(obs[:vote_cache].lteq(0.01)))
  end

  def stale_row(obs)
    naming = representative_naming(obs)
    return nil unless naming && naming.vote_cache.to_f > 0.01

    [obs.id, obs.created_at, obs.updated_at, obs.user_id, obs.source,
     obs.inat_id, naming.id, naming.vote_cache, obs.user&.login]
  end

  def representative_naming(obs)
    return nil if obs.name_id.nil?

    obs.namings.select { |n| n.name_id == obs.name_id }.min_by(&:id)
  end

  # nil and 0.0 are equivalent for our purposes (both mean "no useful
  # vote_cache recorded"); coerce to compare cleanly.
  def vote_cache_changed?(before, after)
    (before.to_f - after.to_f).abs > EPSILON
  end

  # Returns :repaired / :unchanged / :missing for tally bookkeeping.
  def process_obs(obs_id)
    obs = Observation.find_by(id: obs_id)
    return :missing if obs.nil?
    return :repaired if @dry_run

    recompute_and_classify(obs)
  end

  def recompute_and_classify(obs)
    before = obs.vote_cache
    Observation::NamingConsensus.new(obs).calc_consensus
    obs.reload
    if vote_cache_changed?(before, obs.vote_cache)
      log("  obs #{obs.id} repaired") if @verbose
      :repaired
    else
      :unchanged
    end
  end

  def send_alert(rows)
    WebmasterMailer.build(
      sender_email: MO.webmaster_email_address,
      subject: "[MO] vote_cache integrity check: " \
               "#{rows.size} observation(s) repaired",
      message: format_alert(rows)
    ).deliver_now
  end

  def format_alert(rows)
    lines = alert_header(rows.size)
    lines.concat(rows.first(50).map { |r| format_obs_line(r) })
    lines << "" << "(#{rows.size - 50} more not listed)" if rows.size > 50
    lines.join("\n")
  end

  def alert_header(count)
    verb = @dry_run ? "would be repaired" : "were repaired"
    [
      "vote_cache integrity check found #{count} observation(s) " \
      "whose obs.vote_cache was stale (≈ 0) despite the matching-name " \
      "Naming having a real positive vote_cache. They #{verb}.",
      "",
      "Tracking and root-cause hunt: " \
      "https://github.com/MushroomObserver/mushroom-observer/issues/4171",
      "",
      "Per-obs detail (most recent first, up to 50):",
      ""
    ]
  end

  def format_obs_line(row)
    obs_id, created_at, updated_at, user_id, source, inat_id,
      naming_id, naming_vc, user_login = row
    format("- obs %d: %s\n    " \
           "user %d (%s), created %s, updated %s\n    " \
           "source=%s, inat_id=%s, naming %d vc=%.3f",
           obs_id, Observation.show_url(obs_id),
           user_id, user_login || "?",
           created_at, updated_at,
           source.inspect, inat_id.inspect,
           naming_id, naming_vc.to_f)
  end
end
