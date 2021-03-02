# frozen_string_literal: true

class CreateContestVotes < ActiveRecord::Migration[5.2]
  def change
    create_table(:contest_votes,
                 options: "ENGINE=InnoDB DEFAULT CHARSET=utf8") do |t|
      t.integer(:contest_entry_id)
      t.integer(:user_id)
      t.integer(:vote)
      t.boolean(:confirmed)
      t.timestamps
    end
  end
end
