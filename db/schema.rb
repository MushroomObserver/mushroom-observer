# encoding: UTF-8
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

ActiveRecord::Schema.define(version: 20170827000729) do

  create_table "api_keys", force: :cascade do |t|
    t.datetime "created_at"
    t.datetime "last_used"
    t.integer  "num_uses",   limit: 4,     default: 0
    t.integer  "user_id",    limit: 4,                 null: false
    t.string   "key",        limit: 128,               null: false
    t.text     "notes",      limit: 65535
    t.datetime "verified"
  end

  create_table "articles", force: :cascade do |t|
    t.string   "title",      limit: 255
    t.text     "body",       limit: 65535
    t.integer  "user_id",    limit: 4
    t.integer  "rss_log_id", limit: 4
    t.datetime "created_at",               null: false
    t.datetime "updated_at",               null: false
  end

  create_table "comments", force: :cascade do |t|
    t.datetime "created_at"
    t.integer  "user_id",     limit: 4
    t.string   "summary",     limit: 100
    t.text     "comment",     limit: 65535
    t.string   "target_type", limit: 30
    t.integer  "target_id",   limit: 4
    t.datetime "updated_at"
  end

  create_table "copyright_changes", force: :cascade do |t|
    t.integer  "user_id",     limit: 4,   null: false
    t.datetime "updated_at",              null: false
    t.string   "target_type", limit: 30,  null: false
    t.integer  "target_id",   limit: 4,   null: false
    t.integer  "year",        limit: 4
    t.string   "name",        limit: 255
    t.integer  "license_id",  limit: 4
  end

  create_table "donations", force: :cascade do |t|
    t.decimal  "amount",                 precision: 12, scale: 2
    t.string   "who",        limit: 100
    t.string   "email",      limit: 100
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "anonymous",                                       default: false, null: false
    t.boolean  "reviewed",                                        default: true,  null: false
    t.integer  "user_id",    limit: 4
    t.boolean  "recurring",                                       default: false
  end

  create_table "external_links", force: :cascade do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "user_id",          limit: 4
    t.integer  "observation_id",   limit: 4
    t.integer  "external_site_id", limit: 4
    t.string   "url",              limit: 100
  end

  create_table "external_sites", force: :cascade do |t|
    t.string  "name",       limit: 100
    t.integer "project_id", limit: 4
  end

  create_table "glossary_terms", force: :cascade do |t|
    t.integer  "version",        limit: 4
    t.integer  "user_id",        limit: 4
    t.string   "name",           limit: 1024
    t.integer  "thumb_image_id", limit: 4
    t.text     "description",    limit: 65535
    t.integer  "rss_log_id",     limit: 4
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "glossary_terms_images", id: false, force: :cascade do |t|
    t.integer "image_id",         limit: 4
    t.integer "glossary_term_id", limit: 4
  end

  create_table "glossary_terms_versions", force: :cascade do |t|
    t.integer  "glossary_term_id", limit: 4
    t.integer  "version",          limit: 4
    t.integer  "user_id",          limit: 4
    t.datetime "updated_at"
    t.string   "name",             limit: 1024
    t.text     "description",      limit: 65535
  end

  create_table "herbaria", force: :cascade do |t|
    t.text     "mailing_address",  limit: 65535
    t.integer  "location_id",      limit: 4
    t.string   "email",            limit: 80,    default: "", null: false
    t.string   "name",             limit: 1024
    t.text     "description",      limit: 65535
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "code",             limit: 8,     default: "", null: false
    t.integer  "personal_user_id", limit: 4
  end

  create_table "herbaria_curators", id: false, force: :cascade do |t|
    t.integer "user_id",      limit: 4, default: 0, null: false
    t.integer "herbarium_id", limit: 4, default: 0, null: false
  end

  create_table "image_votes", force: :cascade do |t|
    t.integer "value",     limit: 4,                 null: false
    t.boolean "anonymous",           default: false, null: false
    t.integer "user_id",   limit: 4
    t.integer "image_id",  limit: 4
  end

  add_index "image_votes", ["image_id"], name: "index_image_votes_on_image_id", using: :btree
  add_index "image_votes", ["user_id"], name: "index_image_votes_on_user_id", using: :btree

  create_table "images", force: :cascade do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "content_type",     limit: 100
    t.integer  "user_id",          limit: 4
    t.date     "when"
    t.text     "notes",            limit: 65535
    t.string   "copyright_holder", limit: 100
    t.integer  "license_id",       limit: 4,     default: 1,     null: false
    t.integer  "num_views",        limit: 4,     default: 0,     null: false
    t.datetime "last_view"
    t.integer  "width",            limit: 4
    t.integer  "height",           limit: 4
    t.float    "vote_cache",       limit: 24
    t.boolean  "ok_for_export",                  default: true,  null: false
    t.string   "original_name",    limit: 120,   default: ""
    t.boolean  "transferred",                    default: false, null: false
  end

  create_table "images_observations", id: false, force: :cascade do |t|
    t.integer "image_id",       limit: 4, default: 0, null: false
    t.integer "observation_id", limit: 4, default: 0, null: false
  end

  create_table "images_projects", id: false, force: :cascade do |t|
    t.integer "image_id",   limit: 4, null: false
    t.integer "project_id", limit: 4, null: false
  end

  create_table "interests", force: :cascade do |t|
    t.string   "target_type", limit: 30
    t.integer  "target_id",   limit: 4
    t.integer  "user_id",     limit: 4
    t.boolean  "state"
    t.datetime "updated_at"
  end

  create_table "languages", force: :cascade do |t|
    t.string  "locale",   limit: 40
    t.string  "name",     limit: 100
    t.string  "order",    limit: 100
    t.boolean "official",             null: false
    t.boolean "beta",                 null: false
    t.string  "region",   limit: 4
  end

  create_table "licenses", force: :cascade do |t|
    t.string   "display_name", limit: 80
    t.string   "url",          limit: 200
    t.boolean  "deprecated",               default: false, null: false
    t.string   "form_name",    limit: 20
    t.datetime "updated_at"
  end

  create_table "location_descriptions", force: :cascade do |t|
    t.integer  "version",         limit: 4
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "user_id",         limit: 4
    t.integer  "location_id",     limit: 4
    t.integer  "num_views",       limit: 4,     default: 0
    t.datetime "last_view"
    t.integer  "source_type",     limit: 4
    t.string   "source_name",     limit: 100
    t.string   "locale",          limit: 8
    t.boolean  "public"
    t.integer  "license_id",      limit: 4
    t.integer  "merge_source_id", limit: 4
    t.text     "gen_desc",        limit: 65535
    t.text     "ecology",         limit: 65535
    t.text     "species",         limit: 65535
    t.text     "notes",           limit: 65535
    t.text     "refs",            limit: 65535
    t.boolean  "ok_for_export",                 default: true, null: false
    t.integer  "project_id",      limit: 4
  end

  create_table "location_descriptions_admins", id: false, force: :cascade do |t|
    t.integer "location_description_id", limit: 4, default: 0, null: false
    t.integer "user_group_id",           limit: 4, default: 0, null: false
  end

  create_table "location_descriptions_authors", id: false, force: :cascade do |t|
    t.integer "location_description_id", limit: 4, default: 0, null: false
    t.integer "user_id",                 limit: 4, default: 0, null: false
  end

  create_table "location_descriptions_editors", id: false, force: :cascade do |t|
    t.integer "location_description_id", limit: 4, default: 0, null: false
    t.integer "user_id",                 limit: 4, default: 0, null: false
  end

  create_table "location_descriptions_readers", id: false, force: :cascade do |t|
    t.integer "location_description_id", limit: 4, default: 0, null: false
    t.integer "user_group_id",           limit: 4, default: 0, null: false
  end

  create_table "location_descriptions_versions", force: :cascade do |t|
    t.integer  "location_description_id", limit: 4
    t.integer  "version",                 limit: 4
    t.datetime "updated_at"
    t.integer  "user_id",                 limit: 4
    t.integer  "license_id",              limit: 4
    t.integer  "merge_source_id",         limit: 4
    t.text     "gen_desc",                limit: 65535
    t.text     "ecology",                 limit: 65535
    t.text     "species",                 limit: 65535
    t.text     "notes",                   limit: 65535
    t.text     "refs",                    limit: 65535
  end

  create_table "location_descriptions_writers", id: false, force: :cascade do |t|
    t.integer "location_description_id", limit: 4, default: 0, null: false
    t.integer "user_group_id",           limit: 4, default: 0, null: false
  end

  create_table "locations", force: :cascade do |t|
    t.integer  "version",         limit: 4
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "user_id",         limit: 4
    t.integer  "description_id",  limit: 4
    t.integer  "rss_log_id",      limit: 4
    t.integer  "num_views",       limit: 4,     default: 0
    t.datetime "last_view"
    t.float    "north",           limit: 24
    t.float    "south",           limit: 24
    t.float    "west",            limit: 24
    t.float    "east",            limit: 24
    t.float    "high",            limit: 24
    t.float    "low",             limit: 24
    t.boolean  "ok_for_export",                 default: true, null: false
    t.text     "notes",           limit: 65535
    t.string   "name",            limit: 1024
    t.string   "scientific_name", limit: 1024
  end

  create_table "locations_versions", force: :cascade do |t|
    t.string   "location_id",     limit: 255
    t.integer  "version",         limit: 4
    t.datetime "updated_at"
    t.integer  "user_id",         limit: 4
    t.float    "north",           limit: 24
    t.float    "south",           limit: 24
    t.float    "west",            limit: 24
    t.float    "east",            limit: 24
    t.float    "high",            limit: 24
    t.float    "low",             limit: 24
    t.string   "name",            limit: 1024
    t.text     "notes",           limit: 65535
    t.string   "scientific_name", limit: 1024
  end

  create_table "name_descriptions", force: :cascade do |t|
    t.integer  "version",         limit: 4
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "user_id",         limit: 4
    t.integer  "name_id",         limit: 4
    t.integer  "review_status",   limit: 4,     default: 1
    t.datetime "last_review"
    t.integer  "reviewer_id",     limit: 4
    t.boolean  "ok_for_export",                 default: true, null: false
    t.integer  "num_views",       limit: 4,     default: 0
    t.datetime "last_view"
    t.integer  "source_type",     limit: 4
    t.string   "source_name",     limit: 100
    t.string   "locale",          limit: 8
    t.boolean  "public"
    t.integer  "license_id",      limit: 4
    t.integer  "merge_source_id", limit: 4
    t.text     "gen_desc",        limit: 65535
    t.text     "diag_desc",       limit: 65535
    t.text     "distribution",    limit: 65535
    t.text     "habitat",         limit: 65535
    t.text     "look_alikes",     limit: 65535
    t.text     "uses",            limit: 65535
    t.text     "notes",           limit: 65535
    t.text     "refs",            limit: 65535
    t.text     "classification",  limit: 65535
    t.integer  "project_id",      limit: 4
  end

  create_table "name_descriptions_admins", id: false, force: :cascade do |t|
    t.integer "name_description_id", limit: 4, default: 0, null: false
    t.integer "user_group_id",       limit: 4, default: 0, null: false
  end

  create_table "name_descriptions_authors", id: false, force: :cascade do |t|
    t.integer "name_description_id", limit: 4, default: 0, null: false
    t.integer "user_id",             limit: 4, default: 0, null: false
  end

  create_table "name_descriptions_editors", id: false, force: :cascade do |t|
    t.integer "name_description_id", limit: 4, default: 0, null: false
    t.integer "user_id",             limit: 4, default: 0, null: false
  end

  create_table "name_descriptions_readers", id: false, force: :cascade do |t|
    t.integer "name_description_id", limit: 4, default: 0, null: false
    t.integer "user_group_id",       limit: 4, default: 0, null: false
  end

  create_table "name_descriptions_versions", force: :cascade do |t|
    t.integer  "name_description_id", limit: 4
    t.integer  "version",             limit: 4
    t.datetime "updated_at"
    t.integer  "user_id",             limit: 4
    t.integer  "license_id",          limit: 4
    t.integer  "merge_source_id",     limit: 4
    t.text     "gen_desc",            limit: 65535
    t.text     "diag_desc",           limit: 65535
    t.text     "distribution",        limit: 65535
    t.text     "habitat",             limit: 65535
    t.text     "look_alikes",         limit: 65535
    t.text     "uses",                limit: 65535
    t.text     "notes",               limit: 65535
    t.text     "refs",                limit: 65535
    t.text     "classification",      limit: 65535
  end

  create_table "name_descriptions_writers", id: false, force: :cascade do |t|
    t.integer "name_description_id", limit: 4, default: 0, null: false
    t.integer "user_group_id",       limit: 4, default: 0, null: false
  end

  create_table "names", force: :cascade do |t|
    t.integer  "version",             limit: 4
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "user_id",             limit: 4
    t.integer  "description_id",      limit: 4
    t.integer  "rss_log_id",          limit: 4
    t.integer  "num_views",           limit: 4,     default: 0
    t.datetime "last_view"
    t.integer  "rank",                limit: 4
    t.string   "text_name",           limit: 100
    t.string   "search_name",         limit: 221
    t.string   "display_name",        limit: 204
    t.string   "sort_name",           limit: 241
    t.text     "citation",            limit: 65535
    t.boolean  "deprecated",                        default: false, null: false
    t.integer  "synonym_id",          limit: 4
    t.integer  "correct_spelling_id", limit: 4
    t.text     "notes",               limit: 65535
    t.text     "classification",      limit: 65535
    t.boolean  "ok_for_export",                     default: true,  null: false
    t.string   "author",              limit: 100
  end

  create_table "names_versions", force: :cascade do |t|
    t.integer  "name_id",             limit: 4
    t.integer  "version",             limit: 4
    t.datetime "updated_at"
    t.integer  "user_id",             limit: 4
    t.string   "text_name",           limit: 100
    t.string   "search_name",         limit: 221
    t.string   "display_name",        limit: 204
    t.string   "sort_name",           limit: 241
    t.string   "author",              limit: 100
    t.text     "citation",            limit: 65535
    t.boolean  "deprecated",                        default: false, null: false
    t.integer  "correct_spelling_id", limit: 4
    t.text     "notes",               limit: 65535
    t.integer  "rank",                limit: 4
  end

  create_table "naming_reasons", force: :cascade do |t|
    t.integer "naming_id", limit: 4
    t.integer "reason",    limit: 4
    t.text    "notes",     limit: 65535
  end

  create_table "namings", force: :cascade do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "observation_id", limit: 4
    t.integer  "name_id",        limit: 4
    t.integer  "user_id",        limit: 4
    t.float    "vote_cache",     limit: 24,    default: 0.0
    t.text     "reasons",        limit: 65535
  end

  create_table "notifications", force: :cascade do |t|
    t.integer  "user_id",          limit: 4,     default: 0,     null: false
    t.integer  "flavor",           limit: 4
    t.integer  "obj_id",           limit: 4
    t.text     "note_template",    limit: 65535
    t.datetime "updated_at"
    t.boolean  "require_specimen",               default: false, null: false
  end

  create_table "observations", force: :cascade do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.date     "when"
    t.integer  "user_id",                limit: 4
    t.boolean  "specimen",                                                       default: false, null: false
    t.text     "notes",                  limit: 65535
    t.integer  "thumb_image_id",         limit: 4
    t.integer  "name_id",                limit: 4
    t.integer  "location_id",            limit: 4
    t.boolean  "is_collection_location",                                         default: true,  null: false
    t.float    "vote_cache",             limit: 24,                              default: 0.0
    t.integer  "num_views",              limit: 4,                               default: 0,     null: false
    t.datetime "last_view"
    t.integer  "rss_log_id",             limit: 4
    t.decimal  "lat",                                  precision: 15, scale: 10
    t.decimal  "long",                                 precision: 15, scale: 10
    t.string   "where",                  limit: 1024
    t.integer  "alt",                    limit: 4
  end

  create_table "observations_projects", id: false, force: :cascade do |t|
    t.integer "observation_id", limit: 4, null: false
    t.integer "project_id",     limit: 4, null: false
  end

  create_table "observations_species_lists", id: false, force: :cascade do |t|
    t.integer "observation_id",  limit: 4, default: 0, null: false
    t.integer "species_list_id", limit: 4, default: 0, null: false
  end

  create_table "observations_specimens", id: false, force: :cascade do |t|
    t.integer "observation_id", limit: 4, default: 0, null: false
    t.integer "specimen_id",    limit: 4, default: 0, null: false
  end

  create_table "projects", force: :cascade do |t|
    t.integer  "user_id",        limit: 4,     default: 0,  null: false
    t.integer  "admin_group_id", limit: 4,     default: 0,  null: false
    t.integer  "user_group_id",  limit: 4,     default: 0,  null: false
    t.string   "title",          limit: 100,   default: "", null: false
    t.text     "summary",        limit: 65535
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "rss_log_id",     limit: 4
  end

  create_table "projects_species_lists", id: false, force: :cascade do |t|
    t.integer "project_id",      limit: 4, null: false
    t.integer "species_list_id", limit: 4, null: false
  end

  create_table "publications", force: :cascade do |t|
    t.integer  "user_id",       limit: 4
    t.text     "full",          limit: 65535
    t.string   "link",          limit: 255
    t.text     "how_helped",    limit: 65535
    t.boolean  "mo_mentioned"
    t.boolean  "peer_reviewed"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "query_records", force: :cascade do |t|
    t.datetime "updated_at"
    t.integer  "access_count", limit: 4
    t.text     "description",  limit: 65535
    t.integer  "outer_id",     limit: 4
  end

  create_table "queued_email_integers", force: :cascade do |t|
    t.integer "queued_email_id", limit: 4,   default: 0, null: false
    t.string  "key",             limit: 100
    t.integer "value",           limit: 4,   default: 0, null: false
  end

  create_table "queued_email_notes", force: :cascade do |t|
    t.integer "queued_email_id", limit: 4,     default: 0, null: false
    t.text    "value",           limit: 65535
  end

  create_table "queued_email_strings", force: :cascade do |t|
    t.integer "queued_email_id", limit: 4,   default: 0, null: false
    t.string  "key",             limit: 100
    t.string  "value",           limit: 100
  end

  create_table "queued_emails", force: :cascade do |t|
    t.integer  "user_id",      limit: 4
    t.datetime "queued"
    t.integer  "num_attempts", limit: 4
    t.string   "flavor",       limit: 40
    t.integer  "to_user_id",   limit: 4
  end

  create_table "rss_logs", force: :cascade do |t|
    t.integer  "observation_id",   limit: 4
    t.integer  "species_list_id",  limit: 4
    t.datetime "updated_at"
    t.text     "notes",            limit: 65535
    t.integer  "name_id",          limit: 4
    t.integer  "location_id",      limit: 4
    t.integer  "project_id",       limit: 4
    t.integer  "glossary_term_id", limit: 4
    t.integer  "article_id",       limit: 4
  end

  create_table "sequences", force: :cascade do |t|
    t.integer  "observation_id", limit: 4
    t.integer  "user_id",        limit: 4
    t.text     "locus",          limit: 65535
    t.text     "bases",          limit: 65535
    t.string   "archive",        limit: 255
    t.string   "accession",      limit: 255
    t.text     "notes",          limit: 65535
    t.datetime "created_at",                   null: false
    t.datetime "updated_at",                   null: false
  end

  create_table "species_lists", force: :cascade do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.date     "when"
    t.integer  "user_id",     limit: 4
    t.string   "where",       limit: 1024
    t.string   "title",       limit: 100
    t.text     "notes",       limit: 65535
    t.integer  "rss_log_id",  limit: 4
    t.integer  "location_id", limit: 4
  end

  create_table "specimens", force: :cascade do |t|
    t.integer  "herbarium_id",    limit: 4,                  null: false
    t.date     "when",                                       null: false
    t.text     "notes",           limit: 65535
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "user_id",         limit: 4,                  null: false
    t.string   "herbarium_label", limit: 80,    default: "", null: false
  end

  create_table "synonyms", force: :cascade do |t|
  end

  create_table "translation_strings", force: :cascade do |t|
    t.integer  "version",     limit: 4
    t.integer  "language_id", limit: 4,     null: false
    t.string   "tag",         limit: 100
    t.text     "text",        limit: 65535
    t.datetime "updated_at"
    t.integer  "user_id",     limit: 4
  end

  create_table "translation_strings_versions", force: :cascade do |t|
    t.integer  "version",               limit: 4
    t.integer  "translation_string_id", limit: 4
    t.text     "text",                  limit: 65535
    t.datetime "updated_at"
    t.integer  "user_id",               limit: 4
  end

  create_table "triples", force: :cascade do |t|
    t.string "subject",   limit: 1024
    t.string "predicate", limit: 1024
    t.string "object",    limit: 1024
  end

  create_table "user_groups", force: :cascade do |t|
    t.string   "name",       limit: 255, default: "",    null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "meta",                   default: false
  end

  create_table "user_groups_users", id: false, force: :cascade do |t|
    t.integer "user_id",       limit: 4, default: 0, null: false
    t.integer "user_group_id", limit: 4, default: 0, null: false
  end

  create_table "users", force: :cascade do |t|
    t.string   "login",                        limit: 80,    default: "",    null: false
    t.string   "password",                     limit: 40,    default: "",    null: false
    t.string   "email",                        limit: 80,    default: "",    null: false
    t.string   "theme",                        limit: 40
    t.string   "name",                         limit: 80
    t.datetime "created_at"
    t.datetime "last_login"
    t.datetime "verified"
    t.integer  "license_id",                   limit: 4,     default: 3,     null: false
    t.integer  "contribution",                 limit: 4,     default: 0
    t.integer  "location_id",                  limit: 4
    t.integer  "image_id",                     limit: 4
    t.string   "locale",                       limit: 5
    t.text     "bonuses",                      limit: 65535
    t.boolean  "email_comments_owner",                       default: true,  null: false
    t.boolean  "email_comments_response",                    default: true,  null: false
    t.boolean  "email_comments_all",                         default: false, null: false
    t.boolean  "email_observations_consensus",               default: true,  null: false
    t.boolean  "email_observations_naming",                  default: true,  null: false
    t.boolean  "email_observations_all",                     default: false, null: false
    t.boolean  "email_names_author",                         default: true,  null: false
    t.boolean  "email_names_editor",                         default: false, null: false
    t.boolean  "email_names_reviewer",                       default: true,  null: false
    t.boolean  "email_names_all",                            default: false, null: false
    t.boolean  "email_locations_author",                     default: true,  null: false
    t.boolean  "email_locations_editor",                     default: false, null: false
    t.boolean  "email_locations_all",                        default: false, null: false
    t.boolean  "email_general_feature",                      default: true,  null: false
    t.boolean  "email_general_commercial",                   default: true,  null: false
    t.boolean  "email_general_question",                     default: true,  null: false
    t.boolean  "email_html",                                 default: true,  null: false
    t.datetime "updated_at"
    t.boolean  "admin"
    t.text     "alert",                        limit: 65535
    t.boolean  "email_locations_admin",                      default: false
    t.boolean  "email_names_admin",                          default: false
    t.integer  "thumbnail_size",               limit: 4,     default: 1
    t.integer  "image_size",                   limit: 4,     default: 3
    t.string   "default_rss_type",             limit: 40,    default: "all"
    t.integer  "votes_anonymous",              limit: 4,     default: 1
    t.integer  "location_format",              limit: 4,     default: 1
    t.datetime "last_activity"
    t.integer  "hide_authors",                 limit: 4,     default: 1,     null: false
    t.boolean  "thumbnail_maps",                             default: true,  null: false
    t.string   "auth_code",                    limit: 40
    t.integer  "keep_filenames",               limit: 4,     default: 1,     null: false
    t.text     "notes",                        limit: 65535
    t.text     "mailing_address",              limit: 65535
    t.integer  "layout_count",                 limit: 4
    t.boolean  "view_owner_id",                              default: false, null: false
    t.string   "content_filter",               limit: 255
    t.text     "notes_template",               limit: 65535
  end

  create_table "votes", force: :cascade do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "naming_id",      limit: 4
    t.integer  "user_id",        limit: 4
    t.integer  "observation_id", limit: 4,  default: 0
    t.boolean  "favorite"
    t.float    "value",          limit: 24
  end

end
