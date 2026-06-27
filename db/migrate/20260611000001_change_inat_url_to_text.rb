# frozen_string_literal: true

class ChangeInatURLToText < ActiveRecord::Migration[7.2]
  def up
    change_column :inat_imports, :inat_url, :text
  end

  def down
    change_column :inat_imports, :inat_url, :string
  end
end
