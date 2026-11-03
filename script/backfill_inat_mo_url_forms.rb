# frozen_string_literal: true

# Rewrite iNaturalist "Mushroom Observer URL" field values (field 5005)
# to the /obs/ form and resync the reflection behind each one (#5357,
# #4215). Logged-out visitors get a 403 on the /:id and
# /observations/:id forms, so every value iNat holds should read
# https://mushroomobserver.org/obs/<id>.
#
#   Dry run, safe anywhere, no auth:
#     bin/rails runner script/backfill_inat_mo_url_forms.rb \
#       -- [--max-batches N]

# Live runs need a token. get_inat_oauth_access_token.rb does the
# one-time setup; this script mints its 24h JWT from the long-lived
# OAuth access token at startup and re-mints on expiry.
#
#     ... -- --apply --max-writes 8500 \
#       --oauth-token-file tmp/inat_oauth_access_token
#
#   Or pass a JWT from /users/api_token directly, which lasts ~24h:
#     ... -- --token JWT --apply --max-writes 8500

# Read-only reflections only, ~15k, newest iNat id first. Driven from
# MO's reflection list rather than iNat's search across every
# observation carrying the field, so the ~61k linked-but-editable
# imports and ~100k other linked observations are not fetched only to
# be skipped. Those wait for the reflection-building pass, which walks
# them anyway and can rewrite their URLs as it converts them.

# Idempotent. Values already in /obs/ form are skipped, as are
# "DEAD LINK:"-prefixed ones (#4565: they point at deleted MO
# observations, so their form does not matter) and values with no
# extractable MO id, which are reported for manual review.

# iNat asks for ~1 request/second and ~10,000 requests/day. One batch
# fetch covers 200 reflections, so ~75 reads cover the set and the
# writes are what the daily budget has to carry: --max-writes 8500
# twice finishes ~14.2k rewrites and leaves room for the reads and for
# the nightly batch resync. At a write per second, 8,500 takes ~2.4h.

# The written URL is hardcoded to production's domain. The field
# accepts updates from any authenticated account (precedent: the #4565
# DEAD LINK pass).

require("optparse")
require_relative("resync_diff")

