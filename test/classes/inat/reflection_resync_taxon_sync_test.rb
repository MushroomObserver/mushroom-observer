# frozen_string_literal: true

require("test_helper")
require("json")

# Unit tests for the resync's taxon diff engine (#4215).
class Inat::ReflectionResyncTaxonSyncTest < UnitTestCase
  def setup
    @obs = observations(:imported_inat_obs)
    @obs.update_column(:reflected_at, Time.zone.now)
    @site = ExternalSite.inaturalist
    @importer = @obs.user
    @raw = mock_raw("agrocybe_arvalis") # Research Grade, importable
    @old = names(:agaricus_campestris)
    @new = names(:coprinus_comatus)
  end

  def test_unchanged_identification_is_a_noop
    naming = import_naming(@new, Vote::NEXT_BEST_VOTE)

    outcome = sync(fresh)

    assert_not(outcome.changed?)
    assert_equal(1, @obs.namings.reload.count)
    assert_equal(Vote::NEXT_BEST_VOTE, importer_vote(naming).value)
  end

  def test_taxon_change_adds_the_new_lead_and_demotes_the_old
    old_naming = import_naming(@old, Vote::NEXT_BEST_VOTE)

    outcome = sync(fresh)

    assert_equal(1, outcome.added)
    assert(outcome.changed?)
    new_naming = @obs.namings.reload.find_by(name: @new)
    assert_not_nil(new_naming, "Cannot find the new lead naming")
    assert_equal(@site.id, new_naming.external_site_id,
                 "the engine stamps the naming it creates")
    assert_equal(@importer, new_naming.user)
    assert_equal(Vote::NEXT_BEST_VOTE, importer_vote(new_naming).value,
                 "Research Grade leads at Promising")
    assert_equal(@site.id, importer_vote(new_naming).external_site_id)
    assert_equal(Vote::MIN_POS_VOTE, importer_vote(old_naming).value,
                 "the old lead stays as a naming at Could Be")
    assert_equal(@new, @obs.reload.name, "the consensus follows the source")
  end

  def test_sequence_on_an_occurrence_sibling_makes_the_lead_maximum
    native = observations(:minimal_unknown_obs)
    occurrence = Occurrence.create!(user: @importer,
                                    primary_observation: native)
    [native, @obs].each { |o| o.update_column(:occurrence_id, occurrence.id) }
    native.sequences.create!(user: native.user, locus: "ITS",
                             bases: "ACGTACGTACGTACGT")

    sync(fresh)

    naming = @obs.namings.reload.find_by(name: @new)
    assert_equal(Vote::MAXIMUM_VOTE, importer_vote(naming).value,
                 "a native sibling's sequence is evidence for the specimen")
  end

  def test_a_persons_naming_and_vote_are_untouched
    rolf = users(:rolf)
    naming = Naming.create!(observation: @obs, user: rolf, name: @old,
                            reasons: { 1 => "" })
    Vote.create!(naming: naming, user: rolf, observation: @obs,
                 value: Vote::MAXIMUM_VOTE)

    sync(fresh)

    naming.reload
    assert_nil(naming.external_site_id)
    assert_equal(Vote::MAXIMUM_VOTE, naming.votes.find_by(user: rolf).value)
  end

  def test_importer_naming_predating_the_marker_is_adopted
    naming = Naming.create!(observation: @obs, user: @importer, name: @new,
                            reasons: { 2 => "import" })
    Vote.create!(naming: naming, user: @importer, observation: @obs,
                 value: Vote::NEXT_BEST_VOTE)

    outcome = sync(fresh)

    assert_equal(0, outcome.added, "adopted, not duplicated")
    assert_equal(@site.id, naming.reload.external_site_id)
    assert_equal(@site.id, importer_vote(naming).external_site_id)
  end

  # Naming rejects a second proposal of the same name by the same user,
  # and a person's naming is not ours to duplicate: the source votes on
  # the naming already there.
  def test_a_name_a_person_already_proposed_is_voted_on_not_duplicated
    rolf = users(:rolf)
    naming = Naming.create!(observation: @obs, user: rolf, name: @new,
                            reasons: { 1 => "" })
    Vote.create!(naming: naming, user: rolf, observation: @obs,
                 value: Vote::MIN_POS_VOTE)

    outcome = sync(fresh)

    assert_equal(0, outcome.added, "no duplicate naming is created")
    assert_equal(1, @obs.namings.reload.where(name: @new).count)
    assert_nil(naming.reload.external_site_id,
               "the person's naming is not claimed")
    assert_equal(Vote::MIN_POS_VOTE, naming.votes.find_by(user: rolf).value,
                 "the person's vote is untouched")
    vote = naming.votes.find_by(user: @importer)
    assert_not_nil(vote, "the source votes on the existing naming")
    assert_equal(Vote::NEXT_BEST_VOTE, vote.value)
    assert_equal(@site.id, vote.external_site_id)
  end

  # A deprecated iNat taxon leads with its MO preferred synonym, and the
  # deprecated name itself is proposed at Could Be -- unless someone has
  # already proposed it, as on obs 677718 (Leccinellum albellum,
  # deprecated in favor of Leccinum albellum).
  def test_deprecated_source_taxon_with_a_persons_synonym_naming
    deprecated = names(:lactarius_kuehneri)
    preferred = deprecated.best_preferred_synonym
    assert_not_nil(preferred, "premise: the fixture has a preferred synonym")
    mary = users(:mary)
    theirs = Naming.create!(observation: @obs, user: mary, name: deprecated,
                            reasons: { 1 => "" })
    Vote.create!(naming: theirs, user: mary, observation: @obs,
                 value: Vote::MIN_POS_VOTE)

    outcome = sync(fresh(name: deprecated.text_name))

    assert_equal(1, outcome.added, "only the preferred synonym is created")
    assert_equal(1, @obs.namings.reload.where(name: deprecated).count,
                 "the deprecated name is not proposed twice")
    assert_nil(theirs.reload.external_site_id)
    lead = @obs.namings.find_by(name: preferred)
    assert_not_nil(lead, "the preferred synonym leads")
    assert_equal(Vote::NEXT_BEST_VOTE, importer_vote(lead).value)
  end

  def test_demotion_never_raises_a_vote
    old_naming = import_naming(@old, Vote::MIN_NEG_VOTE)

    sync(fresh)

    assert_equal(Vote::MIN_NEG_VOTE, importer_vote(old_naming).value)
  end

  def test_missing_mo_name_is_created_as_the_admin
    assert_nil(Name.find_by(text_name: "Agrocybe zzz"))

    outcome = sync(fresh(name: "Agrocybe zzz"))

    created = Name.find_by(text_name: "Agrocybe zzz")
    assert_not_nil(created, "the lead's MO name should have been created")
    assert_equal(User.admin, created.user)
    assert_equal(1, outcome.added)
  end

  def test_unresolvable_provisional_is_alerted_and_the_rest_proceeds
    provisional = { name: "Provisional Species Name", value: "!!!" }

    outcome = sync(fresh(ofvs: [provisional]))

    assert_equal(1, outcome.alerts.length)
    assert_match(/provisional name "!!!"/, outcome.alerts.first)
    assert_equal(1, outcome.added, "the Observation Taxon still syncs")
  end

  def test_unknown_taxon_is_left_alone
    outcome = sync(fresh(ancestor_ids: []))

    assert_not(outcome.changed?)
    assert_empty(outcome.alerts)
    assert_empty(@obs.namings.reload)
  end

  def test_resync_applies_the_engine_and_logs
    import_naming(@old, Vote::NEXT_BEST_VOTE)
    # The fixture log line has no timestamp, which RssLog reads as an
    # orphaned log; timestamp it so the resync entry lands.
    @obs.rss_log.update_columns(
      notes: "20250801040503 log_observation_created user dick\n"
    )
    link = @obs.import_link
    by_id = { link.external_id.to_s => raw_for(fresh) }

    result = Inat::ReflectionResync.new.call(@obs, by_id, false)

    assert_equal(:synced, result.status)
    assert_equal(@new, @obs.reload.name)
    assert_match(/log_observation_resynced/, @obs.rss_log.reload.notes)
  end

  private

  def import_naming(name, value)
    naming = Naming.create!(observation: @obs, user: @importer, name: name,
                            external_site: @site, reasons: { 2 => "import" })
    Vote.create!(naming: naming, user: @importer, observation: @obs,
                 value: value, external_site: @site)
    Observation::NamingConsensus.new(@obs).calc_consensus
    naming
  end

  def importer_vote(naming)
    naming.votes.reload.find_by(user: @importer)
  end

  def fresh(name: "Coprinus comatus", rank: "species", quality: "research",
            ofvs: [], ancestor_ids: nil)
    taxon = @raw[:taxon].merge(name: name, rank: rank)
    taxon[:ancestor_ids] = ancestor_ids unless ancestor_ids.nil?
    Inat::Obs.new(JSON.generate(@raw.merge(quality_grade: quality,
                                           taxon: taxon, identifications: [],
                                           ofvs: ofvs)))
  end

  def raw_for(inat_obs)
    JSON.parse(JSON.generate(inat_obs.instance_variable_get(:@obs)))
  end

  def sync(inat_obs)
    Inat::ReflectionResync::TaxonSync.new.call(@obs, inat_obs)
  end

  def mock_raw(filename)
    JSON.parse(File.read("test/inat/#{filename}.txt"),
               symbolize_names: true)[:results].first
  end
end
