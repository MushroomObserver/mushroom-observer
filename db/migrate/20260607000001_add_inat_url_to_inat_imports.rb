# frozen_string_literal: true

class AddInatURLToInatImports < ActiveRecord::Migration[7.2]
  def change
    add_column :inat_imports, :inat_url, :string
  end
end
