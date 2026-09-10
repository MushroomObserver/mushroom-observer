# frozen_string_literal: true

require("test_helper")
require("json")

# Unit tests for the resync's sequence diff engine (#4215).
class Inat::ReflectionResyncSequenceSyncTest < UnitTestCase
  ITS_LOCUS = "DNA Barcode ITS"
  ITS_BASES = "ACGTACGTACGTACGTACGTTGCA"
  LSU_BASES = "TTGCAACGTACGTACGTACGTACG"

  def setup
    @obs = observations(:imported_inat_obs)
  end

  def test_adds_new_sequence_owned_by_observation_owner
    assert_empty(@obs.sequences)
    # The fixture's notes line has no leading timestamp, which
    # RssLog#already_orphaned? reads as an orphaned log; timestamp it
    # so the model callback's entry lands.
    @obs.rss_log.update_columns(
      notes: "20250801040503 log_observation_created user dick\n"
    )

    outcome = sync(fields: [dna_field(value: ITS_BASES)])

    assert_equal(1, outcome.added)
    assert(outcome.changed?)
    seq = @obs.sequences.reload.first
    assert_not_nil(seq, "Cannot find the synced Sequence")
    assert_equal(@obs.user_id, seq.user_id,
                 "a synced sequence belongs to the observation's owner")
    assert_equal(ITS_LOCUS, seq.locus)
    assert_equal(ITS_BASES, seq.bases)
    assert_match(/log_sequence_added/, @obs.rss_log.reload.notes,
                 "the add should hit the activity log via the model")
  end

  def test_adds_multiple_variants_for_one_locus
    outcome = sync(fields: [dna_field(value: ITS_BASES),
                            dna_field(value: LSU_BASES)])

    assert_equal(2, outcome.added)
    assert_equal(2, @obs.sequences.reload.count,
                 "both variants of the locus should be created")
  end

  def test_matching_bases_with_formatting_differences_is_a_noop
    @obs.sequences.create!(user: @obs.user, locus: ITS_LOCUS,
                           bases: "1 #{ITS_BASES[0, 12]}\n" \
                                  "13 #{ITS_BASES[12..]}")

    outcome = sync(fields: [dna_field(value: ITS_BASES)])

    assert_not(outcome.changed?,
               "formatting-only differences must not resync")
    assert_equal(1, @obs.sequences.reload.count)
  end

  def test_updates_bases_in_place_for_unambiguous_locus_edit
    seq = @obs.sequences.create!(user: @obs.user, locus: ITS_LOCUS,
                                 bases: LSU_BASES)

    outcome = sync(fields: [dna_field(value: ITS_BASES)])

    assert_equal(1, outcome.updated)
    assert_equal(0, outcome.added)
    assert_equal(ITS_BASES, seq.reload.bases,
                 "an unambiguous locus pairing updates in place")
  end

  def test_unpairable_locus_resolves_by_delete_and_create
    @obs.sequences.create!(user: @obs.user, locus: ITS_LOCUS,
                           bases: LSU_BASES)
    @obs.sequences.create!(user: @obs.user, locus: ITS_LOCUS,
                           bases: LSU_BASES.reverse)

    outcome = sync(fields: [dna_field(value: ITS_BASES)])

    assert_equal(2, outcome.removed)
    assert_equal(1, outcome.added)
    assert_empty(outcome.alerts)
    assert_equal([ITS_BASES], @obs.sequences.reload.map(&:bases),
                 "the mirror resolves an unpairable locus by " \
                 "replacing its sequences with iNat's")
  end

  def test_sequence_absent_from_inat_is_deleted
    @obs.sequences.create!(user: @obs.user, locus: ITS_LOCUS,
                           bases: LSU_BASES)

    outcome = sync(fields: [])

    assert_equal(1, outcome.removed)
    assert(outcome.changed?)
    assert_empty(@obs.sequences.reload,
                 "sequences on a reflection are source-owned: one " \
                 "removed on iNat is removed from the mirror")
  end

  def test_invalid_inat_value_is_rejected_with_alert
    outcome = sync(fields: [dna_field(value: "!!!not-a-sequence-99!!!")])

    assert_equal(0, outcome.added)
    assert_equal(1, outcome.alerts.length)
    assert_match(/rejected/, outcome.alerts.first)
    assert_empty(@obs.sequences.reload)
  end

  def test_apply_reports_synced_and_prefixes_alerts
    resync = Inat::ReflectionResync.new
    raw = mock_raw("calostoma_lutescens")
    raw[:ofvs] += [dna_field(value: ITS_BASES),
                   dna_field(value: "junk99!!!")]
    by_id = { @obs.import_link.external_id.to_s => raw }

    result = resync.call(@obs, by_id, false)

    assert_equal(:synced, result.status,
                 "a sequence-only change should count as synced")
    assert_equal(1, @obs.sequences.reload.count)
    assert_equal(1, resync.sequence_alerts.length)
    assert_match(/\AReflection obs #{@obs.id} /,
                 resync.sequence_alerts.first,
                 "batch alerts must identify the reflection")
  end

  private

  def dna_field(value:, name: ITS_LOCUS)
    { field_id: 999, name: name, datatype: "dna", value: value }
  end

  def mock_raw(filename)
    JSON.parse(File.read("test/inat/#{filename}.txt"),
               symbolize_names: true)[:results].first
  end

  def sync(fields:)
    inat_obs = Inat::Obs.new(JSON.generate({ id: 1, ofvs: fields }))
    Inat::ReflectionResync::SequenceSync.new.call(@obs, inat_obs)
  end
end
