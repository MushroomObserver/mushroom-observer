# frozen_string_literal: true

class AddIgnoredUnlicensedCountToInatImports < ActiveRecord::Migration[7.2]
  def change
    add_column(:inat_imports, :ignored_unlicensed_count, :integer,
               default: 0, null: false)
  end
end
