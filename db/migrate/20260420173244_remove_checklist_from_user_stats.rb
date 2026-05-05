# frozen_string_literal: true

class RemoveChecklistFromUserStats < ActiveRecord::Migration[7.2]
  def change
    remove_column(:user_stats, :checklist, :string)
  end
end
