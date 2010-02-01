class Synchronization < ActiveRecord::Migration

  #=================================================
  #  Migrate up.
  #=================================================

  def self.up
#     # ------------------------------------------
#     #  Add sync_id and modified to everything.
#     # ------------------------------------------
# 
#     # Add "sync id" to all tables we want to sync with other servers.
#     for table in [
#       :comments,
#       :images,
#       :interests,
#       :licenses,
#       :namings,
#       :notifications,
#       :observations,
#       :projects,
#       :species_lists,
#       :synonyms,
#       :user_groups,
#       :users,
#       :votes,
#       :locations,
#       :names,
#     ]
#       add_column table, :sync_id, :string, :limit => 16
#       User.connection.update("UPDATE #{table} SET sync_id = CONCAT(id,'us1')")
#     end
# 
#     # These need "modified" columns so we can tell which records are new.
#     # (Yes, these are no longer necessary now that we're doing a transaction
#     # log, but I think they're still good to have around.)
#     add_column :comments,       :modified, :datetime
#     add_column :interests,      :modified, :datetime
#     add_column :licenses,       :modified, :datetime
#     add_column :naming_reasons, :modified, :datetime
#     add_column :notifications,  :modified, :datetime
#     add_column :users,          :modified, :datetime
# 
#     # Rename these columns so that everything is consistent.
#     # (Sorry, I'd already done all this, so lets just keep it.)
#     add_column :projects,         :created,  :datetime
#     add_column :user_groups,      :created,  :datetime
#     add_column :draft_names,      :created,  :datetime
#     add_column :projects,         :modified, :datetime
#     add_column :user_groups,      :modified, :datetime
#     add_column :draft_names,      :modified, :datetime
#     add_column :past_draft_names, :modified, :datetime
#     User.connection.update('UPDATE projects         SET modified = updated_at, created = created_at')
#     User.connection.update('UPDATE user_groups      SET modified = updated_at, created = created_at')
#     User.connection.update('UPDATE draft_names      SET modified = updated_at, created = created_at')
#     User.connection.update('UPDATE past_draft_names SET modified = updated_at')
#     remove_column :projects,         :updated_at
#     remove_column :user_groups,      :updated_at
#     remove_column :draft_names,      :updated_at
#     remove_column :past_draft_names, :updated_at
#     remove_column :projects,         :created_at
#     remove_column :user_groups,      :created_at
#     remove_column :draft_names,      :created_at
# 
# #     #---------------------------------------------------------
# #     #  Move name and draft descriptions into separate table.
# #     #---------------------------------------------------------
# #
# #     create_table 'descriptions', :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8', :force => true do |t|
# #       t.column 'sync_id',        :string,  :limit => 16
# #       t.column 'version',        :integer
# #       t.column 'created',        :datetime
# #       t.column 'modified',       :datetime
# #       t.column 'user_id',        :integer
# #       t.column 'name_id',        :integer
# #
# #       t.column 'num_views',      :integer, :default => 0
# #       t.column 'last_view',      :datetime
# #       t.column 'review_status',  :enum,    :default => :unreviewed, :limit => [:unreviewed, :unvetted, :vetted, :inaccurate]
# #       t.column 'last_review'     :datetime
# #       t.column 'reviewer_id'     :integer
# #       t.column 'ok_for_export',  :boolean, :default => true, :null => false
# #
# #       t.column 'permission',     :enum,   :default => :All, :null => false, :limit => [:All, :Project, :Authors]
# #       t.column 'visibility',     :enum,   :default => :All, :null => false, :limit => [:All, :Project, :Authors]
# #       t.column 'locale',         :string, :default => 'en-US', :limit => 8
# #       t.column 'project_id',     :integer
# #       t.column 'source_id',      :integer
# #       t.column 'license_id',     :integer
# #
# #       t.column 'gen_desc',       :text
# #       t.column 'diag_desc',      :text
# #       t.column 'distribution',   :text
# #       t.column 'habitat',        :text
# #       t.column 'look_alikes',    :text
# #       t.column 'uses',           :text
# #       t.column 'notes',          :text
# #       t.column 'refs',           :text
# #     end
# #
# #     create_table 'past_descriptions', :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8', :force => true do |t|
# #       t.column 'description_id', :integer
# #       t.column 'version',        :integer
# #       t.column 'modified',       :datetime
# #       t.column 'user_id',        :integer
# #
# #       t.column 'permission',     :enum,   :default => :All, :null => false, :limit => [:All, :Project, :Authors]
# #       t.column 'visibility',     :enum,   :default => :All, :null => false, :limit => [:All, :Project, :Authors]
# #       t.column 'locale',         :string, :default => 'en-US', :limit => 8
# #       t.column 'project_id',     :integer
# #       t.column 'source_id',      :integer
# #       t.column 'license_id',     :integer
# #
# #       t.column 'gen_desc',       :text
# #       t.column 'diag_desc',      :text
# #       t.column 'distribution',   :text
# #       t.column 'habitat',        :text
# #       t.column 'look_alikes',    :text
# #       t.column 'uses',           :text
# #       t.column 'notes',          :text
# #       t.column 'refs',           :text
# #     end
# #
# #     names_cols = [
# #       'id', 'version', 'created', 'modified', 'user_id',
# #       'num_views', 'last_view', 'review_status', 'last_review', 'reviewer_id', 'ok_for_export',
# #       'license_id',
# #       'gen_desc', 'diag_desc', 'distribution', 'habitat', 'look_alikes', 'uses', 'notes', 'refs'
# #     ]
# #
# #     draft_names_cols = [
# #       'name_id', 'version', 'created', 'modified', 'user_id',
# #       'review_status', 'last_review', 'reviewer_id',
# #       'project_id', 'license_id',
# #       'gen_desc', 'diag_desc', 'distribution', 'habitat', 'look_alikes', 'uses', 'notes', 'refs'
# #     ]
# #
# #     past_names_cols = [
# #       'name_id', 'version', 'modified', 'user_id',
# #       'license_id',
# #       'gen_desc', 'diag_desc', 'distribution', 'habitat', 'look_alikes', 'uses', 'notes', 'refs'
# #     ]
# #
# #     past_draft_names_cols = [
# #       'draft_name_id', 'version', 'modified', 'user_id',
# #       'project_id', 'license_id',
# #       'gen_desc', 'diag_desc', 'distribution', 'habitat', 'look_alikes', 'uses', 'notes', 'refs'
# #     ]
# #
# #     num_names = copy_table('names', 'descriptions', 'name_id', names_cols)
# #     copy_table('draft_names', 'descriptions', 'name_id', draft_names_cols)
# #     copy_table('past_names', 'past_descriptions', 'description_id', past_names_cols)
# #     copy_table('past_draft_names', 'past_descriptions', 'description_id', past_draft_names_cols, num_names)
# #
# #     remove_column :names, :license_id
# #     remove_column :names, :gen_desc
# #     remove_column :names, :diag_desc
# #     remove_column :names, :distribution
# #     remove_column :names, :habitat
# #     remove_column :names, :look_alikes
# #     remove_column :names, :uses
# #     remove_column :names, :notes
# #     remove_column :names, :refs
# #
# #     remove_column :past_names, :license_id
# #     remove_column :past_names, :gen_desc
# #     remove_column :past_names, :diag_desc
# #     remove_column :past_names, :distribution
# #     remove_column :past_names, :habitat
# #     remove_column :past_names, :look_alikes
# #     remove_column :past_names, :uses
# #     remove_column :past_names, :notes
# #     remove_column :past_names, :refs
# #
# #     # (These really never should've been versioned to start with.)
# #     remove_column :past_names, :reviewer_id
# #     remove_column :past_names, :last_review
# #     remove_column :past_names, :review_status
# #     remove_column :past_names, :ok_for_export
# #     remove_column :past_locations, :location_id
# #
# #     # No longer need draft names at all!
# #     drop_table :draft_names
# #     drop_table :past_draft_names
# #
# #     # Set the permissions correctly for the erstwhile draft names.
# #     Name.connection.update %(
# #       UPDATE `descriptions`
# #       SET `permission` = 'Authors', `visibility` = 'Project'
# #       WHERE `id` > num_names
# #     )
# #     Name.connection.update %(
# #       UPDATE `past_descriptions`
# #       SET `permission` = 'Authors', `visibility` = 'Project'
# #       WHERE `id` > num_names
# #     )
# 
#     #-------------------------------------
#     #  Add some stuff to the user table.
#     #-------------------------------------
# 
#     # Add country preference and admin property to user.
#     add_column :users, :admin, :boolean
#     add_column :users, :created_here, :boolean
#     add_column :users, :alert, :text
# 
#     # Provide correct defaults for new admin and created_here columns.
#     User.connection.update %(
#       UPDATE `users` SET `admin` = TRUE WHERE `login` IN ('nathan', 'jason')
#     )
#     User.connection.update %(
#       UPDATE `users` SET `created_here` = TRUE
#     )
# 
#     #-----------------------------
#     #  Create a transaction log.
#     #-----------------------------
# 
#     create_table 'transactions', :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8', :force => true do |t|
#       t.column 'modified', :datetime
#       t.column 'query',    :text
#     end
# 
# #     #-----------------------------
# #     #  Create tag table. TODO
# #     #-----------------------------
# #
# #     create_table 'rdfs', :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8', :force => true do |t|
# #       t.column 'modified',  :datetime
# #       t.column 'subject',   :text
# #       t.column 'predicate', :text
# #       t.column 'object',    :text
# #     end
# 
#     #---------------------------------------
#     #  Fix flavors in queued_emails table.
#     #---------------------------------------
# 
#     add_column :queued_emails, :flavor2, :string, :limit => 40
# 
#     for flavor in [
#       'comment',
#       'consensus_change',
#       'feature',
#       'location_change',
#       'name_change',
#       'name_proposal',
#       'naming',
#       'observation_change',
#       'publish'
#     ]
#       flavor2 = 'QueuedEmail::' + flavor.camelize
#       User.connection.update %(
#         UPDATE `queued_emails` SET `flavor2` = '#{flavor2}'
#         WHERE `flavor` = '#{flavor}'
#       )
#     end
# 
#     remove_column :queued_emails, :flavor
# 
#     add_column :queued_emails, :flavor, :string, :limit => 40
#     User.connection.update("UPDATE `queued_emails` SET `flavor` = `flavor2`")
#     remove_column :queued_emails, :flavor2
# 
#     #---------------------------------------------------------
#     #  For some reason we were forcing votes to be integers.
#     #---------------------------------------------------------
# 
#     add_column :votes, :value2, :integer
#     Vote.connection.update("UPDATE `votes` SET `value2`=`value`")
#     remove_column :votes, :value
# 
#     add_column :votes, :value, :float
#     Vote.connection.update("UPDATE `votes` SET `value`=`value2`")
#     remove_column :votes, :value2
# 
#     #-----------------------------------------------
#     #  These are not used anywhere (or redundant).
#     #-----------------------------------------------
# 
#     remove_column :images,     :title
#     remove_column :rss_logs,   :synonym_id
#     remove_column :namings,    :review_status
#     remove_column :names,      :misspelling
#     remove_column :past_names, :misspelling
# 
#     #-----------------------------------------------------
#     #  Convert SearchState and SequenceState into Query.
#     #-----------------------------------------------------

