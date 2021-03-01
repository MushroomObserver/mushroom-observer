class CreateContestVotes < ActiveRecord::Migration[5.2]
  def change
    create_table :contest_votes do |t|

      t.timestamps
    end
  end
end
