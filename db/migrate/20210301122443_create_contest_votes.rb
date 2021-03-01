# frozen_string_literal: true

class CreateContestVotes < ActiveRecord::Migration[5.2]
  def change
    create_table(:contest_votes, &:timestamps)
  end
end
