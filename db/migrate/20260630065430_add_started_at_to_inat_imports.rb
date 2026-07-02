# frozen_string_literal: true

class AddStartedAtToInatImports < ActiveRecord::Migration[7.2]
  def change
    add_column(:inat_imports, :started_at, :datetime)
  end
end
