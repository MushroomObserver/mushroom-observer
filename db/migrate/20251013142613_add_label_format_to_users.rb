# frozen_string_literal: true

class AddLabelFormatToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column(:users, :label_format, :integer, default: 1)
  end
end
