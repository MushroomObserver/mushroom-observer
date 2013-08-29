# encoding: utf-8
require File.expand_path(File.dirname(__FILE__) + '/../boot.rb')

class VoteTest < UnitTestCase

  # Create one.
  def test_create
    assert_kind_of(Naming, namings(:agaricus_campestris_naming))
    assert_kind_of(User, @mary)
    now = Time.now
    vote = Vote.new(
        :created_at => now,
        :updated_at => now,
        :naming     => namings(:agaricus_campestris_naming),
        :user       => @mary,
        :value      => 1
    )
    assert(vote.save, vote.errors.full_messages.join("; "))
  end

  # Change an existing one.
  def test_update
    assert_kind_of(Naming, namings(:coprinus_comatus_naming))
    assert_kind_of(Vote, votes(:coprinus_comatus_owner_vote))
    assert_kind_of(User, @rolf)
    assert_equal(@rolf, namings(:coprinus_comatus_naming).user)
    assert_equal(@rolf, votes(:coprinus_comatus_owner_vote).user)
    votes(:coprinus_comatus_owner_vote).updated_at = Time.now
    votes(:coprinus_comatus_owner_vote).value = 1
    assert(votes(:coprinus_comatus_owner_vote).save)
    assert(votes(:coprinus_comatus_owner_vote).errors.full_messages.join("; "))
    votes(:coprinus_comatus_owner_vote).reload
    assert_equal(1, votes(:coprinus_comatus_owner_vote).value)
  end

  # Make sure it fails if we screw up.
  def test_validate
    vote = Vote.new
    assert !vote.save
    assert_equal(:validate_vote_naming_missing.t, vote.errors.on(:naming))
    assert_equal(:validate_vote_user_missing.t, vote.errors.on(:user))
    assert_equal(:validate_vote_value_missing.t, vote.errors.on(:value))
    assert_equal(3, vote.errors.count)

    vote = Vote.new(
        :naming => namings(:coprinus_comatus_naming),
        :user   => @rolf,
        :value  => "blah"
    )
    assert !vote.save
    assert_equal(:validate_vote_value_not_integer.t, vote.errors.on(:value))
    assert_equal(1, vote.errors.count)

    vote = Vote.new(
        :naming => namings(:coprinus_comatus_naming),
        :user   => @rolf,
        :value  => -10
    )
    assert !vote.save
    assert_equal(:validate_vote_value_out_of_bounds.t, vote.errors.on(:value))
    assert_equal(1, vote.errors.count)
  end

  # Destroy one.
  def test_destroy
    id = votes(:coprinus_comatus_other_vote).id
    votes(:coprinus_comatus_other_vote).destroy
    assert_raise(ActiveRecord::RecordNotFound) { Vote.find(id) }
  end
end
