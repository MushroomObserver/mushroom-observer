# frozen_string_literal: true

require("test_helper")

class Observation::MergedNamingTest < UnitTestCase
  def setup
    @obs1 = observations(:minimal_unknown_obs)
    @obs2 = observations(:detailed_unknown_obs)
    @obs3 = observations(:amateur_obs)
    @obs1.update_column(:occurrence_id, nil)
    @name = names(:agaricus_campestris)
  end

  # -- votes deduplication --

  def test_votes_deduplicated_by_user_strongest_wins
    occ = create_occurrence(@obs1, @obs2)
    naming1 = Naming.create!(
      observation: @obs1, name: @name, user: rolf
    )
    naming2 = Naming.create!(
      observation: @obs2, name: @name, user: mary
    )

    # Rolf votes on both namings with different values
    Vote.create!(naming: naming1, observation: @obs1,
                 user: rolf, value: 1, favorite: true)
    Vote.create!(naming: naming2, observation: @obs2,
                 user: rolf, value: 3, favorite: false)
    # Mary votes on naming2 only
    Vote.create!(naming: naming2, observation: @obs2,
                 user: mary, value: 2, favorite: true)

    merged = build_merged_naming(occ, @obs1)
    votes = merged.votes

    # Should have 2 votes (one per user), not 3
    assert_equal(2, votes.size,
                 "Should deduplicate to one vote per user")

    rolf_vote = votes.find { |v| v.user_id == rolf.id }
    assert_equal(3, rolf_vote.value,
                 "Should keep strongest vote per user")
  end

  # -- vote_cache computation --

  def test_vote_cache_returns_weighted_aggregate
    occ = create_occurrence(@obs1, @obs2)
    naming1 = Naming.create!(
      observation: @obs1, name: @name, user: rolf
    )

    Vote.create!(naming: naming1, observation: @obs1,
                 user: rolf, value: 3, favorite: true)

    merged = build_merged_naming(occ, @obs1)
    cache = merged.vote_cache

    assert_operator(cache, :>, 0,
                    "vote_cache should be positive with a vote")
  end

  # -- multiple_proposers? --

  def test_multiple_proposers_true_when_different_users
    occ = create_occurrence(@obs1, @obs2, @obs3)
    # Only sibling namings (not on obs1) with different users
    Naming.create!(observation: @obs2, name: @name, user: rolf)
    Naming.create!(
      observation: @obs3, name: @name, user: mary
    )

    merged = build_merged_naming(occ, @obs1)
    assert(merged.multiple_proposers?,
           "Should be true with different sibling proposers")
  end

  def test_multiple_proposers_false_when_local_naming_exists
    occ = create_occurrence(@obs1, @obs2)
    # Local naming on obs1
    Naming.create!(observation: @obs1, name: @name, user: rolf)
    Naming.create!(
      observation: @obs2, name: @name, user: mary
    )

    merged = build_merged_naming(occ, @obs1)
    assert_not(merged.multiple_proposers?,
               "Should be false when local naming exists")
  end

  def test_multiple_proposers_false_when_same_user
    occ = create_occurrence(@obs1, @obs2, @obs3)
    Naming.create!(observation: @obs2, name: @name, user: rolf)
    Naming.create!(
      observation: @obs3, name: @name, user: rolf
    )

    merged = build_merged_naming(occ, @obs1)
    assert_not(merged.multiple_proposers?,
               "Should be false when same user proposed all")
  end

  # -- grouped_reasons --

  def test_grouped_reasons_with_local_and_sibling
    occ = create_occurrence(@obs1, @obs2)
    naming1 = Naming.create!(
      observation: @obs1, name: @name, user: rolf
    )
    naming2 = Naming.create!(
      observation: @obs2, name: @name, user: mary
    )
    naming1.update_reasons(1 => "Local reason")
    naming1.save!
    naming2.update_reasons(1 => "Sibling reason")
    naming2.save!

    merged = build_merged_naming(occ, @obs1)
    groups = merged.grouped_reasons

    # First entry should be local (nil observation)
    local_group = groups.find { |obs, _| obs.nil? }
    assert_not_nil(local_group, "Should have local reasons")
    assert(local_group[1].any? { |r| r.notes == "Local reason" })

    # Second entry should be sibling (obs2)
    sib_group = groups.find { |obs, _| obs == @obs2 }
    assert_not_nil(sib_group, "Should have sibling reasons")
    assert(sib_group[1].any? { |r| r.notes == "Sibling reason" })
  end

  # -- local_naming detection --

  def test_local_naming_returns_naming_on_current_obs
    occ = create_occurrence(@obs1, @obs2)
    local = Naming.create!(
      observation: @obs1, name: @name, user: rolf
    )
    Naming.create!(
      observation: @obs2, name: @name, user: mary
    )

    merged = build_merged_naming(occ, @obs1)
    assert_equal(local, merged.local_naming)
  end

  def test_local_naming_nil_when_not_on_current_obs
    occ = create_occurrence(@obs1, @obs2, @obs3)
    Naming.create!(observation: @obs2, name: @name, user: rolf)
    Naming.create!(
      observation: @obs3, name: @name, user: mary
    )

    merged = build_merged_naming(occ, @obs1)
    assert_nil(merged.local_naming)
  end

  # -- users_best_vote --

  def test_users_best_vote_returns_highest
    occ = create_occurrence(@obs1, @obs2)
    naming1 = Naming.create!(
      observation: @obs1, name: @name, user: rolf
    )
    naming2 = Naming.create!(
      observation: @obs2, name: @name, user: mary
    )

    Vote.create!(naming: naming1, observation: @obs1,
                 user: rolf, value: 1, favorite: true)
    Vote.create!(naming: naming2, observation: @obs2,
                 user: rolf, value: 3, favorite: false)

    merged = build_merged_naming(occ, @obs1)
    best = merged.users_best_vote(rolf)
    assert_equal(3, best.value)
  end

  def test_users_best_vote_nil_when_no_votes
    occ = create_occurrence(@obs1, @obs2)
    Naming.create!(observation: @obs1, name: @name, user: rolf)

    merged = build_merged_naming(occ, @obs1)
    best = merged.users_best_vote(mary)
    assert_nil(best)
  end

  # == Coverage: user, can_edit?, vote_percent, etc. ==

  def test_user_returns_local_naming_user
    occ = create_occurrence(@obs1, @obs2)
    Naming.create!(observation: @obs1, name: @name, user: rolf)
    Naming.create!(observation: @obs2, name: @name, user: mary)
    merged = build_merged_naming(occ, @obs1)
    assert_equal(rolf, merged.user)
  end

  def test_user_returns_single_sibling_user
    occ = create_occurrence(@obs1, @obs2)
    Naming.create!(observation: @obs2, name: @name, user: mary)
    merged = build_merged_naming(occ, @obs1)
    assert_equal(mary, merged.user)
  end

  def test_user_returns_nil_for_multiple_sibling_users
    occ = create_occurrence(@obs1, @obs2, @obs3)
    Naming.create!(observation: @obs2, name: @name, user: rolf)
    Naming.create!(observation: @obs3, name: @name, user: mary)
    merged = build_merged_naming(occ, @obs1)
    assert_nil(merged.user)
  end

  def test_can_edit_true_for_local_naming_owner
    occ = create_occurrence(@obs1, @obs2)
    Naming.create!(observation: @obs1, name: @name, user: rolf)
    merged = build_merged_naming(occ, @obs1)
    assert(merged.can_edit?(rolf))
  end

  def test_can_edit_nil_without_local_naming
    occ = create_occurrence(@obs1, @obs2)
    Naming.create!(observation: @obs2, name: @name, user: mary)
    merged = build_merged_naming(occ, @obs1)
    assert_nil(merged.can_edit?(rolf))
  end

  def test_vote_percent
    occ = create_occurrence(@obs1, @obs2)
    naming = Naming.create!(
      observation: @obs1, name: @name, user: rolf
    )
    Vote.create!(naming: naming, observation: @obs1,
                 user: rolf, value: Vote::MAXIMUM_VOTE,
                 favorite: true)
    merged = build_merged_naming(occ, @obs1)
    pct = merged.vote_percent
    assert_operator(pct, :>, 0)
    assert_operator(pct, :<=, 100)
  end

  # Verify MergedNaming applies the sub-max vote boost the same
  # way ConsensusCalculator does. Without the boost, the
  # denominator uses raw weight, inflating the denominator and
  # producing a lower percentage than the consensus score.
  def test_vote_cache_applies_sub_max_boost
    occ = create_occurrence(@obs1, @obs2)
    naming = Naming.create!(
      observation: @obs1, name: @name, user: rolf
    )
    # Rolf votes "I'd Call It That" (3.0)
    Vote.create!(naming: naming, observation: @obs1,
                 user: rolf, value: 3, favorite: true)
    # Mary votes "Promising" (2.0) — triggers the boost
    Vote.create!(naming: naming, observation: @obs1,
                 user: mary, value: 2, favorite: true)

    merged = build_merged_naming(occ, @obs1)
    merged_cache = merged.vote_cache

    # Recalculate via ConsensusCalculator for comparison
    namings = Naming.where(observation_id: occ.observation_ids).
              includes(:name, votes: [:observation, :user])
    calc = Observation::ConsensusCalculator.new(namings)
    calc.calc(nil)
    naming.reload
    calc_cache = naming.vote_cache

    assert_in_delta(calc_cache, merged_cache, 0.001,
                    "MergedNaming vote_cache should match " \
                    "ConsensusCalculator when boost applies")
  end

  def test_vote_cache_zero_without_votes
    occ = create_occurrence(@obs1, @obs2)
    Naming.create!(observation: @obs1, name: @name, user: rolf)
    merged = build_merged_naming(occ, @obs1)
    assert_in_delta(0.0, merged.vote_cache, 0.001)
  end

  def test_created_at_returns_earliest
    occ = create_occurrence(@obs1, @obs2)
    n1 = Naming.create!(
      observation: @obs1, name: @name, user: rolf
    )
    sleep(0.01)
    n2 = Naming.create!(
      observation: @obs2, name: @name, user: mary
    )
    merged = build_merged_naming(occ, @obs1)
    assert_equal([n1, n2].map(&:created_at).min,
                 merged.created_at)
  end

  def test_primary_naming_returns_local_when_present
    occ = create_occurrence(@obs1, @obs2)
    local = Naming.create!(
      observation: @obs1, name: @name, user: rolf
    )
    Naming.create!(observation: @obs2, name: @name, user: mary)
    merged = build_merged_naming(occ, @obs1)
    assert_equal(local, merged.primary_naming)
  end

  def test_primary_naming_returns_first_sibling_no_local
    occ = create_occurrence(@obs1, @obs2)
    sibling = Naming.create!(
      observation: @obs2, name: @name, user: mary
    )
    merged = build_merged_naming(occ, @obs1)
    assert_equal(sibling, merged.primary_naming)
  end

  def test_grouped_reasons_includes_default_reason
    occ = create_occurrence(@obs1, @obs2)
    Naming.create!(observation: @obs1, name: @name, user: rolf)
    merged = build_merged_naming(occ, @obs1)
    assert_kind_of(Array, merged.grouped_reasons)
  end

  private

  def create_occurrence(primary_obs, *other_obs)
    occ = Occurrence.create!(
      user: rolf, primary_observation: primary_obs
    )
    primary_obs.update!(occurrence: occ)
    other_obs.each { |obs| obs.update!(occurrence: occ) }
    occ
  end

  def build_merged_naming(_occ, obs)
    reloaded = Observation.naming_includes.find(obs.id)
    consensus = Observation::NamingConsensus.new(reloaded)
    consensus.merged_namings.find do |mn|
      mn.name_id == @name.id
    end
  end
end
