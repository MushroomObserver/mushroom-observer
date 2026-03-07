# frozen_string_literal: true

class CreateOccurrences < ActiveRecord::Migration[7.2]
  def change
    create_table(:occurrences, id: :integer) do |t|
      t.integer(:user_id)
      t.integer(:default_observation_id)
      t.boolean(:has_specimen, default: false, null: false)
      t.timestamps
    end

    add_index(:occurrences, :user_id)
    add_index(:occurrences, :default_observation_id)
    add_column(:observations, :occurrence_id, :integer)
    add_index(:observations, :occurrence_id)
  end
end
