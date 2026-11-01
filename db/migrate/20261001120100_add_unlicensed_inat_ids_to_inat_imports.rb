# frozen_string_literal: true

class AddUnlicensedInatIdsToInatImports < ActiveRecord::Migration[7.2]
  def change
    add_column(:inat_imports, :unlicensed_inat_ids, :text)
  end
end
