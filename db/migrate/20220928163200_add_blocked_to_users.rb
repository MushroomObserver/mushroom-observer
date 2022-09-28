# frozen_string_literal: true

class AddBlockedToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column(:users, :blocked, :boolean, default: false, null: false)
  end
end
