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
                   name_override: nil)
      @sequences = sequences
      @provisional_name = provisional_name
      @quality_grade = quality_grade
      @name_override = name_override
    end

    attr_reader :sequences, :provisional_name, :name_override

    def [](key)
      { quality_grade: @quality_grade, license_code: "cc-by" }[key]
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

  # An accepted Community ID with no provisional name: a single naming.
  def test_proposed_namings_single_accepted
    assert_equal([["Lactarius alpinus", Vote::MAXIMUM_VOTE]],
                 proposed(community: names(:lactarius_alpinus)))
  end

  # A deprecated Community ID is corrected: its preferred synonym leads, the
  # deprecated name follows at Could Be. (Applies to all imports.)
  def test_proposed_namings_deprecated_community_adds_preferred_synonym
    assert_equal([["Lactarius alpinus", Vote::MAXIMUM_VOTE],
                  ["Lactarius alpigenes", Vote::MIN_POS_VOTE]],
                 proposed(community: names(:lactarius_alpigenes)))
  end

  # A provisional name (not deprecated) leads; the Community ID follows.
  def test_proposed_namings_provisional_leads
    assert_equal([["Lactarius alpinus", Vote::MAXIMUM_VOTE],
                  ["Peltigera", Vote::MIN_POS_VOTE]],
                 proposed(community: names(:peltigera),
                          provisional: names(:lactarius_alpinus)))
  end

  # The provisional is deprecated in favor of the Community ID (the Leccinum
  # scenario): the accepted name leads, the deprecated provisional follows,
  # and the synonym-of-the-provisional dedups with the Community ID.
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

  # Provisional equal to the Community ID collapses to a single naming.
  def test_proposed_namings_provisional_equals_community
    assert_equal([["Lactarius alpinus", Vote::MAXIMUM_VOTE]],
                 proposed(community: names(:lactarius_alpinus),
                          provisional: names(:lactarius_alpinus)))
  end

  # --- Species Name Override (#4533) ---

  # The override leads ahead of the Community ID.
  def test_proposed_namings_override_leads_over_community
    assert_equal([["Lactarius alpinus", Vote::MAXIMUM_VOTE],
                  ["Peltigera", Vote::MIN_POS_VOTE]],
                 proposed(community: names(:peltigera),
                          override: names(:lactarius_alpinus)))
  end

  # The override outranks BOTH the provisional name and the Community ID;
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

  private

  def builder_for(provisional_name: nil, name_override: nil)
    fake = FakeInatObs.new(sequences: [], quality_grade: "needs_id",
                           provisional_name: provisional_name,
                           name_override: name_override)
    Inat::MoObservationBuilder.new(inat_obs: fake, user: users(:rolf),
                                   inat_source: :stub)
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
    # inat_source: :stub keeps the constructor from hitting Source.inaturalist.
    Inat::MoObservationBuilder.new(
      inat_obs: fake, user: users(:rolf), inat_source: :stub
    ).send(:naming_vote)
  end
end
