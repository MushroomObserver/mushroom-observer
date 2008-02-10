require File.dirname(__FILE__) + '/../test_helper'

class VoteTest < Test::Unit::TestCase
  fixtures :observations
  fixtures :users
  fixtures :names
  fixtures :namings
  fixtures :votes

  # Create one.
  def test_create
    assert_kind_of Naming, @agaricus_campestris_naming
    assert_kind_of User, @mary
    now = Time.now
    vote = Vote.new(
        :created  => now,
        :modified => now,
        :naming   => @agaricus_campestris_naming,
        :user     => @mary,
        :value    => 50
    )
    assert vote.save, vote.errors.full_messages.join("; ")
  end

  # Change an existing one.
  def test_update
    assert_kind_of Naming, @coprinus_comatus_naming
    assert_kind_of Vote, @coprinus_comatus_owner_vote
    assert_kind_of User, @rolf
    assert_equal @rolf, @coprinus_comatus_naming.user
    assert_equal @rolf, @coprinus_comatus_owner_vote.user
    @coprinus_comatus_owner_vote.modified = Time.now
    @coprinus_comatus_owner_vote.value = 50
    assert @coprinus_comatus_owner_vote.save
    assert @coprinus_comatus_owner_vote.errors.full_messages.join("; ")
    @coprinus_comatus_owner_vote.reload
    assert_equal 50, @coprinus_comatus_owner_vote.value
  end

  # Make sure it fails if we screw up.
  def test_validate
    vote = Vote.new()
    assert !vote.save
    assert_equal 3, vote.errors.count
    assert_equal "can't be blank", vote.errors.on(:naming)
    assert_equal "can't be blank", vote.errors.on(:user)
    assert_equal "can't be blank", vote.errors.on(:value)
    vote = Vote.new(
        :naming => @coprinus_comatus_naming,
        :user   => @rolf,
        :value  => "blah"
    )
    assert !vote.save
    assert_equal 1, vote.errors.count
    assert_equal "is not a number", vote.errors.on(:value)
    vote = Vote.new(
        :naming => @coprinus_comatus_naming,
        :user   => @rolf,
        :value  => -10
    )
    assert !vote.save
    assert_equal 1, vote.errors.count
    assert_equal "out of range", vote.errors.on(:value)
  end

  # Destroy one.
  def test_destroy
    id = @coprinus_comatus_other_vote.id
    @coprinus_comatus_other_vote.destroy
    assert_raise(ActiveRecord::RecordNotFound) { Vote.find(id) }
  end
end