drop_table :queries
    create_table 'queries', :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8', :force => true do |t|
      t.column 'modified',     :datetime
      t.column 'access_count', :integer
      t.column 'user_id',      :integer
      t.column 'model',        :enum, :limit => Query.all_models
      t.column 'flavor',       :enum, :limit => Query.all_flavors
      t.column 'params',       :text
      t.column 'outer_id',     :integer
    end

#     drop_table :search_states
#     drop_table :sequence_states
  end

  #=================================================
  #  Migrate down.
  #=================================================

  def self.down
#     raise "Sorry! This and the next migration can't be reversed without great difficulty."
  end

  #=================================================
  #  Copy table.
  #=================================================

  def copy_table(src_table, dest_table, target_id_col, src_cols, id_offset=nil)
    rows = User.connection.select_rows %(
      SELECT `#{src_cols.join('`,`')}` FROM #{src_table}
    )
    dest_cols = src_cols.dup
    src_cols[0] = target_id_col
    User.connection.insert %(
      INSERT INTO #{dest_table} (`#{dest_cols.join('`,`')}`)
      VALUES (#{
        rows.map do |row|
          row[0] = (row[0].to_i + id_offset).to_s if id_offset
          row.map do |val|
            "'" + val.gsub('\\', '\\\\').gsub("'", "''") + "'"
          end.join(',')
        end.join('),(')
      })
    )
  end

end
