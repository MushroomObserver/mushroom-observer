# This file is auto-generated from the current state of the database. Instead of editing this file, 
# please use the migrations feature of Active Record to incrementally modify your database, and
# then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your database schema. If you need
# to create the application database on another system, you should be using db:schema:load, not running
# all the migrations from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20110214110100) do

  create_table "authors_descriptions", :id => false, :force => true do |t|
    t.integer "description_id", :default => 0, :null => false
    t.integer "user_id",        :default => 0, :null => false
  end

  create_table "authors_locations", :id => false, :force => true do |t|
    t.integer "location_id", :default => 0, :null => false
    t.integer "user_id",     :default => 0, :null => false
  end

  create_table "authors_names", :id => false, :force => true do |t|
    t.integer "name_id", :default => 0, :null => false
    t.integer "user_id", :default => 0, :null => false
  end

  create_table "comments", :force => true do |t|
    t.datetime "created"
    t.integer  "user_id"
    t.string   "summary",     :limit => 100
    t.text     "comment"
    t.string   "target_type", :limit => 30
    t.integer  "target_id"
    t.string   "sync_id",     :limit => 16
    t.datetime "modified"
  end

  create_table "descriptions", :force => true do |t|
    t.integer  "name_id",                                                               :null => false
    t.integer  "source_id"
    t.integer  "version",                                             :default => 0,    :null => false
    t.string   "locale"
    t.integer  "num_views",                                           :default => 0,    :null => false
    t.datetime "last_view"
    t.integer  "license_id"
    t.enum     "permission",    :limit => [:All, :Editors, :Authors], :default => :All, :null => false
    t.enum     "visibility",    :limit => [:All, :Editors, :Authors], :default => :All, :null => false
    t.boolean  "ok_for_export",                                       :default => true, :null => false
    t.text     "gen_desc"
    t.text     "diag_desc"
    t.text     "distribution"
    t.text     "habitat"
    t.text     "look_alikes"
    t.text     "uses"
    t.text     "refs"
    t.text     "notes"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "donations", :force => true do |t|
    t.decimal  "amount",                    :precision => 12, :scale => 2
    t.string   "who",        :limit => 100
    t.string   "email",      :limit => 100
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "anonymous",                                                :default => false, :null => false
    t.boolean  "reviewed",                                                 :default => true,  :null => false
    t.integer  "user_id"
  end

  create_table "draft_names", :force => true do |t|
    t.integer  "user_id",                                                                  :default => 0,           :null => false
    t.integer  "project_id",                                                               :default => 0,           :null => false
    t.integer  "name_id",                                                                  :default => 0,           :null => false
    t.integer  "version",                                                                  :default => 0,           :null => false
    t.text     "gen_desc"
    t.text     "diag_desc"
    t.text     "distribution"
    t.text     "habitat"
    t.text     "look_alikes"
    t.text     "uses"
    t.text     "notes"
    t.enum     "review_status",  :limit => [:unreviewed, :unvetted, :vetted, :inaccurate], :default => :unreviewed, :null => false
    t.integer  "reviewer_id"
    t.datetime "last_review"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "license_id"
    t.text     "classification"
    t.text     "refs"
  end

  create_table "editors_descriptions", :id => false, :force => true do |t|
    t.integer "description_id", :default => 0, :null => false
    t.integer "user_id",        :default => 0, :null => false
  end

  create_table "editors_locations", :id => false, :force => true do |t|
    t.integer "location_id", :default => 0, :null => false
    t.integer "user_id",     :default => 0, :null => false
  end

  create_table "editors_names", :id => false, :force => true do |t|
    t.integer "name_id", :default => 0, :null => false
    t.integer "user_id", :default => 0, :null => false
  end

  create_table "foo", :force => true do |t|
  end

  create_table "images", :force => true do |t|
    t.datetime "created"
    t.datetime "modified"
    t.string   "content_type",     :limit => 100
    t.integer  "user_id"
    t.date     "when"
    t.text     "notes"
    t.string   "copyright_holder", :limit => 100
    t.integer  "license_id",                      :default => 1,    :null => false
    t.integer  "num_views",                       :default => 0,    :null => false
    t.datetime "last_view"
    t.string   "sync_id",          :limit => 16
    t.integer  "width"
    t.integer  "height"
    t.text     "votes"
    t.float    "vote_cache"
    t.boolean  "ok_for_export",                   :default => true, :null => false
  end

  create_table "images_observations", :id => false, :force => true do |t|
    t.integer "image_id",       :default => 0, :null => false
    t.integer "observation_id", :default => 0, :null => false
  end

  create_table "interests", :force => true do |t|
    t.string   "target_type", :limit => 30
    t.integer  "target_id"
    t.integer  "user_id"
    t.boolean  "state"
    t.string   "sync_id",     :limit => 16
    t.datetime "modified"
  end

  create_table "licenses", :force => true do |t|
    t.string   "display_name", :limit => 80
    t.string   "url",          :limit => 200
    t.boolean  "deprecated",                  :default => false, :null => false
    t.string   "form_name",    :limit => 20
    t.string   "sync_id",      :limit => 16
    t.datetime "modified"
  end

  create_table "location_descriptions", :force => true do |t|
    t.string   "sync_id",         :limit => 16
    t.integer  "version"
    t.datetime "created"
    t.datetime "modified"
    t.integer  "user_id"
    t.integer  "location_id"
    t.integer  "num_views",                                                                :default => 0
    t.datetime "last_view"
    t.enum     "source_type",     :limit => [:public, :foreign, :project, :source, :user]
    t.string   "source_name",     :limit => 100
    t.string   "locale",          :limit => 8
    t.boolean  "public"
    t.integer  "license_id"
    t.integer  "merge_source_id"
    t.text     "gen_desc"
    t.text     "ecology"
    t.text     "species"
    t.text     "notes"
    t.text     "refs"
    t.boolean  "ok_for_export",                                                            :default => true, :null => false
    t.integer  "project_id"
  end

  create_table "location_descriptions_admins", :id => false, :force => true do |t|
    t.integer "location_description_id", :default => 0, :null => false
    t.integer "user_group_id",           :default => 0, :null => false
  end

  create_table "location_descriptions_authors", :id => false, :force => true do |t|
    t.integer "location_description_id", :default => 0, :null => false
    t.integer "user_id",                 :default => 0, :null => false
  end

  create_table "location_descriptions_editors", :id => false, :force => true do |t|
    t.integer "location_description_id", :default => 0, :null => false
    t.integer "user_id",                 :default => 0, :null => false
  end

  create_table "location_descriptions_readers", :id => false, :force => true do |t|
    t.integer "location_description_id", :default => 0, :null => false
    t.integer "user_group_id",           :default => 0, :null => false
  end

  create_table "location_descriptions_versions", :force => true do |t|
    t.integer  "location_description_id"
    t.integer  "version"
    t.datetime "modified"
    t.integer  "user_id"
    t.integer  "license_id"
    t.integer  "merge_source_id"
    t.text     "gen_desc"
    t.text     "ecology"
    t.text     "species"
    t.text     "notes"
    t.text     "refs"
  end

  create_table "location_descriptions_writers", :id => false, :force => true do |t|
    t.integer "location_description_id", :default => 0, :null => false
    t.integer "user_group_id",           :default => 0, :null => false
  end

  create_table "locations", :force => true do |t|
    t.string   "sync_id",        :limit => 16
    t.integer  "version"
    t.datetime "created"
    t.datetime "modified"
    t.integer  "user_id"
    t.integer  "description_id"
    t.integer  "rss_log_id"
    t.integer  "num_views",                      :default => 0
    t.datetime "last_view"
    t.float    "north"
    t.float    "south"
    t.float    "west"
    t.float    "east"
    t.float    "high"
    t.float    "low"
    t.boolean  "ok_for_export",                  :default => true, :null => false
    t.text     "notes"
    t.string   "name",           :limit => 1024
  end

  create_table "locations_versions", :force => true do |t|
    t.string   "location_id"
    t.integer  "version"
    t.datetime "modified"
    t.integer  "user_id"
    t.float    "north"
    t.float    "south"
    t.float    "west"
    t.float    "east"
    t.float    "high"
    t.float    "low"
    t.string   "name",        :limit => 200
    t.text     "notes"
  end

  create_table "name_descriptions", :force => true do |t|
    t.string   "sync_id",         :limit => 16
    t.integer  "version"
    t.datetime "created"
    t.datetime "modified"
    t.integer  "user_id"
    t.integer  "name_id"
    t.enum     "review_status",   :limit => [:unreviewed, :unvetted, :vetted, :inaccurate], :default => :unreviewed
    t.datetime "last_review"
    t.integer  "reviewer_id"
    t.boolean  "ok_for_export",                                                             :default => true,        :null => false
    t.integer  "num_views",                                                                 :default => 0
    t.datetime "last_view"
    t.enum     "source_type",     :limit => [:public, :foreign, :project, :source, :user]
    t.string   "source_name",     :limit => 100
    t.string   "locale",          :limit => 8
    t.boolean  "public"
    t.integer  "license_id"
    t.integer  "merge_source_id"
    t.text     "gen_desc"
    t.text     "diag_desc"
    t.text     "distribution"
    t.text     "habitat"
    t.text     "look_alikes"
    t.text     "uses"
    t.text     "notes"
    t.text     "refs"
    t.text     "classification"
    t.integer  "project_id"
  end

  create_table "name_descriptions_admins", :id => false, :force => true do |t|
    t.integer "name_description_id", :default => 0, :null => false
    t.integer "user_group_id",       :default => 0, :null => false
  end

  create_table "name_descriptions_authors", :id => false, :force => true do |t|
    t.integer "name_description_id", :default => 0, :null => false
    t.integer "user_id",             :default => 0, :null => false
  end

  create_table "name_descriptions_editors", :id => false, :force => true do |t|
    t.integer "name_description_id", :default => 0, :null => false
    t.integer "user_id",             :default => 0, :null => false
  end

  create_table "name_descriptions_readers", :id => false, :force => true do |t|
    t.integer "name_description_id", :default => 0, :null => false
    t.integer "user_group_id",       :default => 0, :null => false
  end

  create_table "name_descriptions_versions", :force => true do |t|
    t.integer  "name_description_id"
    t.integer  "version"
    t.datetime "modified"
    t.integer  "user_id"
    t.integer  "license_id"
    t.integer  "merge_source_id"
    t.text     "gen_desc"
    t.text     "diag_desc"
    t.text     "distribution"
    t.text     "habitat"
    t.text     "look_alikes"
    t.text     "uses"
    t.text     "notes"
    t.text     "refs"
    t.text     "classification"
  end

  create_table "name_descriptions_writers", :id => false, :force => true do |t|
    t.integer "name_description_id", :default => 0, :null => false
    t.integer "user_group_id",       :default => 0, :null => false
  end

  create_table "names", :force => true do |t|
    t.string   "sync_id",             :limit => 16
    t.integer  "version"
    t.datetime "created"
    t.datetime "modified"
    t.integer  "user_id"
    t.integer  "description_id"
    t.integer  "rss_log_id"
    t.integer  "num_views",                                                                                                                                    :default => 0
    t.datetime "last_view"
    t.enum     "rank",                :limit => [:Form, :Variety, :Subspecies, :Species, :Genus, :Family, :Order, :Class, :Phylum, :Kingdom, :Domain, :Group]
    t.string   "text_name",           :limit => 100
    t.string   "search_name",         :limit => 200
    t.string   "display_name",        :limit => 200
    t.string   "observation_name",    :limit => 200
    t.string   "author",              :limit => 100
    t.text     "citation"
    t.boolean  "deprecated",                                                                                                                                   :default => false, :null => false
    t.integer  "synonym_id"
    t.integer  "correct_spelling_id"
    t.text     "notes"
    t.text     "classification"
    t.boolean  "ok_for_export",                                                                                                                                :default => true,  :null => false
  end

  create_table "names_versions", :force => true do |t|
    t.integer  "name_id"
    t.integer  "version"
    t.datetime "modified"
    t.integer  "user_id"
    t.enum     "rank",                :limit => [:Form, :Variety, :Subspecies, :Species, :Genus, :Family, :Order, :Class, :Phylum, :Kingdom, :Domain, :Group]
    t.string   "text_name",           :limit => 100
    t.string   "search_name",         :limit => 200
    t.string   "display_name",        :limit => 200
    t.string   "observation_name",    :limit => 200
    t.string   "author",              :limit => 100
    t.text     "citation"
    t.boolean  "deprecated",                                                                                                                                   :default => false, :null => false
    t.integer  "correct_spelling_id"
    t.text     "notes"
  end

  create_table "naming_reasons", :force => true do |t|
    t.integer "naming_id"
    t.integer "reason"
    t.text    "notes"
  end

  create_table "namings", :force => true do |t|
    t.datetime "created"
    t.datetime "modified"
    t.integer  "observation_id"
    t.integer  "name_id"
    t.integer  "user_id"
    t.float    "vote_cache",                   :default => 0.0
    t.string   "sync_id",        :limit => 16
    t.text     "reasons"
  end

  create_table "notifications", :force => true do |t|
    t.integer  "user_id",                                                              :default => 0, :null => false
    t.enum     "flavor",        :limit => [:name, :observation, :user, :all_comments]
    t.integer  "obj_id"
    t.text     "note_template"
    t.string   "sync_id",       :limit => 16
    t.datetime "modified"
  end

  create_table "observations", :force => true do |t|
    t.datetime "created"
    t.datetime "modified"
    t.date     "when"
    t.integer  "user_id"
    t.boolean  "specimen",                                                               :default => false, :null => false
    t.text     "notes"
    t.integer  "thumb_image_id"
    t.integer  "name_id"
    t.integer  "location_id"
    t.boolean  "is_collection_location",                                                 :default => true,  :null => false
    t.float    "vote_cache",                                                             :default => 0.0
    t.integer  "num_views",                                                              :default => 0,     :null => false
    t.datetime "last_view"
    t.string   "sync_id",                :limit => 16
    t.integer  "rss_log_id"
    t.decimal  "lat",                                    :precision => 15, :scale => 10
    t.decimal  "long",                                   :precision => 15, :scale => 10
    t.string   "where",                  :limit => 1024
  end

  create_table "observations_species_lists", :id => false, :force => true do |t|
    t.integer "observation_id",  :default => 0, :null => false
    t.integer "species_list_id", :default => 0, :null => false
  end

  create_table "past_descriptions", :force => true do |t|
    t.integer  "description_id"
    t.integer  "name_id",                                                                :null => false
    t.integer  "source_id"
    t.integer  "version",                                              :default => 0,    :null => false
    t.string   "locale"
    t.integer  "num_views",                                            :default => 0,    :null => false
    t.datetime "last_view"
    t.integer  "license_id"
    t.enum     "permission",     :limit => [:All, :Editors, :Authors], :default => :All, :null => false
    t.enum     "visibility",     :limit => [:All, :Editors, :Authors], :default => :All, :null => false
    t.boolean  "ok_for_export",                                        :default => true, :null => false
    t.text     "gen_desc"
    t.text     "diag_desc"
    t.text     "distribution"
    t.text     "habitat"
    t.text     "look_alikes"
    t.text     "uses"
    t.text     "refs"
    t.text     "notes"
    t.datetime "updated_at"
  end

  create_table "past_draft_names", :force => true do |t|
    t.integer  "draft_name_id",                                                            :default => 0,           :null => false
    t.integer  "user_id",                                                                  :default => 0,           :null => false
    t.integer  "project_id",                                                               :default => 0,           :null => false
    t.integer  "name_id",                                                                  :default => 0,           :null => false
    t.integer  "version",                                                                  :default => 0,           :null => false
    t.text     "gen_desc"
    t.text     "diag_desc"
    t.text     "distribution"
    t.text     "habitat"
    t.text     "look_alikes"
    t.text     "uses"
    t.text     "notes"
    t.enum     "review_status",  :limit => [:unreviewed, :unvetted, :vetted, :inaccurate], :default => :unreviewed, :null => false
    t.integer  "reviewer_id"
    t.datetime "last_review"
    t.datetime "updated_at"
    t.integer  "license_id"
    t.text     "classification"
    t.text     "refs"
  end

  create_table "past_locations", :force => true do |t|
    t.integer  "location_id"
    t.datetime "modified"
    t.integer  "user_id",                     :default => 0, :null => false
    t.integer  "version",                     :default => 0, :null => false
    t.string   "display_name", :limit => 200
    t.text     "notes"
    t.float    "north"
    t.float    "south"
    t.float    "west"
    t.float    "east"
    t.float    "high"
    t.float    "low"
    t.integer  "license_id"
  end

  create_table "past_names", :force => true do |t|
    t.integer  "name_id"
    t.datetime "modified"
    t.integer  "user_id",                                                                                                                             :default => 0,     :null => false
    t.integer  "version",                                                                                                                             :default => 0,     :null => false
    t.string   "text_name",           :limit => 100
    t.string   "author",              :limit => 100
    t.string   "display_name",        :limit => 200
    t.string   "observation_name",    :limit => 200
    t.string   "search_name",         :limit => 200
    t.text     "notes"
    t.boolean  "deprecated",                                                                                                                          :default => false, :null => false
    t.enum     "rank",                :limit => [:Form, :Variety, :Subspecies, :Species, :Genus, :Family, :Order, :Class, :Phylum, :Kingdom, :Group]
    t.text     "gen_desc"
    t.text     "diag_desc"
    t.text     "distribution"
    t.text     "habitat"
    t.text     "look_alikes"
    t.text     "uses"
    t.integer  "reviewer_id"
    t.datetime "last_review"
    t.enum     "review_status",       :limit => [:unreviewed, :unvetted, :vetted, :inaccurate]
    t.integer  "license_id"
    t.boolean  "ok_for_export",                                                                                                                       :default => true,  :null => false
    t.text     "classification"
    t.text     "citation"
    t.boolean  "misspelling",                                                                                                                         :default => false, :null => false
    t.integer  "correct_spelling_id"
    t.text     "refs"
  end

  create_table "projects", :force => true do |t|
    t.integer  "user_id",                       :default => 0,  :null => false
    t.integer  "admin_group_id",                :default => 0,  :null => false
    t.integer  "user_group_id",                 :default => 0,  :null => false
    t.string   "title",          :limit => 100, :default => "", :null => false
    t.text     "summary"
    t.string   "sync_id",        :limit => 16
    t.datetime "created"
    t.datetime "modified"
    t.integer  "rss_log_id"
  end

  create_table "queries", :force => true do |t|
    t.datetime "modified"
    t.integer  "access_count"
    t.enum     "model",        :limit => [:Comment, :Image, :Location, :LocationDescription, :Name, :NameDescription, :Observation, :Project, :RssLog, :SpeciesList, :User]
    t.enum     "flavor",       :limit => [:advanced_search, :all, :at_location, :at_where, :by_author, :by_editor, :by_rss_log, :by_user, :for_user, :in_set, :in_species_list, :inside_observation, :of_children, :of_name, :of_parents, :pattern_search, :with_descriptions, :with_descriptions_by_author, :with_descriptions_by_editor, :with_descriptions_by_user, :with_descriptions_in_set, :with_observations, :with_observations_at_location, :with_observations_at_where, :with_observations_by_user, :with_observations_in_set, :with_observations_in_species_list, :with_observations_of_children, :with_observations_of_name]
    t.text     "params"
    t.integer  "outer_id"
  end

  create_table "queued_email_integers", :force => true do |t|
    t.integer "queued_email_id",                :default => 0, :null => false
    t.string  "key",             :limit => 100
    t.integer "value",                          :default => 0, :null => false
  end

  create_table "queued_email_notes", :force => true do |t|
    t.integer "queued_email_id", :default => 0, :null => false
    t.text    "value"
  end

  create_table "queued_email_strings", :force => true do |t|
    t.integer "queued_email_id",                :default => 0, :null => false
    t.string  "key",             :limit => 100
    t.string  "value",           :limit => 100
  end

  create_table "queued_emails", :force => true do |t|
    t.integer  "user_id"
    t.integer  "to_user_id",                 :default => 0, :null => false
    t.datetime "queued"
    t.integer  "num_attempts"
    t.string   "flavor",       :limit => 40
  end

  create_table "rss_logs", :force => true do |t|
    t.integer  "observation_id"
    t.integer  "species_list_id"
    t.datetime "modified"
    t.text     "notes"
    t.integer  "name_id"
    t.integer  "location_id"
    t.integer  "project_id"
  end

  create_table "search_states", :force => true do |t|
    t.datetime "timestamp"
    t.integer  "access_count"
    t.string   "title",        :limit => 100
    t.text     "conditions"
    t.text     "order"
    t.string   "source",       :limit => 20
    t.enum     "query_type",   :limit => [:species_list_observations, :name_observations, :synonym_observations, :other_observations, :observations, :images, :rss_logs, :advanced_observations, :advanced_images, :advanced_names]
  end

  create_table "sequence_states", :force => true do |t|
    t.datetime "timestamp"
    t.integer  "access_count"
    t.text     "query"
    t.integer  "current_id"
    t.integer  "current_index"
    t.integer  "prev_id"
    t.integer  "next_id"
    t.enum     "query_type",    :limit => [:species_list_observations, :name_observations, :synonym_observations, :other_observations, :observations, :images, :rss_logs]
  end

  create_table "species_lists", :force => true do |t|
    t.datetime "created"
    t.datetime "modified"
    t.date     "when"
    t.integer  "user_id"
    t.string   "where",       :limit => 100
    t.string   "title",       :limit => 100
    t.text     "notes"
    t.string   "sync_id",     :limit => 16
    t.integer  "rss_log_id"
    t.integer  "location_id"
  end

  create_table "synonyms", :force => true do |t|
    t.string "sync_id", :limit => 16
  end

  create_table "transactions", :force => true do |t|
    t.datetime "modified"
    t.text     "query"
  end

  create_table "user_groups", :force => true do |t|
    t.string   "name",                   :default => "",    :null => false
    t.string   "sync_id",  :limit => 16
    t.datetime "created"
    t.datetime "modified"
    t.boolean  "meta",                   :default => false
  end

  create_table "user_groups_users", :id => false, :force => true do |t|
    t.integer "user_id",       :default => 0, :null => false
    t.integer "user_group_id", :default => 0, :null => false
  end

  create_table "users", :force => true do |t|
    t.string   "login",                        :limit => 80,                                                       :default => "",         :null => false
    t.string   "password",                     :limit => 40,                                                       :default => "",         :null => false
    t.string   "email",                        :limit => 80,                                                       :default => "",         :null => false
    t.string   "theme",                        :limit => 40
    t.string   "name",                         :limit => 80
    t.datetime "created"
    t.datetime "last_login"
    t.datetime "verified"
    t.integer  "rows"
    t.integer  "columns"
    t.boolean  "alternate_rows",                                                                                   :default => true,       :null => false
    t.boolean  "alternate_columns",                                                                                :default => true,       :null => false
    t.boolean  "vertical_layout",                                                                                  :default => true,       :null => false
    t.integer  "license_id",                                                                                       :default => 3,          :null => false
    t.integer  "contribution",                                                                                     :default => 0
    t.text     "notes",                                                                                            :default => "",         :null => false
    t.integer  "location_id"
    t.integer  "image_id"
    t.text     "mailing_address",                                                                                  :default => "",         :null => false
    t.string   "locale",                       :limit => 5
    t.text     "bonuses"
    t.boolean  "email_comments_owner",                                                                             :default => true,       :null => false
    t.boolean  "email_comments_response",                                                                          :default => true,       :null => false
    t.boolean  "email_comments_all",                                                                               :default => false,      :null => false
    t.boolean  "email_observations_consensus",                                                                     :default => true,       :null => false
    t.boolean  "email_observations_naming",                                                                        :default => true,       :null => false
    t.boolean  "email_observations_all",                                                                           :default => false,      :null => false
    t.boolean  "email_names_author",                                                                               :default => true,       :null => false
    t.boolean  "email_names_editor",                                                                               :default => false,      :null => false
    t.boolean  "email_names_reviewer",                                                                             :default => true,       :null => false
    t.boolean  "email_names_all",                                                                                  :default => false,      :null => false
    t.boolean  "email_locations_author",                                                                           :default => true,       :null => false
    t.boolean  "email_locations_editor",                                                                           :default => false,      :null => false
    t.boolean  "email_locations_all",                                                                              :default => false,      :null => false
    t.boolean  "email_general_feature",                                                                            :default => true,       :null => false
    t.boolean  "email_general_commercial",                                                                         :default => true,       :null => false
    t.boolean  "email_general_question",                                                                           :default => true,       :null => false
    t.boolean  "email_html",                                                                                       :default => true,       :null => false
    t.string   "sync_id",                      :limit => 16
    t.datetime "modified"
    t.boolean  "admin"
    t.boolean  "created_here"
    t.text     "alert"
    t.boolean  "email_locations_admin",                                                                            :default => false
    t.boolean  "email_names_admin",                                                                                :default => false
    t.enum     "thumbnail_size",               :limit => [:thumbnail, :small],                                     :default => :thumbnail
    t.enum     "image_size",                   :limit => [:thumbnail, :small, :medium, :large, :huge, :full_size], :default => :medium
    t.string   "default_rss_type",             :limit => 40,                                                       :default => "all"
    t.enum     "votes_anonymous",              :limit => [:no, :yes, :old],                                        :default => :no
    t.enum     "location_format",              :limit => [:postal, :scientific],                                   :default => :postal
  end

  create_table "votes", :force => true do |t|
    t.datetime "created"
    t.datetime "modified"
    t.integer  "naming_id"
    t.integer  "user_id"
    t.integer  "observation_id",               :default => 0
    t.string   "sync_id",        :limit => 16
    t.boolean  "favorite"
    t.float    "value"
  end

end
