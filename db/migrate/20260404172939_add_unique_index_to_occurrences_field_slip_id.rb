# frozen_string_literal: true

class AddUniqueIndexToOccurrencesFieldSlipId < ActiveRecord::Migration[7.2]
  def change
    remove_index(:occurrences, :field_slip_id)
    add_index(:occurrences, :field_slip_id, unique: true)
  end
end
