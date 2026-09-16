# frozen_string_literal: true

class AddStatusToFieldSlipExtracts < ActiveRecord::Migration[7.2]
  def change
    # "complete" so every existing row -- all recorded from successful
    # reads -- keeps meaning what it meant.
    add_column(:field_slip_extracts, :status, :string,
               null: false, default: "complete")
  end
end
