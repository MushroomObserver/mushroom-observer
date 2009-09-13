class References < ActiveRecord::Migration
  def self.up
    add_column :names, :refs, :text
    add_column :past_names, :refs, :text
    add_column :draft_names, :refs, :text
    add_column :past_draft_names, :refs, :text
  end

  def self.down
    remove_column :names, :refs
    remove_column :past_names, :refs
    remove_column :draft_names, :refs
    remove_column :past_draft_names, :refs
  end
end
