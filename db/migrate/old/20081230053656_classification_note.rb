class ClassificationNote < ActiveRecord::Migration
  def self.up
    add_column :names, :classification, :text
    add_column :past_names, :classification, :text
    add_column :draft_names, :classification, :text
    add_column :past_draft_names, :classification, :text
  end

  def self.down
    remove_column :names, :classification
    remove_column :past_names, :classification
    remove_column :draft_names, :classification
    remove_column :past_draft_names, :classification
  end
end
