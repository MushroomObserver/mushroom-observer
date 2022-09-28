# frozen_string_literal: true

class AddBlockedToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column(:users, :blocked, :boolean, default: false, null: false)
    block_byrain!
  end

  # We used to have this hard-coded in application_controller.
  def block_byrain!
    User.find(2750).update_attribute(blocked: true)
  rescue ActiveRecord::RecordNotFound
  end
end
