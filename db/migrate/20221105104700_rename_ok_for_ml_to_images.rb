# frozen_string_literal: true

class RenameOkForMlToImages < ActiveRecord::Migration[6.1]
  def change
    rename_column(:images, :ok_for_ml, :diagnostic)
  end
end
