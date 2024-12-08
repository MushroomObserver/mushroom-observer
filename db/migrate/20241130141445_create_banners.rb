# frozen_string_literal: true

class CreateBanners < ActiveRecord::Migration[7.1]
  def change
    create_table(:banners) do |t|
      t.text(:message)
      t.integer(:version)

      t.timestamps
    end
  end
end
