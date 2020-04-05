# encoding: utf-8
class Synchronization < ActiveRecord::Migration[4.2]
  #=================================================
  #  Migrate up.
  #=================================================

  def self.up
    # ------------------------------------------
    #  Add sync_id and modified to everything.
    # ------------------------------------------

    # Add "sync id" to all tables we want to sync with other servers.
    for table in [
      :comments,
      :images,
      :interests,
      :licenses,
      :namings,
      :notifications,
      :observations,
      :projects,
      :species_lists,
      :synonyms,
      :user_groups,
      :users,
      :votes,
      :locations,
      :names
    ]
      add_column table, :sync_id, :string, limit: 16
      User.connection.update("UPDATE #{table} SET sync_id = CONCAT(id,'us1')")
    end

    # These need "modified" columns so we can tell which records are new.
    # (Yes, these are no longer necessary now that we're doing a transaction
    # log, but I think they're still good to have around.)
    add_column :comments,       :modified, :datetime
    add_column :interests,      :modified, :datetime
    add_column :licenses,       :modified, :datetime
    add_column :naming_reasons, :modified, :datetime
    add_column :notifications,  :modified, :datetime
    add_column :users,          :modified, :datetime

    # Rename these columns so that everything is consistent.
    # (Sorry, I'd already done all this, so lets just keep it.)
    add_column :projects,         :created,  :datetime
    add_column :user_groups,      :created,  :datetime
    add_column :draft_names,      :created,  :datetime
    add_column :projects,         :modified, :datetime
    add_column :user_groups,      :modified, :datetime
    add_column :draft_names,      :modified, :datetime
    add_column :past_draft_names, :modified, :datetime
    User.connection.update("UPDATE projects         SET modified = updated_at, created = created_at")
    User.connection.update("UPDATE user_groups      SET modified = updated_at, created = created_at")
    User.connection.update("UPDATE draft_names      SET modified = updated_at, created = created_at")
    User.connection.update("UPDATE past_draft_names SET modified = updated_at")
    remove_column :projects,         :updated_at
    remove_column :user_groups,      :updated_at
    remove_column :draft_names,      :updated_at
    remove_column :past_draft_names, :updated_at
    remove_column :projects,         :created_at
    remove_column :user_groups,      :created_at
    remove_column :draft_names,      :created_at

    #-------------------------------------
    #  Add some stuff to the user table.
    #-------------------------------------

    # Add country preference and admin property to user.
    add_column :users, :admin, :boolean
    add_column :users, :created_here, :boolean
    add_column :users, :alert, :text

    # Provide correct defaults for new admin and created_here columns.
    User.connection.update %(
      UPDATE `users` SET `admin` = TRUE WHERE `login` IN ('nathan', 'jason')
    )
    User.connection.update %(
      UPDATE `users` SET `created_here` = TRUE
    )

    #-----------------------------
    #  Create a transaction log.
    #-----------------------------

    create_table "transactions", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: true do |t|
      t.column "modified", :datetime
      t.column "query",    :text
    end

    #---------------------------------------
    #  Fix flavors in queued_emails table.
    #---------------------------------------

    add_column :queued_emails, :flavor2, :string, limit: 40

    for flavor in %w(
      comment
      consensus_change
      feature
      location_change
      name_change
      name_proposal
      naming
      observation_change
      publish)
      flavor2 = "QueuedEmail::" + flavor.camelize
      User.connection.update %(
        UPDATE `queued_emails` SET `flavor2` = '#{flavor2}'
        WHERE `flavor` = '#{flavor}'
      )
    end

    remove_column :queued_emails, :flavor

    add_column :queued_emails, :flavor, :string, limit: 40
    User.connection.update("UPDATE `queued_emails` SET `flavor` = `flavor2`")
    remove_column :queued_emails, :flavor2

    #-----------------------------------------------
    #  These are not used anywhere (or redundant).
    #-----------------------------------------------

    remove_column :images,     :title
    remove_column :rss_logs,   :synonym_id
    remove_column :namings,    :review_status
    remove_column :names,      :misspelling
    remove_column :past_names, :misspelling

    # Synonyms are never instantiated, thus never modified.
    remove_column :synonyms, :created
    remove_column :synonyms, :modified

    #-----------------------------------------------------
    #  Convert SearchState and SequenceState into Query.
    #-----------------------------------------------------

    create_table "queries", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: true do |t|
      t.column "modified",     :datetime
      t.column "access_count", :integer
      t.column "model",        :enum, limit: Query.all_models
      t.column "flavor",       :enum, limit: Query.all_flavors
      t.column "params",       :text
      t.column "outer_id",     :integer
    end

    drop_table :search_states
    drop_table :sequence_states

    # ----------------------------
    #  Remove naming_reasons.
    # ----------------------------

    add_column :namings, :reasons, :text

    reasons = {}
    for id, num, notes in Name.connection.select_rows %(
      SELECT naming_id, reason, notes FROM naming_reasons
    )
      reasons[id] ||= {}
      reasons[id][num.to_i] = notes
    end

    for id, hash in reasons
      data = YAML.dump(hash).gsub(/[\\"]/) { |x| '\\' + x }
      Name.connection.update %(
        UPDATE namings SET reasons="#{data}" WHERE id = #{id}
      )
    end

    drop_table :naming_reasons

    # ----------------------------
    #  Add "favorite" to votes.
    # ----------------------------

    # Grab max votes for each naming/user pair.
    maxes = {}
    for max, naming_id, user_id in Vote.connection.select_rows %(
      SELECT MAX(votes.value), naming_id, user_id
      FROM votes
      GROUP BY naming_id, user_id
    )
      maxes["#{naming_id} #{user_id}"] = max
    end

    # Grab all data in the existing table.
    data = Vote.connection.select_rows %(
      SELECT created, modified, naming_id, user_id, observation_id, sync_id, value
      FROM votes
    )

    # Calculate favorite flag for each vote.
    for row in data
      created, modified, naming_id, user_id, observation_id, sync_id, value = *row
      max = maxes["#{naming_id} #{user_id}"]
      row << (value.to_f > 0 && value.to_f == max.to_f ? "1" : "0")
    end

    # Clear table, we'll recreate it from scratch later.  I tried to do a fancy
    # update, but my sql-fu was unequal to the task.
    Vote.connection.delete %(
      DELETE FROM votes
    )

    # Add "favorite" column.
    add_column :votes, :favorite, :boolean

    # For some reason we were forcing votes to be integers.
    remove_column :votes, :value
    add_column :votes, :value, :float

    # Now re-populate the table.
    for row in data
      Vote.connection.insert %(
        INSERT INTO votes (created, modified, naming_id, user_id, observation_id, sync_id, value, favorite)
        VALUES (#{row.map { |val| "'#{val}'" }.join(",")})
      )
    end

    # --------------------------------------------------------
    #  Add rss_log_id to observations, names, species_lists.
    #  Also give locations an rss log.
    # --------------------------------------------------------

    add_column :locations,     :rss_log_id,  :integer
    add_column :names,         :rss_log_id,  :integer
    add_column :observations,  :rss_log_id,  :integer
    add_column :species_lists, :rss_log_id,  :integer
    add_column :rss_logs,      :location_id, :integer

    for type in %w(name observation species_list)
      for rss_log_id, id in Name.connection.select_rows %(
        SELECT id, #{type}_id FROM rss_logs WHERE #{type}_id IS NOT NULL
      )
        Name.connection.update %(
          UPDATE #{type}s SET rss_log_id = #{rss_log_id} WHERE id = #{id}
        )
      end
    end
  end

  #=================================================
  #  Migrate down.
  #=================================================

  def self.down
    # Sorry! This and the next migration can't be reversed without great difficulty.
  end
end
