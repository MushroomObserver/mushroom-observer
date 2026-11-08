# frozen_string_literal: true

class AddPasswordResetRequiredToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column(:users, :password_reset_required, :boolean,
               default: false, null: false)
  end
end
