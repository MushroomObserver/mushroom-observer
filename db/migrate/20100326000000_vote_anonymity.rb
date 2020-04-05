# encoding: utf-8
class VoteAnonymity < ActiveRecord::Migration[4.2]
  def self.up
    # Make default "no" (always public), except grandfather in existing users
    # as "old" (public going forward).
    add_column :users, :votes_anonymous, :enum, limit: [:no, :yes, :old], default: :no
    User.connection.update "UPDATE users SET votes_anonymous = 'old'"
  end

  def self.down
    remove_column :users, :votes_anonymous
  end
end
