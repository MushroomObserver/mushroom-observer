# frozen_string_literal: true

class CreateLogoEntries < ActiveRecord::Migration[5.2]
  def change
    create_table(:logo_entries, &:timestamps)
  end
end
