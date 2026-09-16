# frozen_string_literal: true

require("test_helper")

# The #4212 naming weights and multi-naming rules, shared by the iNat
# importer and the resync's taxon engine.
class Inat::NamingPlanTest < UnitTestCase
  def setup
    @community = names(:coprinus_comatus)
    @other = names(:agaricus_campestris)
  end

  def test_lead_vote_follows_the_evidence
    assert_equal(Vote::MAXIMUM_VOTE,
                 vote_for(quality_grade: "casual", sequence_evidence: true),
                 "sequence data is the strongest signal")
    assert_equal(Vote::NEXT_BEST_VOTE, vote_for(quality_grade: "research"),
                 "Research Grade")
    assert_equal(Vote::NEXT_BEST_VOTE,
                 vote_for(quality_grade: "casual", provisional_evidence: true),
                 "a provisional name, resolved or not")
    assert_equal(Vote::MIN_POS_VOTE, vote_for(quality_grade: "needs_id"),
                 "no signal")
  end

  def test_lead_first_then_others_at_could_be
    proposals = plan(provisional: @other,
                     lead_vote: Vote::NEXT_BEST_VOTE).proposals

    assert_equal([@other, @community], proposals.map(&:name),
                 "the provisional leads the Observation Taxon")
    assert_equal([Vote::NEXT_BEST_VOTE, Vote::MIN_POS_VOTE],
                 proposals.map(&:vote))
  end

  # --- which names become namings, and at what weight ---
  # Lactarius alpinus is approved; L. alpigenes is deprecated in favor of it;
  # Pluteus petasatus (deprecated) has no approved synonym; Peltigera is a
  # second approved name. (See test_best_preferred_synonym in name_test.rb.)

  # An accepted Observation Taxon with no provisional name: a single naming.
  def test_proposals_single_accepted
    assert_equal([["Lactarius alpinus", Vote::MAXIMUM_VOTE]],
                 proposed(community: names(:lactarius_alpinus)))
  end

  # A deprecated Observation Taxon is corrected: its preferred synonym leads,
  # the deprecated name follows at Could Be. (Applies to all imports.)
  def test_proposals_deprecated_community_adds_preferred_synonym
    assert_equal([["Lactarius alpinus", Vote::MAXIMUM_VOTE],
                  ["Lactarius alpigenes", Vote::MIN_POS_VOTE]],
                 proposed(community: names(:lactarius_alpigenes)))
  end

  # A provisional name (not deprecated) leads; the Observation Taxon follows.
  def test_proposals_provisional_leads
    assert_equal([["Lactarius alpinus", Vote::MAXIMUM_VOTE],
                  ["Peltigera", Vote::MIN_POS_VOTE]],
                 proposed(community: names(:peltigera),
                          provisional: names(:lactarius_alpinus)))
  end

  # The provisional is deprecated in favor of the leading ID (the
  # Leccinum scenario): the accepted name leads, the deprecated provisional
  # follows, and the synonym-of-the-provisional dedups with the Observation
  # Taxon.
  def test_proposals_deprecated_provisional_prefers_accepted
    assert_equal([["Lactarius alpinus", Vote::MAXIMUM_VOTE],
                  ["Lactarius alpigenes", Vote::MIN_POS_VOTE]],
                 proposed(community: names(:lactarius_alpinus),
                          provisional: names(:lactarius_alpigenes)))
  end

  # A deprecated name with no approved synonym falls back to itself.
  def test_proposals_deprecated_without_synonym_keeps_self
    assert_equal([["Pluteus petasatus", Vote::MAXIMUM_VOTE]],
                 proposed(community: names(:pluteus_petasatus_deprecated)))
  end

  # Provisional equal to the leading ID collapses to a single naming.
  def test_proposals_provisional_equals_community
    assert_equal([["Lactarius alpinus", Vote::MAXIMUM_VOTE]],
                 proposed(community: names(:lactarius_alpinus),
                          provisional: names(:lactarius_alpinus)))
  end

  # --- Species Name Override (#4533) ---

  # The override leads ahead of the leading ID.
  def test_proposals_override_leads_over_community
    assert_equal([["Lactarius alpinus", Vote::MAXIMUM_VOTE],
                  ["Peltigera", Vote::MIN_POS_VOTE]],
                 proposed(community: names(:peltigera),
                          override: names(:lactarius_alpinus)))
  end

  # The override outranks BOTH the provisional name and the leading ID;
  # the other two follow at Could Be.
  def test_proposals_override_outranks_provisional_and_community
    assert_equal([["Coprinus comatus", Vote::MAXIMUM_VOTE],
                  ["Boletus edulis", Vote::MIN_POS_VOTE],
                  ["Peltigera", Vote::MIN_POS_VOTE]],
                 proposed(community: names(:peltigera),
                          provisional: names(:boletus_edulis),
                          override: names(:coprinus_comatus)))
  end

  # Override equal to the provisional collapses to one naming for it.
  def test_proposals_override_equals_provisional
    assert_equal([["Lactarius alpinus", Vote::MAXIMUM_VOTE],
                  ["Peltigera", Vote::MIN_POS_VOTE]],
                 proposed(community: names(:peltigera),
                          provisional: names(:lactarius_alpinus),
                          override: names(:lactarius_alpinus)))
  end

  # A deprecated override is corrected to its preferred synonym, which leads.
  def test_proposals_deprecated_override_prefers_synonym
    assert_equal([["Lactarius alpinus", Vote::MAXIMUM_VOTE],
                  ["Lactarius alpigenes", Vote::MIN_POS_VOTE],
                  ["Peltigera", Vote::MIN_POS_VOTE]],
                 proposed(community: names(:peltigera),
                          override: names(:lactarius_alpigenes)))
  end

  private

  def plan(lead_vote: Vote::MIN_POS_VOTE, **)
    Inat::NamingPlan.new(community: @community, lead_vote: lead_vote, **)
  end

  def proposed(community:, provisional: nil, override: nil)
    Inat::NamingPlan.new(community:, provisional:, override:,
                         lead_vote: Vote::MAXIMUM_VOTE).proposals.
      map { |proposal| [proposal.name.text_name, proposal.vote] }
  end

  def vote_for(quality_grade:, sequence_evidence: false,
               provisional_evidence: false)
    Inat::NamingPlan.lead_vote_for(quality_grade: quality_grade,
                                   sequence_evidence: sequence_evidence,
                                   provisional_evidence: provisional_evidence)
  end
end
