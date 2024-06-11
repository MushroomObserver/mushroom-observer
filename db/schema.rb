# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2024_06_08_213317) do
  create_table "api_keys", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.datetime "last_used", precision: nil
    t.integer "num_uses", default: 0
    t.integer "user_id", null: false
    t.string "key", limit: 128, null: false
    t.text "notes"
    t.datetime "verified", precision: nil
  end

  create_table "articles", id: :integer, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "title"
    t.text "body", size: :medium
    t.integer "user_id"
    t.integer "rss_log_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "collection_numbers", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.integer "user_id"
    t.string "name"
    t.string "number"
  end

  create_table "comments", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.integer "user_id"
    t.string "summary", limit: 100
    t.text "comment"
    t.string "target_type", limit: 30
    t.integer "target_id"
    t.datetime "updated_at", precision: nil
    t.index ["target_id", "target_type"], name: "target_index"
  end

  create_table "copyright_changes", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.integer "user_id", null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "target_type", limit: 30, null: false
    t.integer "target_id", null: false
    t.integer "year"
    t.string "name"
    t.integer "license_id"
  end

  create_table "donations", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.decimal "amount", precision: 12, scale: 2
    t.string "who", limit: 100
    t.string "email", limit: 100
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.boolean "anonymous", default: false, null: false
    t.boolean "reviewed", default: true, null: false
    t.integer "user_id"
    t.boolean "recurring", default: false
  end

  create_table "external_links", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.integer "user_id"
    t.integer "observation_id"
    t.integer "external_site_id"
    t.string "url", limit: 100
  end

  create_table "external_sites", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.string "name", limit: 100
    t.integer "project_id"
  end

  create_table "field_slip_job_trackers", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "start"
    t.integer "count"
    t.string "prefix"
    t.integer "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "pages", default: 0, null: false
    t.string "title", limit: 100, default: "", null: false
    t.integer "user_id"
    t.boolean "one_per_page", default: false, null: false
  end

  create_table "field_slips", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "observation_id"
    t.integer "project_id"
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["code"], name: "index_field_slips_on_code", unique: true
  end

  create_table "glossary_term_images", charset: "utf8mb3", force: :cascade do |t|
    t.integer "image_id"
    t.integer "glossary_term_id"
  end

  create_table "glossary_term_versions", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.integer "glossary_term_id"
    t.integer "version"
    t.integer "user_id"
    t.datetime "updated_at", precision: nil
    t.string "name", limit: 1024
    t.text "description"
  end

  create_table "glossary_terms", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.integer "version"
    t.integer "user_id"
    t.string "name", limit: 1024
    t.integer "thumb_image_id"
    t.text "description"
    t.integer "rss_log_id"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.boolean "locked", default: false, null: false
  end

  create_table "herbaria", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.text "mailing_address"
    t.integer "location_id"
    t.string "email", limit: 80, default: "", null: false
    t.string "name", limit: 1024
    t.text "description"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.string "code", limit: 8, default: "", null: false
    t.integer "personal_user_id"
  end

  create_table "herbarium_curators", charset: "utf8mb3", force: :cascade do |t|
    t.integer "user_id", default: 0, null: false
    t.integer "herbarium_id", default: 0, null: false
  end

  create_table "herbarium_records", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.integer "herbarium_id", null: false
    t.text "notes"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.integer "user_id", null: false
    t.string "initial_det", limit: 221, null: false
    t.string "accession_number", limit: 80, null: false
  end

  create_table "image_votes", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.integer "value", null: false
    t.boolean "anonymous", default: false, null: false
    t.integer "user_id"
    t.integer "image_id"
    t.index ["image_id"], name: "index_image_votes_on_image_id"
    t.index ["user_id"], name: "index_image_votes_on_user_id"
  end

  create_table "images", id: { type: :integer, unsigned: true }, charset: "utf8mb3", force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.string "content_type", limit: 100
    t.integer "user_id"
    t.date "when"
    t.text "notes"
    t.string "copyright_holder", limit: 100
    t.integer "license_id", default: 10, null: false
    t.integer "num_views", default: 0, null: false
    t.datetime "last_view", precision: nil
    t.integer "width"
    t.integer "height"
    t.float "vote_cache"
    t.boolean "ok_for_export", default: true, null: false
    t.string "original_name", limit: 120, default: ""
    t.boolean "transferred", default: false, null: false
    t.boolean "gps_stripped", default: false, null: false
    t.boolean "diagnostic", default: true, null: false
  end

  create_table "interests", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.string "target_type", limit: 30
    t.integer "target_id"
    t.integer "user_id"
    t.boolean "state"
    t.datetime "updated_at", precision: nil
  end

  create_table "languages", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.string "locale", limit: 40
    t.string "name", limit: 100
    t.string "order", limit: 100
    t.boolean "official", null: false
    t.boolean "beta", null: false
  end

  create_table "licenses", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.string "display_name", limit: 80
    t.string "url", limit: 200
    t.boolean "deprecated", default: false, null: false
    t.datetime "updated_at", precision: nil
    t.datetime "created_at", precision: nil
  end

  create_table "location_description_admins", charset: "utf8mb3", force: :cascade do |t|
    t.integer "location_description_id", default: 0, null: false
    t.integer "user_group_id", default: 0, null: false
  end

  create_table "location_description_authors", charset: "utf8mb3", force: :cascade do |t|
    t.integer "location_description_id", default: 0, null: false
    t.integer "user_id", default: 0, null: false
  end

  create_table "location_description_editors", charset: "utf8mb3", force: :cascade do |t|
    t.integer "location_description_id", default: 0, null: false
    t.integer "user_id", default: 0, null: false
  end

  create_table "location_description_readers", charset: "utf8mb3", force: :cascade do |t|
    t.integer "location_description_id", default: 0, null: false
    t.integer "user_group_id", default: 0, null: false
  end

  create_table "location_description_versions", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.integer "location_description_id"
    t.integer "version"
    t.datetime "updated_at", precision: nil
    t.integer "user_id"
    t.integer "license_id"
    t.integer "merge_source_id"
    t.text "gen_desc"
    t.text "ecology"
    t.text "species"
    t.text "notes"
    t.text "refs"
  end

  create_table "location_description_writers", charset: "utf8mb3", force: :cascade do |t|
    t.integer "location_description_id", default: 0, null: false
    t.integer "user_group_id", default: 0, null: false
  end

  create_table "location_descriptions", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.integer "version"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.integer "user_id"
    t.integer "location_id"
    t.integer "num_views", default: 0
    t.datetime "last_view", precision: nil
    t.integer "source_type"
    t.string "source_name", limit: 100
    t.string "locale", limit: 8
    t.boolean "public"
    t.integer "license_id"
    t.text "gen_desc"
    t.text "ecology"
    t.text "species"
    t.text "notes"
    t.text "refs"
    t.boolean "ok_for_export", default: true, null: false
    t.integer "project_id"
  end

  create_table "location_versions", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.string "location_id"
    t.integer "version"
    t.datetime "updated_at", precision: nil
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

  create_table "locations", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.integer "version"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.integer "user_id"
    t.integer "description_id"
    t.integer "rss_log_id"
    t.integer "num_views", default: 0
    t.datetime "last_view", precision: nil
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
    t.boolean "hidden", default: false, null: false
  end

  create_table "name_description_admins", charset: "utf8mb3", force: :cascade do |t|
    t.integer "name_description_id", default: 0, null: false
    t.integer "user_group_id", default: 0, null: false
  end

  create_table "name_description_authors", charset: "utf8mb3", force: :cascade do |t|
    t.integer "name_description_id", default: 0, null: false
    t.integer "user_id", default: 0, null: false
  end

  create_table "name_description_editors", charset: "utf8mb3", force: :cascade do |t|
    t.integer "name_description_id", default: 0, null: false
    t.integer "user_id", default: 0, null: false
  end

  create_table "name_description_readers", charset: "utf8mb3", force: :cascade do |t|
    t.integer "name_description_id", default: 0, null: false
    t.integer "user_group_id", default: 0, null: false
  end

  create_table "name_description_versions", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.integer "name_description_id"
    t.integer "version"
    t.datetime "updated_at", precision: nil
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

  create_table "name_description_writers", charset: "utf8mb3", force: :cascade do |t|
    t.integer "name_description_id", default: 0, null: false
    t.integer "user_group_id", default: 0, null: false
  end

  create_table "name_descriptions", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.integer "version"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.integer "user_id"
    t.integer "name_id"
    t.integer "review_status", default: 1
    t.datetime "last_review", precision: nil
    t.integer "reviewer_id"
    t.boolean "ok_for_export", default: true, null: false
    t.integer "num_views", default: 0
    t.datetime "last_view", precision: nil
    t.integer "source_type"
    t.string "source_name", limit: 100
    t.string "locale", limit: 8
    t.boolean "public"
    t.integer "license_id"
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

  create_table "name_trackers", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.integer "user_id", default: 0, null: false
    t.integer "name_id"
    t.text "note_template"
    t.datetime "updated_at", precision: nil
    t.boolean "require_specimen", default: false, null: false
    t.boolean "approved", default: true, null: false
  end

  create_table "name_versions", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.integer "name_id"
    t.integer "version"
    t.datetime "updated_at", precision: nil
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

  create_table "names", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.integer "version"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.integer "user_id"
    t.integer "description_id"
    t.integer "rss_log_id"
    t.integer "num_views", default: 0
    t.datetime "last_view", precision: nil
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
    t.index ["synonym_id"], name: "synonym_index"
  end

  create_table "naming_reasons", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.integer "naming_id"
    t.integer "reason"
    t.text "notes"
  end

  create_table "namings", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.integer "observation_id"
    t.integer "name_id"
    t.integer "user_id"
    t.float "vote_cache", default: 0.0
    t.text "reasons"
    t.index ["observation_id"], name: "index_namings_on_observation_id"
  end

  create_table "observation_collection_numbers", charset: "utf8mb3", force: :cascade do |t|
    t.integer "collection_number_id"
    t.integer "observation_id"
  end

  create_table "observation_herbarium_records", charset: "utf8mb3", force: :cascade do |t|
    t.integer "observation_id", default: 0, null: false
    t.integer "herbarium_record_id", default: 0, null: false
  end

  create_table "observation_images", charset: "utf8mb3", force: :cascade do |t|
    t.integer "image_id", default: 0, null: false
    t.integer "observation_id", default: 0, null: false
    t.integer "rank", default: 0, null: false
    t.index ["observation_id"], name: "index_observation_images_on_observation_id"
  end

  create_table "observation_views", charset: "utf8mb3", force: :cascade do |t|
    t.integer "observation_id"
    t.integer "user_id"
    t.datetime "last_view", precision: nil
    t.boolean "reviewed"
    t.index ["observation_id"], name: "observation_index"
    t.index ["user_id"], name: "user_index"
  end

  create_table "observations", id: { type: :integer, unsigned: true }, charset: "utf8mb3", force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
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
    t.datetime "last_view", precision: nil
    t.integer "rss_log_id"
    t.decimal "lat", precision: 15, scale: 10
    t.decimal "lng", precision: 15, scale: 10
    t.string "where", limit: 1024
    t.integer "alt"
    t.string "lifeform", limit: 1024
    t.string "text_name", limit: 100
    t.text "classification"
    t.boolean "gps_hidden", default: false, null: false
    t.integer "source"
    t.datetime "log_updated_at", precision: nil
    t.boolean "needs_naming", default: false, null: false
    t.integer "inat_id"
    t.index ["needs_naming"], name: "needs_naming_index"
  end

  create_table "project_images", charset: "utf8mb3", force: :cascade do |t|
    t.integer "image_id", null: false
    t.integer "project_id", null: false
  end

  create_table "project_members", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "project_id"
    t.integer "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "trust_level", default: 1, null: false
  end

  create_table "project_observations", charset: "utf8mb3", force: :cascade do |t|
    t.integer "observation_id", null: false
    t.integer "project_id", null: false
  end

  create_table "project_species_lists", charset: "utf8mb3", force: :cascade do |t|
    t.integer "project_id", null: false
    t.integer "species_list_id", null: false
  end

  create_table "projects", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.integer "user_id", default: 0, null: false
    t.integer "admin_group_id", default: 0, null: false
    t.integer "user_group_id", default: 0, null: false
    t.string "title", limit: 100, default: "", null: false
    t.text "summary"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.integer "rss_log_id"
    t.boolean "open_membership", default: false, null: false
    t.integer "location_id"
    t.integer "image_id"
    t.date "start_date"
    t.date "end_date"
    t.string "field_slip_prefix"
    t.integer "next_field_slip", default: 0, null: false
    t.index ["field_slip_prefix"], name: "index_projects_on_field_slip_prefix", unique: true
  end

  create_table "publications", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.integer "user_id"
    t.text "full"
    t.string "link"
    t.text "how_helped"
    t.boolean "mo_mentioned"
    t.boolean "peer_reviewed"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
  end

  create_table "query_records", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.datetime "updated_at", precision: nil
    t.integer "access_count"
    t.text "description"
    t.integer "outer_id"
  end

  create_table "queued_email_integers", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.integer "queued_email_id", default: 0, null: false
    t.string "key", limit: 100
    t.integer "value", default: 0, null: false
  end

  create_table "queued_email_notes", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.integer "queued_email_id", default: 0, null: false
    t.text "value"
  end

  create_table "queued_email_strings", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.integer "queued_email_id", default: 0, null: false
    t.string "key", limit: 100
    t.string "value", limit: 100
  end

  create_table "queued_emails", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.integer "user_id"
    t.datetime "queued", precision: nil
    t.integer "num_attempts"
    t.string "flavor", limit: 50
    t.integer "to_user_id"
  end

  create_table "rss_logs", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.integer "observation_id"
    t.integer "species_list_id"
    t.datetime "updated_at", precision: nil
    t.text "notes"
    t.integer "name_id"
    t.integer "location_id"
    t.integer "project_id"
    t.integer "glossary_term_id"
    t.integer "article_id"
    t.datetime "created_at", precision: nil, null: false
  end

  create_table "sequences", id: :integer, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "observation_id"
    t.integer "user_id"
    t.text "locus", size: :medium
    t.text "bases", size: :medium
    t.string "archive"
    t.string "accession"
    t.text "notes", size: :medium
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "solid_queue_blocked_executions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.string "concurrency_key", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.text "error"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "queue_name", null: false
    t.string "class_name", null: false
    t.text "arguments"
    t.integer "priority", default: 0, null: false
    t.string "active_job_id"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "queue_name", null: false
    t.datetime "created_at", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.bigint "supervisor_id"
    t.integer "pid", null: false
    t.string "hostname"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "task_key", null: false
    t.datetime "run_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_scheduled_executions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "scheduled_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "key", null: false
    t.integer "value", default: 1, null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "species_list_observations", charset: "utf8mb3", force: :cascade do |t|
    t.integer "observation_id", default: 0, null: false
    t.integer "species_list_id", default: 0, null: false
  end

  create_table "species_lists", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.date "when"
    t.integer "user_id"
    t.string "where", limit: 1024
    t.string "title", limit: 100
    t.text "notes"
    t.integer "rss_log_id"
    t.integer "location_id"
  end

  create_table "synonyms", id: :integer, charset: "utf8mb3", force: :cascade do |t|
  end

  create_table "translation_string_versions", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.integer "version"
    t.integer "translation_string_id"
    t.text "text"
    t.datetime "updated_at", precision: nil
    t.integer "user_id"
    t.integer "language_id"
  end

  create_table "translation_strings", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.integer "version"
    t.integer "language_id", null: false
    t.string "tag", limit: 100
    t.text "text"
    t.datetime "updated_at", precision: nil
    t.integer "user_id"
  end

  create_table "triples", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.string "subject", limit: 1024
    t.string "predicate", limit: 1024
    t.string "object", limit: 1024
  end

  create_table "user_group_users", charset: "utf8mb3", force: :cascade do |t|
    t.integer "user_id", default: 0, null: false
    t.integer "user_group_id", default: 0, null: false
  end

  create_table "user_groups", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.string "name", default: "", null: false
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.boolean "meta", default: false
  end

  create_table "user_stats", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "user_id", default: 0, null: false
    t.integer "comments", default: 0, null: false
    t.integer "images", default: 0, null: false
    t.integer "location_description_authors", default: 0, null: false
    t.integer "location_description_editors", default: 0, null: false
    t.integer "locations", default: 0, null: false
    t.integer "location_versions", default: 0, null: false
    t.integer "name_description_authors", default: 0, null: false
    t.integer "name_description_editors", default: 0, null: false
    t.integer "names", default: 0, null: false
    t.integer "name_versions", default: 0, null: false
    t.integer "namings", default: 0, null: false
    t.integer "observations", default: 0, null: false
    t.integer "sequences", default: 0, null: false
    t.integer "sequenced_observations", default: 0, null: false
    t.integer "species_list_entries", default: 0, null: false
    t.integer "species_lists", default: 0, null: false
    t.integer "translation_strings", default: 0, null: false
    t.integer "votes", default: 0, null: false
    t.string "languages"
    t.string "bonuses"
    t.string "checklist"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "user_index"
  end

  create_table "users", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.string "login", limit: 80, default: "", null: false
    t.string "password", limit: 40, default: "", null: false
    t.string "email", limit: 80, default: "", null: false
    t.string "theme", limit: 40
    t.string "name", limit: 80
    t.datetime "created_at", precision: nil
    t.datetime "last_login", precision: nil
    t.datetime "verified", precision: nil
    t.integer "license_id", default: 10, null: false
    t.integer "contribution", default: 0
    t.integer "location_id"
    t.integer "image_id"
    t.string "locale", limit: 5
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
    t.datetime "updated_at", precision: nil
    t.boolean "admin"
    t.text "alert"
    t.boolean "email_locations_admin", default: false
    t.boolean "email_names_admin", default: false
    t.integer "thumbnail_size", default: 1
    t.integer "image_size", default: 5
    t.string "default_rss_type", limit: 40, default: "all"
    t.integer "votes_anonymous", default: 1
    t.integer "location_format", default: 1
    t.datetime "last_activity", precision: nil
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
    t.boolean "blocked", default: false, null: false
    t.boolean "no_emails", default: false, null: false
    t.index ["login"], name: "login_index"
  end

  create_table "visual_group_images", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "image_id"
    t.integer "visual_group_id"
    t.boolean "included", default: true, null: false
  end

  create_table "visual_groups", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "visual_model_id"
    t.string "name", null: false
    t.boolean "approved", default: false, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "visual_models", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "votes", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.integer "naming_id"
    t.integer "user_id"
    t.integer "observation_id", default: 0
    t.boolean "favorite"
    t.float "value"
    t.index ["naming_id"], name: "naming_index"
    t.index ["observation_id"], name: "observation_index"
  end

  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
end
