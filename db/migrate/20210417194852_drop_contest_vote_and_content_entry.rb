class DropContestVoteAndContentEntry < ActiveRecord::Migration[5.2]
  def change
    drop_table(:contest_entries,
                 options: "ENGINE=InnoDB DEFAULT CHARSET=utf8") do |t|
      t.integer(:image_id)
      t.integer(:alternate_image_id)
      t.timestamps
    end
    drop_table(:contest_votes,
                 options: "ENGINE=InnoDB DEFAULT CHARSET=utf8") do |t|
      t.integer(:contest_entry_id)
      t.integer(:user_id)
      t.integer(:vote)
      t.boolean(:confirmed)
      t.timestamps
    end
  end
end
