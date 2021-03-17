# frozen_string_literal: true

class ContestBallotsController < ApplicationController
  before_action :login_required

  def index
    @votes = ContestVote.find_or_create_votes(@user)
  end

  def create
    count = ContestVote.where(user: @user).count
    params["contest_ballot"].each do |key, value|
      if key.starts_with?("vote_")
        break if process_vote(Integer(key.split("_")[-1], 10), value, count)
      end
    end
    confirm_votes(params["contest_ballot"]["confirmed"] == "1")
    redirect_to(contest_ballots_path)
  end

  private

  def process_vote(id, value, count)
    vote = ContestVote.find(id)
    new_vote = sanitize_value(value, count)
    if new_vote && vote.vote != new_vote
      reassign_vote(vote, new_vote)
      return true
    end
    false
  end

  def sanitize_value(value, max_value)
    [1, [max_value, Integer(value, 10)].min].max
  rescue ArgumentError
    false
  end

  def confirm_votes(confirmed)
    ContestVote.where(user: @user).where(confirmed: !confirmed).each do |vote|
      vote.update(confirmed: confirmed)
    end
  end

  def reassign_vote(vote, value)
    if vote.vote < value
      move_vote_block(vote.vote + 1, value, -1)
    else
      move_vote_block(value, vote.vote - 1, 1)
    end
    vote.update(vote: value)
  end

  def move_vote_block(low, high, delta)
    ContestVote.where(user: @user).
      where("vote >= ? and vote <= ?", low, high).each do |v|
      v.update(vote: v.vote + delta)
    end
  end
end
