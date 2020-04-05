class AddNotesTemplateToUser < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :notes_template, :text
  end
end
