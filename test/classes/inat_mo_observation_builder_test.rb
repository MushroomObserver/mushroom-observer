# frozen_string_literal: true

require("test_helper")

# Unit tests for the confidence weight Inat::MoObservationBuilder assigns to
# an import's single consensus naming (#4212). The integration coverage in
# test/jobs/inat_import_job_test.rb exercises the sequence / research /
# non-research branches against recorded fixtures; this isolates naming_vote
# so every branch is pinned — including "provisional name without a sequence",
# which no real iNat fixture can produce (a prov name implies a sequence).
class InatMoObservationBuilderTest < UnitTestCase
  # Minimal stand-in for an ::Inat::Obs, exposing only what naming_vote reads.
  class FakeInatObs
    def initialize(sequences:, provisional_name:, quality_grade:,
                   name_override: nil, obs_taxon_name: nil)
      @sequences = sequences
      @provisional_name = provisional_name
      @quality_grade = quality_grade
      @name_override = name_override
      @obs_taxon_name = obs_taxon_name
    end

    attr_reader :sequences, :provisional_name, :name_override

    def name
      @obs_taxon_name
    end

    def [](key)
      { quality_grade: @quality_grade, license_code: "cc-by",
        identifications: [] }[key]
    end
  end

  # DNA evidence is the strongest signal: max vote regardless of grade or
  # whether there's a provisional name.
  def test_naming_vote_sequence_wins
    assert_equal(Vote::MAXIMUM_VOTE,
                 naming_vote(sequence: true, provisional: false,
                             quality_grade: "casual"))
    assert_equal(Vote::MAXIMUM_VOTE,
                 naming_vote(sequence: true, provisional: true,
                             quality_grade: "needs_id"))
  end

  # A provisional name (no sequence) is Promising — the branch the recorded
  # fixtures can't cover.
  def test_naming_vote_provisional_without_sequence_is_promising
    assert_equal(Vote::NEXT_BEST_VOTE,
                 naming_vote(sequence: false, provisional: true,
                             quality_grade: "needs_id"))
  end

  def test_naming_vote_research_grade_is_promising
    assert_equal(Vote::NEXT_BEST_VOTE,
                 naming_vote(sequence: false, provisional: false,
                             quality_grade: "research"))
  end

  def test_naming_vote_non_research_is_could_be
    assert_equal(Vote::MIN_POS_VOTE,
                 naming_vote(sequence: false, provisional: false,
                             quality_grade: "needs_id"))
    assert_equal(Vote::MIN_POS_VOTE,
                 naming_vote(sequence: false, provisional: false,
                             quality_grade: "casual"))
  end

  # --- proposed_namings: which names become namings, and at what weight ----
  # Lactarius alpinus is approved; L. alpigenes is deprecated in favor of it;
  # Pluteus petasatus (deprecated) has no approved synonym; Peltigera is a
  # second approved name. (See test_best_preferred_synonym in name_test.rb.)

  # An accepted Observation Taxon with no provisional name: a single naming.
  def test_proposed_namings_single_accepted
    assert_equal([["Lactarius alpinus", Vote::MAXIMUM_VOTE]],
                 proposed(community: names(:lactarius_alpinus)))
  end

  # A deprecated Observation Taxon is corrected: its preferred synonym leads,
  # the deprecated name follows at Could Be. (Applies to all imports.)
  def test_proposed_namings_deprecated_community_adds_preferred_synonym
    assert_equal([["Lactarius alpinus", Vote::MAXIMUM_VOTE],
                  ["Lactarius alpigenes", Vote::MIN_POS_VOTE]],
                 proposed(community: names(:lactarius_alpigenes)))
  end

  # A provisional name (not deprecated) leads; the Observation Taxon follows.
  def test_proposed_namings_provisional_leads
    assert_equal([["Lactarius alpinus", Vote::MAXIMUM_VOTE],
                  ["Peltigera", Vote::MIN_POS_VOTE]],
                 proposed(community: names(:peltigera),
                          provisional: names(:lactarius_alpinus)))
  end

  # The provisional is deprecated in favor of the Observation Taxon (the
  # Leccinum scenario): the accepted name leads, the deprecated provisional
  # follows, and the synonym-of-the-provisional dedups with the Observation
  # Taxon.
  def test_proposed_namings_deprecated_provisional_prefers_accepted
    assert_equal([["Lactarius alpinus", Vote::MAXIMUM_VOTE],
                  ["Lactarius alpigenes", Vote::MIN_POS_VOTE]],
                 proposed(community: names(:lactarius_alpinus),
                          provisional: names(:lactarius_alpigenes)))
  end

  # A deprecated name with no approved synonym falls back to itself.
  def test_proposed_namings_deprecated_without_synonym_keeps_self
    assert_equal([["Pluteus petasatus", Vote::MAXIMUM_VOTE]],
                 proposed(community: names(:pluteus_petasatus_deprecated)))
  end

  # Provisional equal to the Observation Taxon collapses to a single naming.
  def test_proposed_namings_provisional_equals_community
    assert_equal([["Lactarius alpinus", Vote::MAXIMUM_VOTE]],
                 proposed(community: names(:lactarius_alpinus),
                          provisional: names(:lactarius_alpinus)))
  end

  # --- Species Name Override (#4533) ---

  # The override leads ahead of the Observation Taxon.
  def test_proposed_namings_override_leads_over_community
    assert_equal([["Lactarius alpinus", Vote::MAXIMUM_VOTE],
                  ["Peltigera", Vote::MIN_POS_VOTE]],
                 proposed(community: names(:peltigera),
                          override: names(:lactarius_alpinus)))
  end

  # The override outranks BOTH the provisional name and the Observation Taxon;
  # the other two follow at Could Be.
  def test_proposed_namings_override_outranks_provisional_and_community
    assert_equal([["Coprinus comatus", Vote::MAXIMUM_VOTE],
                  ["Boletus edulis", Vote::MIN_POS_VOTE],
                  ["Peltigera", Vote::MIN_POS_VOTE]],
                 proposed(community: names(:peltigera),
                          provisional: names(:boletus_edulis),
                          override: names(:coprinus_comatus)))
  end

  # Override equal to the provisional collapses to one naming for it.
  def test_proposed_namings_override_equals_provisional
    assert_equal([["Lactarius alpinus", Vote::MAXIMUM_VOTE],
                  ["Peltigera", Vote::MIN_POS_VOTE]],
                 proposed(community: names(:peltigera),
                          provisional: names(:lactarius_alpinus),
                          override: names(:lactarius_alpinus)))
  end

  # A deprecated override is corrected to its preferred synonym, which leads.
  def test_proposed_namings_deprecated_override_prefers_synonym
    assert_equal([["Lactarius alpinus", Vote::MAXIMUM_VOTE],
                  ["Lactarius alpigenes", Vote::MIN_POS_VOTE],
                  ["Peltigera", Vote::MIN_POS_VOTE]],
                 proposed(community: names(:peltigera),
                          override: names(:lactarius_alpigenes)))
  end

  # When the iNat provisional name already exists in MO, reuse it rather than
  # posting a new one.
  def test_prov_name_reuses_existing_mo_name
    existing = names(:lactarius_alpinus)
    builder = builder_for(provisional_name: existing.text_name)
    assert_equal(existing, builder.send(:prov_name))
  end

  # An override matching an existing MO name reuses it (no API post).
  def test_override_name_reuses_existing_mo_name
    existing = names(:coprinus_comatus)
    builder = builder_for(name_override: existing.text_name)
    assert_equal(existing, builder.send(:override_name))
  end

  # An unparseable override falls back to nil so the import proceeds with the
  # provisional/Community lead.
  def test_override_name_unparseable_falls_back_to_nil
    assert_nil(builder_for(name_override: "see comments").send(:override_name))
  end

  # A failure while resolving the override (e.g. an API error) is logged and
  # falls back to nil rather than aborting the import.
  def test_override_name_falls_back_when_resolution_raises
    builder = builder_for(name_override: "Boletus edulis")
    builder.define_singleton_method(:find_or_create_name) { |_| raise("boom") }
    assert_nil(builder.send(:override_name))
  end

  # No override field => no override name.
  def test_override_name_absent_is_nil
    assert_nil(builder_for.send(:override_name))
  end

  # The override naming carries the override reason text.
  def test_override_naming_reason
    existing = names(:coprinus_comatus)
    builder = builder_for(name_override: existing.text_name)
    assert_equal("Following Species Name Override from iNat",
                 builder.send(:used_references_explanation, existing))
  end

  # The observation taxon explanation uses the inat_observation_taxon
  # translation string plus today's date.
  def test_observation_taxon_naming_reason
    name = names(:peltigera)
    expected = "#{:inat_observation_taxon.l} " \
               "#{Time.zone.today.strftime("%Y-%m-%d")}"
    assert_equal(expected,
                 builder_for(obs_taxon_name: name).
                   send(:used_references_explanation, name),
                 "Observation taxon explanation should use " \
                 "inat_observation_taxon translation key")
  end

  # When the obs taxon is a misspelling and the proposed name is its correct
  # spelling, the observation taxon explanation appends the corrected spelling
  # note.
  def test_observation_taxon_naming_reason_corrected_spelling
    misspelling = names(:petigera)
    correct = misspelling.correct_spelling
    assert(correct, "Test requires a name fixture with correct_spelling set")
    expected = "#{:inat_observation_taxon.l} " \
               "#{Time.zone.today.strftime("%Y-%m-%d")} " \
               "#{:inat_corrected_spelling.l}"
    assert_equal(expected,
                 builder_for(obs_taxon_name: misspelling).
                   send(:used_references_explanation, correct),
                 "Observation taxon explanation should append corrected " \
                 "spelling note when proposed name corrects the obs taxon")
  end

  # --- preferred_rank: ICN suffix overrides iNat rank for above-genus names --

  def test_preferred_rank_suffix_wins_over_inat_rank
    # Leucocoprineae ends in -ineae (Suborder per ICN). iNat assigns "tribe";
    # MO should create it as Suborder, which is what the suffix mandates.
    assert_equal("Suborder",
                 builder_for.send(:preferred_rank, "Leucocoprineae", "tribe"))
  end

  def test_preferred_rank_falls_back_for_unsuffixed_name
    # A plain single-word name has no disambiguating suffix; keep iNat's rank.
    assert_equal("Genus",
                 builder_for.send(:preferred_rank, "Boletus", "genus"))
  end

  def test_preferred_rank_no_change_when_inat_and_suffix_agree
    assert_equal("Order",
                 builder_for.send(:preferred_rank, "Agaricales", "order"))
    assert_equal("Family",
                 builder_for.send(:preferred_rank, "Agaricaceae", "family"))
  end

  def test_preferred_rank_defers_to_inat_for_multiword_names
    # Multi-word names (infrageneric/infraspecific) have the rank spelled out
    # in the string; skip suffix guessing and keep iNat's rank.
    assert_equal("Section",
                 builder_for.send(:preferred_rank,
                                  "Amanita section Validae", "section"))
    assert_equal("Form",
                 builder_for.send(:preferred_rank,
                                  "Inonotus obliquus form sterilis", "form"))
  end

  private

  def builder_for(provisional_name: nil, name_override: nil,
                  obs_taxon_name: nil)
    fake = FakeInatObs.new(sequences: [], quality_grade: "needs_id",
                           provisional_name: provisional_name,
                           name_override: name_override,
                           obs_taxon_name: obs_taxon_name)
    Inat::MoObservationBuilder.new(inat_obs: fake, user: users(:rolf),
                                   external_site: :stub)
  end

  def proposed(community:, provisional: nil, override: nil,
               lead_vote: Vote::MAXIMUM_VOTE)
    builder_for.send(:proposed_namings, community, provisional, override,
                     lead_vote).
      map { |name, vote| [name.text_name, vote] }
  end

  def naming_vote(sequence:, provisional:, quality_grade:)
    fake = FakeInatObs.new(
      sequences: sequence ? [:a_sequence] : [],
      provisional_name: provisional ? "Boletus sp. 'T01'" : nil,
      quality_grade: quality_grade
    )
    # external_site: :stub keeps the constructor from hitting
    # ExternalSite.inaturalist.
    Inat::MoObservationBuilder.new(
      inat_obs: fake, user: users(:rolf), external_site: :stub
    ).send(:naming_vote)
  end
end
