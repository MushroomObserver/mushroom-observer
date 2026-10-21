# frozen_string_literal: true

# #4625: the varchar columns, after 20261014120000 took the TEXT ones
# and 20261014130000 the table defaults. Audited first, and none of
# the things that could have blocked it does:
#
#   index key length  every table is DYNAMIC, so the limit is 3072
#                     bytes; the longest indexed column here is
#                     external_links.import_source at 1020
#   duplicate keys    the eight unique indexes over these columns have
#                     the same distinct counts under
#                     utf8mb4_general_ci as they do now
#   row size          observations is the widest at 12,688 bytes of
#                     varchar against a 65,535 limit
#   sort order        unchanged: over 71k names.text_name values, no
#                     row changes position
#   speed             observations.where, varchar(1024) over 643k
#                     rows, in 56ms with ALGORITHM=INPLACE and
#                     LOCK=NONE accepted -- widening is metadata,
#                     since the stored bytes are already valid utf8mb4
#
# Narrowing is the slow direction, so `down` is not the mirror of
# `up` in cost: it has to read every value to confirm it still fits,
# about 11s for that same column, and it fails outright once a row
# holds a 4-byte character.
#
# schema_migrations.version is left alone, as Rails bookkeeping.
#
# external_links needs more than a column change. import_source and
# import_target are stored generated columns over target_type and
# external_id, and MySQL leaves a generated column's charset where it
# was when an operand moves -- converting the operands in place left
# the expression concatenating a utf8mb4 column with utf8mb3 literals
# and the result still declared utf8mb3. MySQL 9 tolerates writing
# that; the 8.0 series is the version that raises on a collation mix,
# which is not something to find out in production. So the two
# columns are dropped and rebuilt around the conversion, which also
# rewrites their ':' literals as utf8mb4 -- the churn PR #5474
# pinned to utf8mb3 in schema.rb, now legitimately the other way.
# Dropping them first also keeps the operand conversion cheap: with
# the generated columns in place it took 18s rather than milliseconds,
# because every stored value had to be recomputed.
class ConvertVarcharColumnsToUtf8mb4 < ActiveRecord::Migration[7.2]
  IMPORT_TARGET =
    "(CASE WHEN relationship = 1 " \
    "THEN CONCAT(target_type, ':', target_id) END)"
  IMPORT_SOURCE =
    "(CASE WHEN relationship = 1 " \
    "THEN CONCAT(external_site_id, ':', target_type, ':', external_id) END)"

  COLUMNS = [
    [:api_keys, :key, { limit: 128, null: false }],
    [:collection_numbers, :name, { limit: 255 }],
    [:collection_numbers, :number, { limit: 255 }],
    [:copyright_changes, :name, { limit: 255 }],
    [:copyright_changes, :target_type, { limit: 30, null: false }],
    [:donations, :email, { limit: 100 }],
    [:donations, :who, { limit: 100 }],
    [:external_links, :external_id, { limit: 64 }],
    [:external_links, :target_type, { limit: 64 }],
    [:external_sites, :base_url, { limit: 255, null: false }],
    [:external_sites, :name, { limit: 100 }],
    [:external_sites, :url_template, { limit: 255 }],
    [:glossary_term_versions, :name, { limit: 1024 }],
    [:glossary_terms, :name, { limit: 1024 }],
    [:herbaria, :code, { limit: 8 }],
    [:herbaria, :email, { limit: 80, null: false, default: "" }],
    [:herbaria, :name, { limit: 1024 }],
    [:herbarium_records, :accession_number, { limit: 80, null: false }],
    [:herbarium_records, :initial_det, { limit: 221, null: false }],
    [:images, :content_type, { limit: 100 }],
    [:interests, :target_type, { limit: 30 }],
    [:languages, :locale, { limit: 40 }],
    [:languages, :name, { limit: 100 }],
    [:languages, :order, { limit: 100 }],
    [:licenses, :display_name, { limit: 80 }],
    [:licenses, :url, { limit: 200 }],
    [:location_descriptions, :locale, { limit: 8 }],
    [:location_descriptions, :source_name, { limit: 100 }],
    [:location_versions, :location_id, { limit: 255 }],
    [:location_versions, :name, { limit: 1024 }],
    [:location_versions, :scientific_name, { limit: 1024 }],
    [:locations, :name, { limit: 1024, null: false }],
    [:locations, :scientific_name, { limit: 1024, null: false }],
    [:name_descriptions, :locale, { limit: 8 }],
    [:name_descriptions, :source_name, { limit: 100 }],
    [:name_versions, :author, { limit: 100 }],
    [:name_versions, :display_name, { limit: 204 }],
    [:name_versions, :lifeform, { limit: 1024, null: false, default: " " }],
    [:name_versions, :search_name, { limit: 221 }],
    [:name_versions, :sort_name, { limit: 241 }],
    [:name_versions, :text_name, { limit: 100 }],
    [:names, :author, { limit: 100 }],
    [:names, :display_name, { limit: 204 }],
    [:names, :lifeform, { limit: 1024, null: false, default: " " }],
    [:names, :search_name, { limit: 221 }],
    [:names, :sort_name, { limit: 241 }],
    [:names, :text_name, { limit: 100 }],
    [:observations, :collector, { limit: 1024 }],
    [:observations, :lifeform, { limit: 1024 }],
    [:observations, :text_name, { limit: 100 }],
    [:observations, :where, { limit: 1024 }],
    [:project_external_site_alerts, :name, { limit: 255 }],
    [:project_external_site_alerts, :remote_identification_id,
     { limit: 100, null: false }],
    [:project_external_site_alerts, :remote_observation_id,
     { limit: 100, null: false }],
    [:project_external_sites, :remote_project_id, { limit: 100 }],
    [:project_external_sites, :remote_project_name, { limit: 255 }],
    [:projects, :field_slip_prefix, { limit: 255 }],
    [:projects, :title, { limit: 100, null: false, default: "" }],
    [:publications, :link, { limit: 255 }],
    [:species_lists, :title, { limit: 100 }],
    [:species_lists, :where, { limit: 1024 }],
    [:translation_strings, :tag, { limit: 100 }],
    [:triples, :object, { limit: 1024 }],
    [:triples, :predicate, { limit: 1024 }],
    [:triples, :subject, { limit: 1024 }],
    [:user_groups, :name, { limit: 255, null: false, default: "" }],
    [:users, :auth_code, { limit: 40 }],
    [:users, :content_filter, { limit: 255 }],
    [:users, :default_rss_type, { limit: 255, default: "all" }],
    [:users, :email, { limit: 80, null: false, default: "" }],
    [:users, :inat_username, { limit: 255 }],
    [:users, :locale, { limit: 5 }],
    [:users, :login, { limit: 80, null: false, default: "" }],
    [:users, :name, { limit: 80 }],
    [:users, :password, { limit: 40, null: false, default: "" }],
    [:users, :theme, { limit: 40 }]
  ].freeze

  def up
    convert("utf8mb4_general_ci")
  end

  def down
    convert("utf8mb3_general_ci")
  end

  private

  def convert(collation)
    drop_generated_columns
    COLUMNS.each do |table, column, options|
      change_column(table, column, :string, **options, collation: collation)
    end
    add_generated_columns
  end

  # Removing the column takes its unique index with it.
  def drop_generated_columns
    remove_column(:external_links, :import_source)
    remove_column(:external_links, :import_target)
  end

  def add_generated_columns
    change_table(:external_links, bulk: true) do |t|
      t.virtual(:import_source, type: :string, stored: true,
                                as: IMPORT_SOURCE)
      t.index(:import_source, unique: true,
                              name: "index_external_links_on_import_source")
      t.virtual(:import_target, type: :string, stored: true,
                                as: IMPORT_TARGET)
      t.index(:import_target, unique: true,
                              name: "index_external_links_on_import_target")
    end
  end
end
