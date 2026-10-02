# frozen_string_literal: true

require "json"

class Inat
  # Rewrites iNaturalist's "Mushroom Observer URL" field values to the
  # /obs/ form (#5357), and resyncs the MO reflection behind each one
  # while it has the observation in hand (#4215).
  #
  # Logged-out visitors get a 403 on the /:id and /observations/:id
  # forms, so every value iNat holds should read
  # https://mushroomobserver.org/obs/<id>.
  #
  # Walks iNat's search for observations carrying the field, newest
  # first (descending id_below pagination, which the 10,000-result page
  # window doesn't cap): recent observations are the most viewed, so
  # they are corrected first and the old tail waits. Values already in
  # /obs/ form are skipped, which makes the walk idempotent; so are
  # "DEAD LINK:" values (#4565 -- they name deleted MO observations, so
  # their form is moot) and values with no extractable MO id, which are
  # counted for review.
  #
  # The resync is inline rather than left to the nightly batch: an old
  # iNat observation stops changing, so `updated_since` stops returning
  # it, and the sequence, taxon and image engines shipped after most of
  # these were imported. The engines read the payload the search already
  # returned, so they cost no further API calls.
  #
  # One run is bounded by a wall-clock budget (the job holds one of two
  # maintenance threads) and optionally by a write quota; the cursor
  # resumes the next run where this one stopped.
  class URLBackfill
    include Inat::Constants

    DEFAULT_TIME_LIMIT = 30.minutes

    # A value needing no rewrite.
    GOOD_VALUE_RE = %r{\Ahttps?://mushroomobserver\.org/obs/\d+\z}

    # What bounds one run. The time limit is the binding one in
    # practice: the job holds one of the maintenance queue's two
    # threads, and writes are paced at one per second.
    Budget = Data.define(:time_limit, :max_writes) do
      def self.default
        new(time_limit: DEFAULT_TIME_LIMIT, max_writes: 0)
      end
    end

    Result = Data.define(:counts, :cursor, :alerts, :complete) do
      def complete? = complete

      def summary
        counts.map { |key, value| "#{key}=#{value}" }.join(" ")
      end
    end

    def initialize(client: Client.new, cursor: Cursor.new,
                   applier: ReflectionResync.new, budget: Budget.default,
                   logger: nil)
      @client = client
      @cursor = cursor
      @applier = applier
      @budget = budget
      @logger = logger
      @id_below = cursor.read
      @complete = false
      @counts = Hash.new(0)
    end

    def call
      @deadline = Time.zone.now + @budget.time_limit
      catch(:budget_spent) { walk }
      Result.new(counts: @counts.merge(cursor: @id_below), cursor: @id_below,
                 alerts: @applier.alerts, complete: @complete)
    end

    private

    def walk
      loop do
        page = fetch_page
        return @complete = true if page.empty?

        page.each { |raw| visit(raw) }
        @counts[:pages] += 1
      end
    end

    # The cursor tracks the observation, not the page: a run that stops
    # part way through a page would otherwise discard up to 200 finished
    # resyncs and walk them again tomorrow.
    def visit(raw)
      handle(raw)
      @id_below = raw["id"]
      @cursor.write(@id_below)
      throw(:budget_spent) if budget_spent?
    end

    def budget_spent?
      return true if Time.zone.now >= @deadline

      @budget.max_writes.positive? &&
        @counts[:rewritten] >= @budget.max_writes
    end

    def handle(raw)
      ofv = field_value(raw)
      return unless ofv

      @counts[:checked] += 1
      url_action = dispatch_value(raw, ofv)
      obs = mo_observation(raw["id"])
      log_event(raw, ofv, obs, url_action, resync(obs, raw))
    end

    def field_value(raw)
      (raw["ofvs"] || []).find do |field|
        field["field_id"] == MO_URL_OBSERVATION_FIELD_ID
      end
    end

    # Counted here rather than by instrumenting Inat::APIRequest: the
    # resync engines work from the payload this page already carries, so
    # the searches and the writes are the whole iNat cost of a run.
    def fetch_page
      @counts[:api_calls] += 1
      @client.search(id_below: @id_below)
    end

    def dispatch_value(raw, ofv)
      value = ofv["value"].to_s
      return :already_obs_form if value.match?(GOOD_VALUE_RE)
      return count(:dead_link) if value.start_with?("DEAD LINK")

      mo_id = value[MO_URL_FIELD_VALUE_ID_RE, 1]
      return count(:unparseable) unless mo_id

      rewrite(raw, ofv, mo_id)
    end

    # A rejected write is counted and reported, not raised: the run has
    # thousands of other values to get through, and the next pass over
    # this one retries it.
    def rewrite(raw, ofv, mo_id)
      @counts[:api_calls] += 1
      @client.write(ofv["id"], mo_id)
      count(:rewritten, as: :rewrote)
    rescue RestClient::ExceptionWithResponse => e
      write_log("WRITE FAILED inat=#{raw["id"]} ofv=#{ofv["id"]}: " \
                "#{e.message}")
      count(:write_failed)
    end

    def count(key, as: key)
      @counts[key] += 1
      as
    end

    # The MO observation this iNat observation was imported into, found
    # by its import link -- not by the id in the field value, which is
    # the thing being corrected.
    def mo_observation(inat_id)
      return nil unless site

      Observation.joins(:external_links).where(
        external_links: {
          external_site_id: site.id,
          relationship: ExternalLink.relationships[:import],
          external_id: inat_id.to_s
        }
      ).first
    end

    def site
      return @site if defined?(@site)

      @site = ExternalSite.find_by(name: ExternalSite::INATURALIST_NAME)
    end

    def resync(obs, raw)
      return :no_mo_record unless obs
      return :not_a_reflection unless obs.reflection?

      before = ResyncDiff.snapshot(obs)
      status = @applier.call(obs, { raw["id"].to_s => raw }, false,
                             absent: :unchanged).status
      @counts[status == :synced ? :resynced : :resync_unchanged] += 1
      return status unless status == :synced

      "synced(#{ResyncDiff.describe(before, ResyncDiff.snapshot(obs.reload))})"
    end

    # Only events worth checking by hand reach the log: across a pass of
    # this length, values already in /obs/ form with nothing to resync
    # are the overwhelming majority, and logging them buries the rest.
    def log_event(raw, ofv, obs, url_action, resync_action)
      return unless notable?(url_action, resync_action)

      write_log("inat=#{raw["id"]} mo=#{obs&.id || "-"} url=#{url_action} " \
                "resync=#{resync_action} value=#{ofv["value"].inspect}")
    end

    def notable?(url_action, resync_action)
      url_action != :already_obs_form ||
        resync_action.to_s.start_with?("synced")
    end

    def write_log(message)
      @logger ? @logger.call(message) : Rails.logger.info(message)
    end
  end
end
