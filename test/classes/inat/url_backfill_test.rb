# frozen_string_literal: true

require("test_helper")
require("json")

# Unit tests for Inat::URLBackfill, the temporary pass that rewrites
# iNat's "Mushroom Observer URL" values to the /obs/ form (#5357). The
# iNat conversation is injected as a fake client, so these exercise the
# value dispatch, the budgets, the cursor and the inline resync without
# touching the API. The per-reflection apply logic itself is covered by
# the Inat::ReflectionResync tests.
class Inat::URLBackfillTest < UnitTestCase
  # Stands in for Inat::URLBackfill::Client: serves canned pages and
  # records the writes it was asked for.
  class FakeClient
    attr_reader :writes, :searches

    def initialize(pages, write_error: nil)
      @pages = pages
      @write_error = write_error
      @writes = []
      @searches = []
    end

    def search(id_below: nil)
      @searches << id_below
      @pages.shift || []
    end

    def write(ofv_id, mo_id)
      raise(@write_error) if @write_error

      @writes << [ofv_id, mo_id]
      "https://mushroomobserver.org/obs/#{mo_id}"
    end
  end

  # An in-memory stand-in for the cursor file.
  class FakeCursor
    attr_reader :value

    def initialize(value = nil)
      @value = value
    end

    def read = @value
    def write(id) = @value = id
  end

  # Records what it was asked to apply without touching the database.
  class FakeApplier
    attr_reader :alerts, :applied

    def initialize(status: :unchanged)
      @status = status
      @alerts = []
      @applied = []
    end

    def call(reflection, by_id, _failed, absent: :deleted)
      @applied << [reflection.id, by_id.keys, absent]
      Inat::ReflectionResync::Result.new(status: @status,
                                         observation: reflection)
    end
  end

  def setup
    @obs = observations(:imported_inat_obs)
    @inat_id = @obs.import_link.external_id.to_i
  end

  # A search result carrying the MO URL field, as iNat returns it.
  def raw_obs(inat_id, value, ofv_id: 1)
    { "id" => inat_id,
      "ofvs" => [{ "field_id" => Inat::Constants::MO_URL_OBSERVATION_FIELD_ID,
                   "id" => ofv_id, "value" => value }] }
  end

  def run_backfill(pages, client: nil, cursor: FakeCursor.new,
                   applier: FakeApplier.new, budget: {})
    client ||= FakeClient.new(pages)
    limits = { time_limit: 30.minutes, max_writes: 0 }.merge(budget)
    backfill = Inat::URLBackfill.new(
      client: client, cursor: cursor, applier: applier,
      budget: Inat::URLBackfill::Budget.new(**limits),
      logger: ->(message) { (@logged ||= []) << message }
    )
    [backfill.call, client]
  end

  # The job holds one of the maintenance queue's two threads, so a run
  # is time-boxed by default and writes are unlimited within it.
  def test_defaults_to_a_time_boxed_run
    budget = Inat::URLBackfill::Budget.default

    assert_equal(Inat::URLBackfill::DEFAULT_TIME_LIMIT, budget.time_limit)
    assert_equal(0, budget.max_writes)
  end

  def test_rewrites_a_legacy_value_to_the_obs_form
    page = [raw_obs(@inat_id, "https://mushroomobserver.org/observations/42",
                    ofv_id: 99)]

    result, client = run_backfill([page])

    assert_equal([[99, "42"]], client.writes,
                 "the MO id comes from the value, the ofv id from the field")
    assert_equal(1, result.counts[:rewritten])
  end

  def test_leaves_a_value_already_in_obs_form_alone
    page = [raw_obs(@inat_id, "https://mushroomobserver.org/obs/42")]

    result, client = run_backfill([page])

    assert_empty(client.writes, "re-running the pass rewrites nothing")
    assert_equal(1, result.counts[:checked])
    assert_equal(0, result.counts[:rewritten])
  end

  # #4565: these name deleted MO observations, so their form is moot.
  def test_skips_dead_link_values
    page = [raw_obs(@inat_id, "DEAD LINK: https://mushroomobserver.org/42")]

    result, client = run_backfill([page])

    assert_empty(client.writes)
    assert_equal(1, result.counts[:dead_link])
  end

  def test_counts_a_value_with_no_extractable_mo_id
    page = [raw_obs(@inat_id, "see the MO website")]

    result, client = run_backfill([page])

    assert_empty(client.writes)
    assert_equal(1, result.counts[:unparseable])
  end

  # The cursor moves per observation, not per page: a run that stops
  # part way through a page keeps the work it finished.
  def test_advances_the_cursor_past_every_observation_handled
    cursor = FakeCursor.new
    page = [raw_obs(500, "https://mushroomobserver.org/obs/1"),
            raw_obs(400, "https://mushroomobserver.org/obs/2")]

    result, = run_backfill([page], cursor: cursor)

    assert_equal(400, cursor.value, "the cursor is the last id handled")
    assert_equal(400, result.cursor)
  end

  def test_resumes_from_the_stored_cursor
    cursor = FakeCursor.new(777)

    _result, client = run_backfill([[]], cursor: cursor)

    assert_equal([777], client.searches,
                 "the first search picks up below the stored id")
  end

  def test_stops_on_the_write_quota_after_finishing_that_observation
    cursor = FakeCursor.new
    page = [raw_obs(500, "https://mushroomobserver.org/observations/1"),
            raw_obs(400, "https://mushroomobserver.org/observations/2")]

    result, client = run_backfill([page, page], cursor: cursor,
                                                budget: { max_writes: 1 })

    assert_equal(1, client.writes.size)
    assert_equal(500, cursor.value,
                 "the observation that hit the quota is passed, not redone")
    assert_not(result.complete?)
  end

  def test_stops_when_the_time_budget_is_spent
    page = [raw_obs(500, "https://mushroomobserver.org/obs/1")]

    result, client = run_backfill([page, page, page],
                                  budget: { time_limit: -1.second })

    assert_equal(1, client.searches.size, "no page is fetched after the stop")
    assert_equal(1, result.counts[:checked])
  end

  # An empty page means the walk reached the end of the corpus.
  def test_reports_a_complete_pass_on_an_empty_page
    result, = run_backfill([[]])

    assert(result.complete?)
  end

  def test_an_incomplete_run_is_not_reported_complete
    page = [raw_obs(500, "https://mushroomobserver.org/obs/1")]

    result, = run_backfill([page], budget: { time_limit: -1.second })

    assert_not(result.complete?)
  end

  # The pass exists partly to reconcile reflections the nightly batch's
  # updated_since walk stopped returning, so every observation it visits
  # is resynced from the payload the search already returned.
  def test_resyncs_the_reflection_behind_each_observation
    @obs.update_column(:reflected_at, Time.zone.now)
    applier = FakeApplier.new(status: :synced)
    page = [raw_obs(@inat_id, "https://mushroomobserver.org/obs/1")]

    result, = run_backfill([page], applier: applier)

    assert_equal([[@obs.id, [@inat_id.to_s], :unchanged]], applier.applied,
                 "absent: :unchanged -- a filtered search says nothing " \
                 "about deletion")
    assert_equal(1, result.counts[:resynced])
  end

  def test_skips_the_resync_when_the_observation_is_not_a_reflection
    applier = FakeApplier.new
    page = [raw_obs(@inat_id, "https://mushroomobserver.org/obs/1")]

    run_backfill([page], applier: applier)

    assert_empty(applier.applied, "reflected_at is nil in the fixture")
  end

  def test_handles_an_inat_observation_mo_does_not_know
    applier = FakeApplier.new
    page = [raw_obs(999_999_999, "https://mushroomobserver.org/obs/1")]

    result, = run_backfill([page], applier: applier)

    assert_empty(applier.applied)
    assert_equal(1, result.counts[:checked])
  end

  # One rejected value should not end a run with thousands to go.
  def test_counts_a_rejected_write_and_keeps_walking
    error = RestClient::UnprocessableEntity.new
    client = FakeClient.new(
      [[raw_obs(500, "https://mushroomobserver.org/observations/1"),
        raw_obs(400, "https://mushroomobserver.org/observations/2")]],
      write_error: error
    )

    result, = run_backfill(nil, client: client)

    assert_equal(2, result.counts[:write_failed])
    assert_equal(2, result.counts[:checked], "the walk continued")
  end

  def test_carries_engine_alerts_out_of_the_run
    applier = FakeApplier.new
    applier.alerts << "obs 1: photo not imported"
    page = [raw_obs(@inat_id, "https://mushroomobserver.org/obs/1")]

    result, = run_backfill([page], applier: applier)

    assert_equal(["obs 1: photo not imported"], result.alerts)
  end

  # Over a five-week pass the untouched values are the overwhelming
  # majority; logging them buries what needs checking.
  def test_logs_events_not_every_observation
    @logged = []
    page = [raw_obs(500, "https://mushroomobserver.org/obs/1"),
            raw_obs(400, "https://mushroomobserver.org/observations/2")]

    run_backfill([page])

    assert_equal(1, @logged.size, "only the rewritten value is logged")
    assert_match(/inat=400/, @logged.first)
  end
end
