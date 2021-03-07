# frozen_string_literal: true

require("test_helper")

class ContestBallotsControllerTest < FunctionalTestCase
  def test_index
    before = ContestVote.count
    login(:rolf)
    get(:index)
    assert_response(:success)
    assert_equal(before + ContestEntry.count, ContestVote.count)
  end

  def test_create
    user = users(:rolf)
    login(:rolf)
    make_admin
    ContestVote.find_or_create_votes(user)
    vote_one = user.contest_votes.first
    value_one = vote_one.vote
    value_two = user.contest_votes.second.vote
    assert_not_equal(value_one, value_two)
    params = {
      contest_ballot: {
        confirmed: "1",
        "vote_#{vote_one.id}" => value_two # change the value of vote_one
      }
    }
    post(:create, params)
    assert_equal(vote_one.reload.vote, value_two)
    params = {
      contest_ballot: {
        confirmed: "1",
        "vote_#{vote_one.id}" => value_one # change the value back
      }
    }
    post(:create, params)
    assert_equal(vote_one.reload.vote, value_one)
  end

  def test_create_with_no_change
    user = users(:rolf)
    login(:rolf)
    make_admin
    ContestVote.find_or_create_votes(user)
    vote_one = user.contest_votes.first
    value_one = vote_one.vote
    params = {
      contest_ballot: {
        confirmed: "1",
        "vote_#{vote_one.id}" => value_one
      }
    }
    post(:create, params)
    assert_equal(vote_one.reload.vote, value_one)
  end

  def test_create_with_bad_value
    user = users(:rolf)
    login(:rolf)
    make_admin
    ContestVote.find_or_create_votes(user)
    vote_one = user.contest_votes.first
    value_one = vote_one.vote
    params = {
      contest_ballot: {
        confirmed: "1",
        "vote_#{vote_one.id}" => "bad vote"
      }
    }
    post(:create, params)
    assert_equal(vote_one.reload.vote, value_one)
  end
end
