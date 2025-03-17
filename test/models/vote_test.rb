# frozen_string_literal: true

require("test_helper")

class VoteTest < UnitTestCase
  # Create one.
  def test_create
    assert_kind_of(Naming, namings(:agaricus_campestris_naming))
    assert_kind_of(User, mary)
    now = Time.current
    vote = Vote.new(
      created_at: now,
      updated_at: now,
      naming: namings(:agaricus_campestris_naming),
      user: mary,
      value: 1
    )
    assert(vote.save, vote.errors.full_messages.join("; "))
  end

  # Change an existing one.
  def test_update
    assert_kind_of(Naming, namings(:coprinus_comatus_naming))
    assert_kind_of(Vote, votes(:coprinus_comatus_owner_vote))
    assert_kind_of(User, rolf)
    assert_equal(rolf, namings(:coprinus_comatus_naming).user)
    assert_equal(rolf, votes(:coprinus_comatus_owner_vote).user)
    votes(:coprinus_comatus_owner_vote).updated_at = Time.current
    votes(:coprinus_comatus_owner_vote).value = 1
    assert(votes(:coprinus_comatus_owner_vote).save)
    assert(votes(:coprinus_comatus_owner_vote).errors.full_messages.join("; "))
    votes(:coprinus_comatus_owner_vote).reload
    assert_equal(1, votes(:coprinus_comatus_owner_vote).value)
  end

  # Make sure it fails if we screw up.
  def test_validate
    vote = Vote.new
    assert_not(vote.save)
    assert_equal(:validate_vote_naming_missing.t, vote.errors[:naming].first)
    assert_equal(:validate_vote_user_missing.t, vote.errors[:user].first)
    assert_equal(:validate_vote_value_missing.t, vote.errors[:value].first)
    assert_equal(3, vote.errors.count)

    vote = Vote.new(
      naming: namings(:coprinus_comatus_naming),
      user: rolf,
      value: "blah"
    )
    assert_not(vote.save)
    assert_equal(:validate_vote_value_not_integer.t, vote.errors[:value].first)
    assert_equal(1, vote.errors.count)

    vote = Vote.new(
      naming: namings(:coprinus_comatus_naming),
      user: rolf,
      value: -10
    )
    assert_not(vote.save)
    assert_equal(:validate_vote_value_out_of_bounds.t,
                 vote.errors[:value].first)
    assert_equal(1, vote.errors.count)
  end

  # Destroy one.
  def test_destroy
    id = votes(:coprinus_comatus_other_vote).id
    votes(:coprinus_comatus_other_vote).destroy
    assert_raise(ActiveRecord::RecordNotFound) { Vote.find(id) }
  end

  def test_scope_by_users
    votes_by_rolf = Vote.by_users(users(:rolf))
    assert_includes(votes_by_rolf, votes(:coprinus_comatus_owner_vote))
    assert_includes(votes_by_rolf,
                    votes(:coprinus_comatus_other_naming_rolf_vote))
    assert_not_includes(votes_by_rolf, votes(:amateur_vote))
  end

  def test_update_observation_views_reviewed_column
    assert_equal(0, ObservationView.all.size)
    Vote.update_observation_views_reviewed_column
    assert_equal(Vote.all.size, ObservationView.all.size)
    ObservationView.find_each do |ov|
      assert_equal(true, ov.reviewed)
    end
  end
end
