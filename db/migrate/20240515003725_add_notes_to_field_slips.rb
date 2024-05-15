# frozen_string_literal: true

class AddNotesToFieldSlips < ActiveRecord::Migration[7.1]
  def change
    add_column(:field_slips, :notes, :text)
  end
end
