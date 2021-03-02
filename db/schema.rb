# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2021_03_01_122443) do

  create_table "api_keys", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.datetime "created_at"
    t.datetime "last_used"
    t.integer "num_uses", default: 0
    t.integer "user_id", null: false
    t.string "key", limit: 128, null: false
    t.text "notes"
    t.datetime "verified"
  end

  create_table "articles", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
    t.string "title"
    t.text "body"
    t.integer "user_id"
    t.integer "rss_log_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "collection_numbers", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "user_id"
    t.string "name"
    t.string "number"
  end

  create_table "collection_numbers_observations", id: false, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "collection_number_id"
    t.integer "observation_id"
  end

  create_table "comments", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.datetime "created_at"
    t.integer "user_id"
    t.string "summary", limit: 100
    t.text "comment"
    t.string "target_type", limit: 30
    t.integer "target_id"
    t.datetime "updated_at"
  end

  create_table "contest_entries", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "image_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "contest_votes", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "contest_entry_id"
    t.integer "user_id"
    t.integer "vote"
    t.boolean "confirmed"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "copyright_changes", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "user_id", null: false
    t.datetime "updated_at", null: false
    t.string "target_type", limit: 30, null: false
    t.integer "target_id", null: false
    t.integer "year"
    t.string "name"
    t.integer "license_id"
  end

  create_table "donations", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.decimal "amount", precision: 12, scale: 2
    t.string "who", limit: 100
    t.string "email", limit: 100
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean "anonymous", default: false, null: false
    t.boolean "reviewed", default: true, null: false
    t.integer "user_id"
    t.boolean "recurring", default: false
  end

  create_table "external_links", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "user_id"
    t.integer "observation_id"
    t.integer "external_site_id"
    t.string "url", limit: 100
  end

  create_table "external_sites", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "name", limit: 100
    t.integer "project_id"
  end

  create_table "glossary_terms", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "version"
    t.integer "user_id"
    t.string "name", limit: 1024
    t.integer "thumb_image_id"
    t.text "description"
    t.integer "rss_log_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "glossary_terms_images", id: false, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "image_id"
    t.integer "glossary_term_id"
  end

  create_table "glossary_terms_versions", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "glossary_term_id"
    t.integer "version"
    t.integer "user_id"
    t.datetime "updated_at"
    t.string "name", limit: 1024
    t.text "description"
  end

  create_table "herbaria", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.text "mailing_address"
    t.integer "location_id"
    t.string "email", limit: 80, default: "", null: false
    t.string "name", limit: 1024
    t.text "description"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "code", limit: 8, default: "", null: false
    t.integer "personal_user_id"
  end

  create_table "herbaria_curators", id: false, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "user_id", default: 0, null: false
    t.integer "herbarium_id", default: 0, null: false
  end

  create_table "herbarium_records", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "herbarium_id", null: false
    t.text "notes"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "user_id", null: false
    t.string "initial_det", limit: 221, null: false
    t.string "accession_number", limit: 80, null: false
  end

  create_table "herbarium_records_observations", id: false, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "observation_id", default: 0, null: false
    t.integer "herbarium_record_id", default: 0, null: false
  end

  create_table "image_votes", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "value", null: false
    t.boolean "anonymous", default: false, null: false
    t.integer "user_id"
    t.integer "image_id"
    t.index ["image_id"], name: "index_image_votes_on_image_id"
    t.index ["user_id"], name: "index_image_votes_on_user_id"
  end

  create_table "images", id: :integer, unsigned: true, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "content_type", limit: 100
    t.integer "user_id"
    t.date "when"
    t.text "notes"
    t.string "copyright_holder", limit: 100
    t.integer "license_id", default: 1, null: false
    t.integer "num_views", default: 0, null: false
    t.datetime "last_view"
    t.integer "width"
    t.integer "height"
    t.float "vote_cache"
    t.boolean "ok_for_export", default: true, null: false
    t.string "original_name", limit: 120, default: ""
    t.boolean "transferred", default: false, null: false
    t.boolean "gps_stripped", default: false, null: false
  end

  create_table "images_observations", id: false, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "image_id", default: 0, null: false
    t.integer "observation_id", default: 0, null: false
    t.index ["observation_id"], name: "index_images_observations_on_observation_id"
  end

  create_table "images_projects", id: false, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "image_id", null: false
    t.integer "project_id", null: false
  end

  create_table "interests", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "target_type", limit: 30
    t.integer "target_id"
    t.integer "user_id"
    t.boolean "state"
    t.datetime "updated_at"
  end

  create_table "languages", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "locale", limit: 40
    t.string "name", limit: 100
    t.string "order", limit: 100
    t.boolean "official", null: false
    t.boolean "beta", null: false
  end

  create_table "licenses", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "display_name", limit: 80
    t.string "url", limit: 200
    t.boolean "deprecated", default: false, null: false
    t.string "form_name", limit: 20
    t.datetime "updated_at"
  end

  create_table "location_descriptions", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "version"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "user_id"
    t.integer "location_id"
    t.integer "num_views", default: 0
    t.datetime "last_view"
    t.integer "source_type"
    t.string "source_name", limit: 100
    t.string "locale", limit: 8
    t.boolean "public"
    t.integer "license_id"
    t.integer "merge_source_id"
    t.text "gen_desc"
    t.text "ecology"
    t.text "species"
    t.text "notes"
    t.text "refs"
    t.boolean "ok_for_export", default: true, null: false
    t.integer "project_id"
  end

  create_table "location_descriptions_admins", id: false, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "location_description_id", default: 0, null: false
    t.integer "user_group_id", default: 0, null: false
  end

  create_table "location_descriptions_authors", id: false, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "location_description_id", default: 0, null: false
    t.integer "user_id", default: 0, null: false
  end

  create_table "location_descriptions_editors", id: false, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "location_description_id", default: 0, null: false
    t.integer "user_id", default: 0, null: false
  end

  create_table "location_descriptions_readers", id: false, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "location_description_id", default: 0, null: false
    t.integer "user_group_id", default: 0, null: false
  end

  create_table "location_descriptions_versions", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "location_description_id"
    t.integer "version"
    t.datetime "updated_at"
    t.integer "user_id"
    t.integer "license_id"
    t.integer "merge_source_id"
    t.text "gen_desc"
    t.text "ecology"
    t.text "species"
    t.text "notes"
    t.text "refs"
  end

  create_table "location_descriptions_writers", id: false, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "location_description_id", default: 0, null: false
    t.integer "user_group_id", default: 0, null: false
  end

  create_table "locations", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "version"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "user_id"
    t.integer "description_id"
    t.integer "rss_log_id"
    t.integer "num_views", default: 0
    t.datetime "last_view"
    t.float "north"
    t.float "south"
    t.float "west"
    t.float "east"
    t.float "high"
    t.float "low"
    t.boolean "ok_for_export", default: true, null: false
    t.text "notes"
    t.string "name", limit: 1024
    t.string "scientific_name", limit: 1024
    t.boolean "locked", default: false, null: false
  end

  create_table "locations_versions", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "location_id"
    t.integer "version"
    t.datetime "updated_at"
    t.integer "user_id"
    t.float "north"
    t.float "south"
    t.float "west"
    t.float "east"
    t.float "high"
    t.float "low"
    t.string "name", limit: 1024
    t.text "notes"
    t.string "scientific_name", limit: 1024
  end

  create_table "name_descriptions", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "version"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "user_id"
    t.integer "name_id"
    t.integer "review_status", default: 1
    t.datetime "last_review"
    t.integer "reviewer_id"
    t.boolean "ok_for_export", default: true, null: false
    t.integer "num_views", default: 0
    t.datetime "last_view"
    t.integer "source_type"
    t.string "source_name", limit: 100
    t.string "locale", limit: 8
    t.boolean "public"
    t.integer "license_id"
    t.integer "merge_source_id"
    t.text "gen_desc"
    t.text "diag_desc"
    t.text "distribution"
    t.text "habitat"
    t.text "look_alikes"
    t.text "uses"
    t.text "notes"
    t.text "refs"
    t.text "classification"
    t.integer "project_id"
  end

  create_table "name_descriptions_admins", id: false, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "name_description_id", default: 0, null: false
    t.integer "user_group_id", default: 0, null: false
  end

  create_table "name_descriptions_authors", id: false, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "name_description_id", default: 0, null: false
    t.integer "user_id", default: 0, null: false
  end

  create_table "name_descriptions_editors", id: false, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "name_description_id", default: 0, null: false
    t.integer "user_id", default: 0, null: false
  end

  create_table "name_descriptions_readers", id: false, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "name_description_id", default: 0, null: false
    t.integer "user_group_id", default: 0, null: false
  end

  create_table "name_descriptions_versions", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "name_description_id"
    t.integer "version"
    t.datetime "updated_at"
    t.integer "user_id"
    t.integer "license_id"
    t.integer "merge_source_id"
    t.text "gen_desc"
    t.text "diag_desc"
    t.text "distribution"
    t.text "habitat"
    t.text "look_alikes"
    t.text "uses"
    t.text "notes"
    t.text "refs"
    t.text "classification"
  end

  create_table "name_descriptions_writers", id: false, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "name_description_id", default: 0, null: false
    t.integer "user_group_id", default: 0, null: false
  end

  create_table "names", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "version"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "user_id"
    t.integer "description_id"
    t.integer "rss_log_id"
    t.integer "num_views", default: 0
    t.datetime "last_view"
    t.integer "rank"
    t.string "text_name", limit: 100
    t.string "search_name", limit: 221
    t.string "display_name", limit: 204
    t.string "sort_name", limit: 241
    t.text "citation"
    t.boolean "deprecated", default: false, null: false
    t.integer "synonym_id"
    t.integer "correct_spelling_id"
    t.text "notes"
    t.text "classification"
    t.boolean "ok_for_export", default: true, null: false
    t.string "author", limit: 100
    t.string "lifeform", limit: 1024, default: " ", null: false
    t.boolean "locked", default: false, null: false
    t.integer "icn_id"
  end

  create_table "names_versions", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "name_id"
    t.integer "version"
    t.datetime "updated_at"
    t.integer "user_id"
    t.string "text_name", limit: 100
    t.string "search_name", limit: 221
    t.string "display_name", limit: 204
    t.string "sort_name", limit: 241
    t.string "author", limit: 100
    t.text "citation"
    t.boolean "deprecated", default: false, null: false
    t.integer "correct_spelling_id"
    t.text "notes"
    t.integer "rank"
    t.string "lifeform", limit: 1024, default: " ", null: false
    t.integer "icn_id"
  end

  create_table "naming_reasons", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "naming_id"
    t.integer "reason"
    t.text "notes"
  end

  create_table "namings", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "observation_id"
    t.integer "name_id"
    t.integer "user_id"
    t.float "vote_cache", default: 0.0
    t.text "reasons"
  end

  create_table "notifications", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "user_id", default: 0, null: false
    t.integer "flavor"
    t.integer "obj_id"
    t.text "note_template"
    t.datetime "updated_at"
    t.boolean "require_specimen", default: false, null: false
  end

  create_table "observation_views", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "observation_id"
    t.integer "user_id"
    t.datetime "last_view"
  end

  create_table "observations", id: :integer, unsigned: true, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.date "when"
    t.integer "user_id"
    t.boolean "specimen", default: false, null: false
    t.text "notes"
    t.integer "thumb_image_id"
    t.integer "name_id"
    t.integer "location_id"
    t.boolean "is_collection_location", default: true, null: false
    t.float "vote_cache", default: 0.0
    t.integer "num_views", default: 0, null: false
    t.datetime "last_view"
    t.integer "rss_log_id"
    t.decimal "lat", precision: 15, scale: 10
    t.decimal "long", precision: 15, scale: 10
    t.string "where", limit: 1024
    t.integer "alt"
    t.string "lifeform", limit: 1024
    t.string "text_name", limit: 100
    t.text "classification"
    t.boolean "gps_hidden", default: false, null: false
  end

  create_table "observations_projects", id: false, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "observation_id", null: false
    t.integer "project_id", null: false
  end

  create_table "observations_species_lists", id: false, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "observation_id", default: 0, null: false
    t.integer "species_list_id", default: 0, null: false
  end

  create_table "projects", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "user_id", default: 0, null: false
    t.integer "admin_group_id", default: 0, null: false
    t.integer "user_group_id", default: 0, null: false
    t.string "title", limit: 100, default: "", null: false
    t.text "summary"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "rss_log_id"
  end

  create_table "projects_species_lists", id: false, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "project_id", null: false
    t.integer "species_list_id", null: false
  end

  create_table "publications", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "user_id"
    t.text "full"
    t.string "link"
    t.text "how_helped"
    t.boolean "mo_mentioned"
    t.boolean "peer_reviewed"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "query_records", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.datetime "updated_at"
    t.integer "access_count"
    t.text "description"
    t.integer "outer_id"
  end

  create_table "queued_email_integers", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "queued_email_id", default: 0, null: false
    t.string "key", limit: 100
    t.integer "value", default: 0, null: false
  end

  create_table "queued_email_notes", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "queued_email_id", default: 0, null: false
    t.text "value"
  end

  create_table "queued_email_strings", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "queued_email_id", default: 0, null: false
    t.string "key", limit: 100
    t.string "value", limit: 100
  end

  create_table "queued_emails", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "user_id"
    t.datetime "queued"
    t.integer "num_attempts"
    t.string "flavor", limit: 50
    t.integer "to_user_id"
  end

  create_table "rss_logs", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "observation_id"
    t.integer "species_list_id"
    t.datetime "updated_at"
    t.text "notes"
    t.integer "name_id"
    t.integer "location_id"
    t.integer "project_id"
    t.integer "glossary_term_id"
    t.integer "article_id"
  end

  create_table "sequences", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
    t.integer "observation_id"
    t.integer "user_id"
    t.text "locus"
    t.text "bases"
    t.string "archive"
    t.string "accession"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "species_lists", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.date "when"
    t.integer "user_id"
    t.string "where", limit: 1024
    t.string "title", limit: 100
    t.text "notes"
    t.integer "rss_log_id"
    t.integer "location_id"
  end

  create_table "synonyms", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
  end

  create_table "translation_strings", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "version"
    t.integer "language_id", null: false
    t.string "tag", limit: 100
    t.text "text"
    t.datetime "updated_at"
    t.integer "user_id"
  end

  create_table "translation_strings_versions", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "version"
    t.integer "translation_string_id"
    t.text "text"
    t.datetime "updated_at"
    t.integer "user_id"
  end

  create_table "triples", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "subject", limit: 1024
    t.string "predicate", limit: 1024
    t.string "object", limit: 1024
  end

  create_table "user_groups", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "name", default: "", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean "meta", default: false
  end

  create_table "user_groups_users", id: false, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "user_id", default: 0, null: false
    t.integer "user_group_id", default: 0, null: false
  end

  create_table "users", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "login", limit: 80, default: "", null: false
    t.string "password", limit: 40, default: "", null: false
    t.string "email", limit: 80, default: "", null: false
    t.string "theme", limit: 40
    t.string "name", limit: 80
    t.datetime "created_at"
    t.datetime "last_login"
    t.datetime "verified"
    t.integer "license_id", default: 3, null: false
    t.integer "contribution", default: 0
    t.integer "location_id"
    t.integer "image_id"
    t.string "locale", limit: 5
    t.text "bonuses"
    t.boolean "email_comments_owner", default: true, null: false
    t.boolean "email_comments_response", default: true, null: false
    t.boolean "email_comments_all", default: false, null: false
    t.boolean "email_observations_consensus", default: true, null: false
    t.boolean "email_observations_naming", default: true, null: false
    t.boolean "email_observations_all", default: false, null: false
    t.boolean "email_names_author", default: true, null: false
    t.boolean "email_names_editor", default: false, null: false
    t.boolean "email_names_reviewer", default: true, null: false
    t.boolean "email_names_all", default: false, null: false
    t.boolean "email_locations_author", default: true, null: false
    t.boolean "email_locations_editor", default: false, null: false
    t.boolean "email_locations_all", default: false, null: false
    t.boolean "email_general_feature", default: true, null: false
    t.boolean "email_general_commercial", default: true, null: false
    t.boolean "email_general_question", default: true, null: false
    t.boolean "email_html", default: true, null: false
    t.datetime "updated_at"
    t.boolean "admin"
    t.text "alert"
    t.boolean "email_locations_admin", default: false
    t.boolean "email_names_admin", default: false
    t.integer "thumbnail_size", default: 1
    t.integer "image_size", default: 3
    t.string "default_rss_type", limit: 40, default: "all"
    t.integer "votes_anonymous", default: 1
    t.integer "location_format", default: 1
    t.datetime "last_activity"
    t.integer "hide_authors", default: 1, null: false
    t.boolean "thumbnail_maps", default: true, null: false
    t.string "auth_code", limit: 40
    t.integer "keep_filenames", default: 1, null: false
    t.text "notes"
    t.text "mailing_address"
    t.integer "layout_count"
    t.boolean "view_owner_id", default: false, null: false
    t.string "content_filter"
    t.text "notes_template"
  end

  create_table "votes", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "naming_id"
    t.integer "user_id"
    t.integer "observation_id", default: 0
    t.boolean "favorite"
    t.float "value"
  end

end
