# frozen_string_literal: true

class CreateLogoEntries < ActiveRecord::Migration[5.2]
  def change
    create_table(:logo_entries,
                 options: "ENGINE=InnoDB DEFAULT CHARSET=utf8") do |t|
      t.integer(:image_id)
      t.timestamps
    end
  end
end
