class AddNotesTemplateToUser < ActiveRecord::Migration
  def change
    add_column :users, :notes_template, :text
  end
end