class BackfillInatMoUrlForms
  include Inat::Constants

  BATCH = Inat::ObsFetcher::PAGE_SIZE
  # Self-imposed throttle: stay well under iNat's 100 req/min cap.
  WRITE_SLEEP = 1.0
  BATCH_SLEEP = Inat::ObsFetcher::INTER_PAGE_SLEEP
  PROGRESS_EVERY = 1 # batches -- a batch is 200 reflections

  # The value written is always production's URL, wherever this runs.
  TARGET_HOST = "https://mushroomobserver.org"

  GOOD_VALUE_RE = %r{\Ahttps?://mushroomobserver\.org/obs/\d+\z}
  MO_ID_RE = MO_URL_FIELD_VALUE_ID_RE

  # Written after every observation, so a run with no --id-below
  # resumes where the last one stopped; delete it to start from the
  # newest again. tmp/, not beside the script: script/ is tracked.
  CURSOR_FILE =
    Rails.root.join("tmp/backfill_inat_mo_url_forms.cursor").to_s

  USAGE = "Usage: ... -- [--token JWT | --oauth-token TOKEN | " \
          "--oauth-token-file PATH] [--apply] [--id-below N] " \
          "[--max-batches N] [--max-writes N]"

  def initialize(argv)
    @apply = false
    @token = nil
    @oauth_token = nil
    @id_below = nil
    @max_batches = 0
    @max_writes = 0
    parse_argv(argv)
    load_cursor
    mint_jwt if @token.blank? && @oauth_token.present?
    reset_counters
  end

  def reset_counters
    @checked = @rewrites = @skipped_dead = @unparseable = @batches = 0
    @synced = @sync_unchanged = @gone = @no_field = @write_failed = 0
    @api_calls = Hash.new(0)
    @started = Time.zone.now
  end

  # Every read-only reflection with an iNat import link, newest iNat id
  # first. Sorted in Ruby because external_id is a string column, so the
  # database would order "9" above "10".
  def targets
    @targets ||= numbered_links.sort_by { |inat_id, _obs_id| -inat_id }
  end

  def numbered_links
    reflection_links.map do |external_id, obs_id|
      [external_id.to_i, obs_id]
    end
  end

  def reflection_links
    site = ExternalSite.find_by(name: ExternalSite::INATURALIST_NAME)
    reflections = Observation.where.not(reflected_at: nil).select(:id)
    ExternalLink.where(
      external_site_id: site&.id,
      relationship: ExternalLink.relationships[:import],
      target_type: "Observation", target_id: reflections
    ).pluck(:external_id, :target_id)
  end

  def applier
    @applier ||= Inat::ReflectionResync.new
  end

  def fetcher
    @fetcher ||= Inat::ObsFetcher.new
  end

  def run
    warn("#{targets.size} reflections to check" \
         "#{" below iNat id #{@id_below}" if @id_below}.")
    catch(:budget_spent) do
      pending.each_slice(BATCH) { |batch| handle_batch(batch) }
    end
    summary
  end

  private

  def pending
    return targets unless @id_below

    targets.select { |inat_id, _obs_id| inat_id < @id_below }
  end

  def handle_batch(batch)
    by_id = fetch(batch)
    observations = Observation.where(id: batch.map(&:last)).index_by(&:id)
    batch.each do |inat_id, obs_id|
      handle_observation(inat_id, by_id[inat_id.to_s], observations[obs_id])
      @id_below = inat_id
      save_cursor
      quota_check
    end
    @batches += 1
    throw(:budget_spent) if @max_batches.positive? && @batches >= @max_batches

    progress
    sleep(BATCH_SLEEP)
  end

  def fetch(batch)
    @api_calls[:get] += 1
    by_id, failed = fetcher.fetch_batch(batch.map(&:first))
    abort_with_status("batch fetch failed after retries") if failed
    by_id
  end

  # An id queried explicitly and missing from the results is gone from
  # iNat. Deletion handling belongs to the nightly batch resync, which is
  # built for it; this pass counts it and moves on.
  def handle_observation(inat_id, raw, mo_obs)
    return gone_from_inat(inat_id, mo_obs) unless raw

    ofv = (raw[:ofvs] || []).find do |field|
      field[:field_id] == MO_URL_OBSERVATION_FIELD_ID
    end
    return @no_field += 1 unless ofv

    @checked += 1
    report(inat_id, ofv, mo_obs, dispatch_value(inat_id, ofv),
           resync(mo_obs, inat_id, raw))
  end

  # Named, not just counted: the nightly batch fetches with
  # updated_since, where a missing id reads as "didn't change", so a
  # deleted source is invisible to it. This pass is the only thing that
  # sees them, and the ids are the point.
  def gone_from_inat(inat_id, mo_obs)
    @gone += 1
    warn("GONE FROM INAT inat=#{inat_id} mo=#{mo_obs&.id || "-"} " \
         "images=#{mo_obs ? mo_obs.images.size : "-"}")
  end

  # :synced / :unchanged / :no_mo_record / :dry_run
  def resync(mo_obs, inat_id, raw)
    return :no_mo_record unless mo_obs
    return :dry_run unless @apply

    before = ResyncDiff.snapshot(mo_obs)
    status = applier.call(mo_obs, { inat_id.to_s => raw }, false,
                          absent: :unchanged).status
    status == :synced ? (@synced += 1) : (@sync_unchanged += 1)
    return status unless status == :synced

    "#{status}(#{ResyncDiff.describe(
      before, ResyncDiff.snapshot(mo_obs.reload)
    )})"
  end

  # One line per observation, naming what changed, so a run leaves a
  # trail that can be checked by hand.
  def report(inat_id, ofv, mo_obs, url_action, sync_action)
    warn("inat=#{inat_id} mo=#{mo_obs&.id || "-"} url=#{url_action} " \
         "resync=#{sync_action} value=#{ofv[:value].inspect}")
    applier.alerts.each { |message| warn("  ALERT #{message}") }
    applier.alerts.clear
  end

  # What the URL needed, as a symbol for the run's per-observation line.
  def dispatch_value(inat_id, ofv)
    value = ofv[:value].to_s
    return :already_obs_form if value.match?(GOOD_VALUE_RE)

    if value.start_with?("DEAD LINK")
      @skipped_dead += 1
      :dead_link
    elsif (mo_id = value[MO_ID_RE, 1])
      rewrite(inat_id, ofv, mo_id)
    else
      @unparseable += 1
      :unparseable
    end
  end

  def rewrite(inat_id, ofv, mo_id)
    new_value = "#{TARGET_HOST}/obs/#{mo_id}"
    return dry_run_rewrite unless @apply

    @api_calls[:put] += 1
    api.request(path: "observation_field_values/#{ofv[:id]}",
                method: :put,
                payload: { observation_field_value: { value: new_value } })
    @rewrites += 1 # after the PUT, so a JWT-refresh retry counts once
    sleep(WRITE_SLEEP)
    :rewrote
  rescue RestClient::Unauthorized
    raise if @jwt_retry # re-mint already failed to help; give up

    abort_with_status("token expired or unauthorized") if @oauth_token.blank?
    warn("JWT expired mid-run; minting a fresh one and retrying.")
    mint_jwt
    @jwt_retry = true
    retry
  rescue RestClient::ExceptionWithResponse => e
    write_failed(inat_id, ofv, e)
  ensure
    @jwt_retry = false
  end

  # The body carries iNat's reason -- a 422 here is usually "you may not
  # edit this field value", which the status alone doesn't say.
  def write_failed(inat_id, ofv, error)
    @write_failed += 1
    warn("WRITE FAILED inat=#{inat_id} ofv=#{ofv[:id]}: #{error.message} " \
         "#{error.response&.body.to_s[0, 200]}")
    :write_failed
  end

  def dry_run_rewrite
    @rewrites += 1
    :would_rewrite
  end

  # Stop when the write quota is hit, after the observation that hit it
  # has been resynced, reported, and passed by the cursor.
  def quota_check
    return unless @max_writes.positive? && @rewrites >= @max_writes

    warn("Reached --max-writes #{@max_writes}.")
    throw(:budget_spent)
  end

  def parse_argv(argv)
    option_parser.parse!(argv)
    return unless @apply && @token.blank? && @oauth_token.blank?

    abort("--apply requires --token (a 24h JWT) or --oauth-token[-file] " \
          "(a long-lived OAuth access token)")
  rescue OptionParser::ParseError => e
    abort("#{e.message}\n#{USAGE}")
  end

  def option_parser
    OptionParser.new do |op|
      op.banner = USAGE
      auth_options(op)
      op.on("--id-below N", Integer) { |n| @id_below = n }
      op.on("--max-batches N", Integer) { |n| @max_batches = n }
      op.on("--max-writes N", Integer) { |n| @max_writes = n }
    end
  end

  def auth_options(parser)
    parser.on("--apply") { @apply = true }
    parser.on("--token TOKEN", String) { |t| @token = t }
    parser.on("--oauth-token TOKEN", String) { |t| @oauth_token = t }
    parser.on("--oauth-token-file PATH", String) do |path|
      @oauth_token = File.read(path).strip
    end
  end

  # An iNat OAuth access token lives until revoked; the API wants the
  # 24h JWT it can mint at #{SITE}/users/api_token. Mint at startup and
  # again when a long run outlives one (see the 401 rescue in #rewrite).
  def mint_jwt
    @token = Inat::APIToken.new(
      app_id: nil, site: SITE, redirect_uri: nil, secret: nil
    ).trade_access_token_for_jwt_api_token(@oauth_token)
    abort("OAuth token was not accepted at #{SITE}/users/api_token") if
      @token.blank?
    @api = nil # rebuild with the fresh JWT
    warn("Minted a fresh 24h JWT from the OAuth access token.")
  rescue RestClient::ExceptionWithResponse => e
    abort("JWT minting failed: #{e.message} -- is the OAuth token " \
          "still authorized?")
  end

  # Explicit --id-below wins; otherwise resume from the state file.
  # nil means "start from the newest reflection".
  def load_cursor
    return if @id_below || !File.exist?(CURSOR_FILE)

    @id_below = File.read(CURSOR_FILE).to_i
    warn("Resuming from saved cursor id_below=#{@id_below} " \
         "(#{CURSOR_FILE}; delete it to restart from the newest).")
  end

  # Only a live run advances the cursor. A dry run that moved it would
  # claim observations it didn't rewrite, and the walk only goes
  # downward -- those observations would be skipped for good.
  def save_cursor
    File.write(CURSOR_FILE, @id_below.to_s) if @apply
  end

  def api
    @api ||= Inat::APIRequest.new(@token)
  end

  # Against iNat's ~10,000/day guidance.
  def api_calls
    "inat-api-calls=#{@api_calls.values.sum}" \
      "(#{@api_calls.map { |method, n| "#{method}:#{n}" }.join(",")})"
  end

  def progress
    return unless (@batches % PROGRESS_EVERY).zero?

    elapsed = (Time.zone.now - @started).round
    warn("[#{elapsed}s] batches=#{@batches} cursor=#{@id_below} " \
         "checked=#{@checked} inat-urls-rewritten=#{@rewrites} " \
         "mo-resynced=#{@synced} dead=#{@skipped_dead} " \
         "unparseable=#{@unparseable} #{api_calls}")
  end

  def abort_with_status(reason)
    abort("#{reason}\nCursor saved (id_below=#{@id_below}); rerun the " \
          "same command to resume.")
  end

  # Counts name what they count: the URL tally covers the iNat field
  # value alone, the resync tallies the MO observation behind it.
  def summary
    label = @apply ? "inat-urls-rewritten" : "inat-urls-to-rewrite"
    warn("Done. checked=#{@checked} #{label}=#{@rewrites} " \
         "dead-link-skipped=#{@skipped_dead} " \
         "unparseable=#{@unparseable} mo-resynced=#{@synced} " \
         "mo-resync-no-change=#{@sync_unchanged} " \
         "gone-from-inat=#{@gone} no-url-field=#{@no_field} " \
         "write-failed=#{@write_failed} " \
         "#{api_calls} cursor=#{@id_below}")
    return warn("Rerun the same command to continue from the saved cursor.") if
      @apply

    warn("Dry run - nothing written, cursor not moved. Add --apply to write.")
  end
end

BackfillInatMoUrlForms.new(ARGV).run
