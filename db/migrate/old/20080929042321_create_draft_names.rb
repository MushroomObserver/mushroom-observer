class CreateDraftNames < ActiveRecord::Migration
  def self.up
    create_table :draft_names do |t|
      t.integer :user_id, :null => false
      t.integer :project_id, :null => false
      t.integer :name_id, :null => false
      t.integer :version, :default => 0, :null => false
      for f in Name.all_note_fields:
        t.text f
      end
      t.column :review_status, :enum, :limit => Name.all_review_statuses, :default => :unreviewed, :null => false
      t.integer :reviewer_id, :default => nil, :null => true
      t.datetime :last_review
      t.timestamps
    end

    create_table :past_draft_names do |t|
      t.integer :draft_name_id, :null => false
      t.integer :user_id, :null => false
      t.integer :project_id, :null => false
      t.integer :name_id, :null => false
      t.integer :version, :default => 0, :null => false
      for f in Name.all_note_fields:
        t.text f
      end
      t.column :review_status, :enum, :limit => Name.all_review_statuses, :default => :unreviewed, :null => false
      t.integer :reviewer_id, :default => nil, :null => true
      t.datetime :last_review
      t.datetime :updated_at
    end
  end

  def self.down
    drop_table :draft_names
    drop_table :past_draft_names
  end
end
