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

ActiveRecord::Schema.define(:version => 20140324102552) do

  create_table "api_keys", :force => true do |t|
    t.datetime "created_at"
    t.datetime "last_used"
    t.integer  "num_uses",                  :default => 0
    t.integer  "user_id",                                  :null => false
    t.string   "key",        :limit => 128,                :null => false
    t.text     "notes"
    t.datetime "verified"
  end

  create_table "comments", :force => true do |t|
    t.datetime "created_at"
    t.integer  "user_id"
    t.string   "summary",     :limit => 100
    t.text     "comment"
    t.string   "target_type", :limit => 30
    t.integer  "target_id"
    t.string   "sync_id",     :limit => 16
    t.datetime "updated_at"
  end

  create_table "conference_events", :force => true do |t|
    t.string   "name",              :limit => 1024
    t.string   "location",          :limit => 1024
    t.date     "start"
    t.date     "end"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "description"
    t.text     "registration_note"
  end

  create_table "conference_registrations", :force => true do |t|
    t.integer  "conference_event_id"
    t.string   "name",                :limit => 1024
    t.string   "email",               :limit => 1024
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "how_many"
    t.datetime "verified"
    t.text     "notes"
  end

  create_table "copyright_changes", :force => true do |t|
    t.integer  "user_id",                   :null => false
    t.datetime "updated_at",                :null => false
    t.string   "target_type", :limit => 30, :null => false
    t.integer  "target_id",                 :null => false
    t.integer  "year"
    t.string   "name"
    t.integer  "license_id"
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

  create_table "herbaria", :force => true do |t|
    t.text     "mailing_address"
    t.integer  "location_id"
    t.string   "email",           :limit => 80,   :default => "", :null => false
    t.string   "name",            :limit => 1024
    t.text     "description"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "code",            :limit => 8,    :default => "", :null => false
  end

  create_table "herbaria_curators", :id => false, :force => true do |t|
    t.integer "user_id",      :default => 0, :null => false
    t.integer "herbarium_id", :default => 0, :null => false
  end

  create_table "image_votes", :force => true do |t|
    t.integer "value",                        :null => false
    t.boolean "anonymous", :default => false, :null => false
    t.integer "user_id"
    t.integer "image_id"
  end

  add_index "image_votes", ["user_id"], :name => "index_image_votes_on_user_id"
  add_index "image_votes", ["image_id"], :name => "index_image_votes_on_image_id"

  create_table "images", :force => true do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "content_type",     :limit => 100
    t.integer  "user_id"
    t.date     "when"
    t.text     "notes"
    t.string   "copyright_holder", :limit => 100
    t.integer  "license_id",                      :default => 1,     :null => false
    t.integer  "num_views",                       :default => 0,     :null => false
    t.datetime "last_view"
    t.string   "sync_id",          :limit => 16
    t.integer  "width"
    t.integer  "height"
    t.float    "vote_cache"
    t.boolean  "ok_for_export",                   :default => true,  :null => false
    t.string   "original_name",    :limit => 120, :default => ""
    t.boolean  "transferred",                     :default => false, :null => false
  end

  create_table "images_observations", :id => false, :force => true do |t|
    t.integer "image_id",       :default => 0, :null => false
    t.integer "observation_id", :default => 0, :null => false
  end

  create_table "images_projects", :id => false, :force => true do |t|
    t.integer "image_id",   :null => false
    t.integer "project_id", :null => false
  end

  create_table "images_terms", :id => false, :force => true do |t|
    t.integer "image_id"
    t.integer "term_id"
  end

  create_table "interests", :force => true do |t|
    t.string   "target_type", :limit => 30
    t.integer  "target_id"
    t.integer  "user_id"
    t.boolean  "state"
    t.string   "sync_id",     :limit => 16
    t.datetime "updated_at"
  end

  create_table "languages", :force => true do |t|
    t.string  "locale",   :limit => 40
    t.string  "name",     :limit => 100
    t.string  "order",    :limit => 100
    t.boolean "official",                :null => false
    t.boolean "beta",                    :null => false
  end

  create_table "licenses", :force => true do |t|
    t.string   "display_name", :limit => 80
    t.string   "url",          :limit => 200
    t.boolean  "deprecated",                  :default => false, :null => false
    t.string   "form_name",    :limit => 20
    t.string   "sync_id",      :limit => 16
    t.datetime "updated_at"
  end

  create_table "location_descriptions", :force => true do |t|
    t.string   "sync_id",         :limit => 16
    t.integer  "version"
    t.datetime "created_at"
    t.datetime "updated_at"
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
    t.datetime "updated_at"
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
    t.string   "sync_id",         :limit => 16
    t.integer  "version"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "user_id"
    t.integer  "description_id"
    t.integer  "rss_log_id"
    t.integer  "num_views",                       :default => 0
    t.datetime "last_view"
    t.float    "north"
    t.float    "south"
    t.float    "west"
    t.float    "east"
    t.float    "high"
    t.float    "low"
    t.boolean  "ok_for_export",                   :default => true, :null => false
    t.text     "notes"
    t.string   "name",            :limit => 1024
    t.string   "scientific_name", :limit => 1024
  end

  create_table "locations_versions", :force => true do |t|
    t.string   "location_id"
    t.integer  "version"
    t.datetime "updated_at"
    t.integer  "user_id"
    t.float    "north"
    t.float    "south"
    t.float    "west"
    t.float    "east"
    t.float    "high"
    t.float    "low"
    t.string   "name",            :limit => 200
    t.text     "notes"
    t.string   "scientific_name", :limit => 1024
  end

  create_table "name_descriptions", :force => true do |t|
    t.string   "sync_id",         :limit => 16
    t.integer  "version"
    t.datetime "created_at"
    t.datetime "updated_at"
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
    t.datetime "updated_at"
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
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "user_id"
    t.integer  "description_id"
    t.integer  "rss_log_id"
    t.integer  "num_views",                                                                                                                                                                               :default => 0
    t.datetime "last_view"
    t.enum     "rank",                :limit => [:Form, :Variety, :Subspecies, :Species, :Stirps, :Subsection, :Section, :Subgenus, :Genus, :Family, :Order, :Class, :Phylum, :Kingdom, :Domain, :Group]
    t.string   "text_name",           :limit => 100
    t.string   "search_name",         :limit => 200
    t.string   "display_name",        :limit => 200
    t.string   "sort_name",           :limit => 200
    t.text     "citation"
    t.boolean  "deprecated",                                                                                                                                                                              :default => false, :null => false
    t.integer  "synonym_id"
    t.integer  "correct_spelling_id"
    t.text     "notes"
    t.text     "classification"
    t.boolean  "ok_for_export",                                                                                                                                                                           :default => true,  :null => false
    t.string   "author",              :limit => 100
  end

  create_table "names_versions", :force => true do |t|
    t.integer  "name_id"
    t.integer  "version"
    t.datetime "updated_at"
    t.integer  "user_id"
    t.string   "text_name",           :limit => 100
    t.string   "search_name",         :limit => 200
    t.string   "display_name",        :limit => 200
    t.string   "sort_name",           :limit => 200
    t.string   "author",              :limit => 100
    t.text     "citation"
    t.boolean  "deprecated",                                                                                                                                                                              :default => false, :null => false
    t.integer  "correct_spelling_id"
    t.text     "notes"
    t.enum     "rank",                :limit => [:Form, :Variety, :Subspecies, :Species, :Stirps, :Subsection, :Section, :Subgenus, :Genus, :Family, :Order, :Class, :Phylum, :Kingdom, :Domain, :Group]
  end

  create_table "naming_reasons", :force => true do |t|
    t.integer "naming_id"
    t.integer "reason"
    t.text    "notes"
  end

  create_table "namings", :force => true do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "observation_id"
    t.integer  "name_id"
    t.integer  "user_id"
    t.float    "vote_cache",                   :default => 0.0
    t.string   "sync_id",        :limit => 16
    t.text     "reasons"
  end

  create_table "notifications", :force => true do |t|
    t.integer  "user_id",                                                                 :default => 0,     :null => false
    t.enum     "flavor",           :limit => [:name, :observation, :user, :all_comments]
    t.integer  "obj_id"
    t.text     "note_template"
    t.string   "sync_id",          :limit => 16
    t.datetime "updated_at"
    t.boolean  "require_specimen",                                                        :default => false, :null => false
  end

  create_table "observations", :force => true do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
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
    t.integer  "alt"
  end

  create_table "observations_projects", :id => false, :force => true do |t|
    t.integer "observation_id", :null => false
    t.integer "project_id",     :null => false
  end

  create_table "observations_species_lists", :id => false, :force => true do |t|
    t.integer "observation_id",  :default => 0, :null => false
    t.integer "species_list_id", :default => 0, :null => false
  end

  create_table "observations_specimens", :id => false, :force => true do |t|
    t.integer "observation_id", :default => 0, :null => false
    t.integer "specimen_id",    :default => 0, :null => false
  end

  create_table "projects", :force => true do |t|
    t.integer  "user_id",                       :default => 0,  :null => false
    t.integer  "admin_group_id",                :default => 0,  :null => false
    t.integer  "user_group_id",                 :default => 0,  :null => false
    t.string   "title",          :limit => 100, :default => "", :null => false
    t.text     "summary"
    t.string   "sync_id",        :limit => 16
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "rss_log_id"
  end

  create_table "projects_species_lists", :id => false, :force => true do |t|
    t.integer "project_id",      :null => false
    t.integer "species_list_id", :null => false
  end

  create_table "publications", :force => true do |t|
    t.integer  "user_id"
    t.text     "full"
    t.string   "link"
    t.text     "how_helped"
    t.boolean  "mo_mentioned"
    t.boolean  "peer_reviewed"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "queries", :force => true do |t|
    t.datetime "updated_at"
    t.integer  "access_count"
    t.text     "params"
    t.integer  "outer_id"
    t.enum     "flavor",       :limit => [:advanced_search, :all, :at_location, :at_where, :by_author, :by_editor, :by_rss_log, :by_user, :for_project, :for_target, :for_user, :in_set, :in_species_list, :inside_observation, :of_children, :of_name, :of_parents, :pattern_search, :regexp_search, :with_descriptions, :with_descriptions_by_author, :with_descriptions_by_editor, :with_descriptions_by_user, :with_descriptions_in_set, :with_observations, :with_observations_at_location, :with_observations_at_where, :with_observations_by_user, :with_observations_for_project, :with_observations_in_set, :with_observations_in_species_list, :with_observations_of_children, :with_observations_of_name]
    t.enum     "model",        :limit => [:Comment, :Herbarium, :Image, :Location, :LocationDescription, :Name, :NameDescription, :Observation, :Project, :RssLog, :SpeciesList, :Specimen, :User]
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
    t.datetime "queued"
    t.integer  "num_attempts"
    t.string   "flavor",       :limit => 40
    t.integer  "to_user_id"
  end

  create_table "rss_logs", :force => true do |t|
    t.integer  "observation_id"
    t.integer  "species_list_id"
    t.datetime "updated_at"
    t.text     "notes"
    t.integer  "name_id"
    t.integer  "location_id"
    t.integer  "project_id"
    t.integer  "term_id"
  end

  create_table "species_lists", :force => true do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.date     "when"
    t.integer  "user_id"
    t.string   "where",       :limit => 1024
    t.string   "title",       :limit => 100
    t.text     "notes"
    t.string   "sync_id",     :limit => 16
    t.integer  "rss_log_id"
    t.integer  "location_id"
  end

  create_table "specimens", :force => true do |t|
    t.integer  "herbarium_id",                                  :null => false
    t.date     "when",                                          :null => false
    t.text     "notes"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "user_id",                                       :null => false
    t.string   "herbarium_label", :limit => 80, :default => "", :null => false
  end

  create_table "synonyms", :force => true do |t|
    t.string "sync_id", :limit => 16
  end

  create_table "terms", :force => true do |t|
    t.integer  "version"
    t.integer  "user_id"
    t.string   "name",           :limit => 1024
    t.integer  "thumb_image_id"
    t.text     "description"
    t.integer  "rss_log_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "terms_versions", :force => true do |t|
    t.integer  "term_id"
    t.integer  "version"
    t.integer  "user_id"
    t.datetime "updated_at"
    t.string   "name",        :limit => 1024
    t.text     "description"
  end

  create_table "transactions", :force => true do |t|
    t.datetime "updated_at"
    t.text     "query"
  end

  create_table "translation_strings", :force => true do |t|
    t.integer  "version"
    t.integer  "language_id",                :null => false
    t.string   "tag",         :limit => 100
    t.text     "text"
    t.datetime "updated_at"
    t.integer  "user_id"
  end

  create_table "translation_strings_versions", :force => true do |t|
    t.integer  "version"
    t.integer  "translation_string_id"
    t.text     "text"
    t.datetime "updated_at"
    t.integer  "user_id"
  end

  create_table "triples", :force => true do |t|
    t.string "subject",   :limit => 1024
    t.string "predicate", :limit => 1024
    t.string "object",    :limit => 1024
  end

  create_table "user_groups", :force => true do |t|
    t.string   "name",                     :default => "",    :null => false
    t.string   "sync_id",    :limit => 16
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "meta",                     :default => false
  end

  create_table "user_groups_users", :id => false, :force => true do |t|
    t.integer "user_id",       :default => 0, :null => false
    t.integer "user_group_id", :default => 0, :null => false
  end

  create_table "users", :force => true do |t|
    t.string   "login",                        :limit => 80,                                                       :default => "",             :null => false
    t.string   "password",                     :limit => 40,                                                       :default => "",             :null => false
    t.string   "email",                        :limit => 80,                                                       :default => "",             :null => false
    t.string   "theme",                        :limit => 40
    t.string   "name",                         :limit => 80
    t.datetime "created_at"
    t.datetime "last_login"
    t.datetime "verified"
    t.integer  "rows"
    t.integer  "columns"
    t.boolean  "alternate_rows",                                                                                   :default => true,           :null => false
    t.boolean  "alternate_columns",                                                                                :default => true,           :null => false
    t.boolean  "vertical_layout",                                                                                  :default => true,           :null => false
    t.integer  "license_id",                                                                                       :default => 3,              :null => false
    t.integer  "contribution",                                                                                     :default => 0
    t.integer  "location_id"
    t.integer  "image_id"
    t.string   "locale",                       :limit => 5
    t.text     "bonuses"
    t.boolean  "email_comments_owner",                                                                             :default => true,           :null => false
    t.boolean  "email_comments_response",                                                                          :default => true,           :null => false
    t.boolean  "email_comments_all",                                                                               :default => false,          :null => false
    t.boolean  "email_observations_consensus",                                                                     :default => true,           :null => false
    t.boolean  "email_observations_naming",                                                                        :default => true,           :null => false
    t.boolean  "email_observations_all",                                                                           :default => false,          :null => false
    t.boolean  "email_names_author",                                                                               :default => true,           :null => false
    t.boolean  "email_names_editor",                                                                               :default => false,          :null => false
    t.boolean  "email_names_reviewer",                                                                             :default => true,           :null => false
    t.boolean  "email_names_all",                                                                                  :default => false,          :null => false
    t.boolean  "email_locations_author",                                                                           :default => true,           :null => false
    t.boolean  "email_locations_editor",                                                                           :default => false,          :null => false
    t.boolean  "email_locations_all",                                                                              :default => false,          :null => false
    t.boolean  "email_general_feature",                                                                            :default => true,           :null => false
    t.boolean  "email_general_commercial",                                                                         :default => true,           :null => false
    t.boolean  "email_general_question",                                                                           :default => true,           :null => false
    t.boolean  "email_html",                                                                                       :default => true,           :null => false
    t.string   "sync_id",                      :limit => 16
    t.datetime "updated_at"
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
    t.datetime "last_activity"
    t.enum     "hide_authors",                 :limit => [:none, :above_species],                                  :default => :none,          :null => false
    t.boolean  "thumbnail_maps",                                                                                   :default => true,           :null => false
    t.string   "auth_code",                    :limit => 40
    t.enum     "keep_filenames",               :limit => [:toss, :keep_but_hide, :keep_and_show],                  :default => :keep_and_show, :null => false
    t.text     "notes"
    t.text     "mailing_address"
  end

  create_table "votes", :force => true do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "naming_id"
    t.integer  "user_id"
    t.integer  "observation_id",               :default => 0
    t.string   "sync_id",        :limit => 16
    t.boolean  "favorite"
    t.float    "value"
  end

end
