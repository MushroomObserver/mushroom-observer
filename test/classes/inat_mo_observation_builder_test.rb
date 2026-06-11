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
    def initialize(sequences:, provisional_name:, quality_grade:)
      @sequences = sequences
      @provisional_name = provisional_name
      @quality_grade = quality_grade
    end

    attr_reader :sequences, :provisional_name

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

  private

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
