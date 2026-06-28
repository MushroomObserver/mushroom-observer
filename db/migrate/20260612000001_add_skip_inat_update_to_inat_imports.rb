# frozen_string_literal: true

class AddSkipInatUpdateToInatImports < ActiveRecord::Migration[7.2]
  def change
    add_column :inat_imports, :skip_inat_update, :boolean,
               default: false, null: false
  end
end
