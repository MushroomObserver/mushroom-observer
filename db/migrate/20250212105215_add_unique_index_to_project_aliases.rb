# frozen_string_literal: true

class AddUniqueIndexToProjectAliases < ActiveRecord::Migration[7.2]
  def change
    add_index(:project_aliases, [:name, :project_id], unique: true)
  end
end
