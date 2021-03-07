# frozen_string_literal: true

class ContestVote < ApplicationRecord
  belongs_to :contest_entry
  belongs_to :user

  def self.find_or_create_votes(user)
    user_vote_count = ContestVote.where(user: user).count
    if user_vote_count < ContestEntry.count
      ContestEntry.all.shuffle.each do |entry|
        next unless entry.contest_votes.where(user: user).empty?

        user_vote_count += 1
        ContestVote.create!(contest_entry: entry,
                            user: user,
                            vote: user_vote_count,
                            confirmed: false)
      end
    end
    ContestVote.where(user: user).order(:vote)
  end
end
