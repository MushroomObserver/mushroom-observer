class MinEolFields < ActiveRecord::Migration
  def self.up
    for f in Name.new_note_fields:
      add_column :names, f, :text
      add_column :past_names, f, :text
    end
  end

  def self.down
    for f in Name.new_note_fields:
      remove_column :names, f
      remove_column :past_names, f
    end
  end
end
