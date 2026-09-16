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

  def test_override_outranks_provisional_and_community
    override = names(:peltigera)
    proposals = plan(provisional: @other, override: override).proposals

    assert_equal([override, @other, @community], proposals.map(&:name))
  end

  def test_provisional_equal_to_community_collapses
    proposals = plan(provisional: @community).proposals

    assert_equal([@community], proposals.map(&:name))
  end

  def test_deprecated_lead_yields_to_its_preferred_synonym
    deprecated = Name.where(deprecated: true).
                 detect { |n| n.best_preferred_synonym.present? }
    assert_not_nil(deprecated, "premise: a deprecated fixture with a synonym")
    proposals = Inat::NamingPlan.new(community: deprecated,
                                     lead_vote: Vote::MIN_POS_VOTE).proposals

    assert_equal(deprecated.best_preferred_synonym, proposals.first.name,
                 "the accepted synonym leads")
    assert_equal(Vote::MIN_POS_VOTE, proposals.last.vote)
    assert_includes(proposals.map(&:name), deprecated,
                    "the deprecated name is still proposed")
  end

  private

  def plan(lead_vote: Vote::MIN_POS_VOTE, **)
    Inat::NamingPlan.new(community: @community, lead_vote: lead_vote, **)
  end

  def vote_for(quality_grade:, sequence_evidence: false,
               provisional_evidence: false)
    Inat::NamingPlan.lead_vote_for(quality_grade: quality_grade,
                                   sequence_evidence: sequence_evidence,
                                   provisional_evidence: provisional_evidence)
  end
end
