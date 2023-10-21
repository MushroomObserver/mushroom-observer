# frozen_string_literal: true

class AddNoEmailsToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column(:users, :no_emails, :boolean, default: false, null: false)
  end
end
