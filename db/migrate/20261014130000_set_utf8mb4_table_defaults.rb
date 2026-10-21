# frozen_string_literal: true

# #4625: the default charset these tables hand to a column created
# without one. Every TEXT column is utf8mb4 as of 20261014120000, but
# a table whose default is still utf8mb3 gives the next `add_column`
# a utf8mb3 column, which puts back the failure that migration just
# cleared -- and nothing in review would show it, since the migration
# reads as ordinary and the column comes out utf8mb3 on its own.
#
# DEFAULT CHARACTER SET is not CONVERT TO CHARACTER SET: it sets what
# future columns inherit and leaves every existing column as it is.
# Measured at under a second per table on a copy of production,
# including observations at 664k rows, because no row is read.
#
# So the 64 varchar columns still on utf8mb3 stay that way, and
# schema.rb starts naming them explicitly instead of letting them hide
# behind a table default. Converting those, and the move to
# utf8mb4_0900_ai_ci, stay with #4625 -- they need the index key
# lengths confirmed on MySQL 8 and they rewrite the big tables.
#
# Raw DDL because ActiveRecord has no API for a table's default
# charset: `create_table` takes `charset:`, and there is no
# `change_table` equivalent. The table names are a frozen list here,
# quoted as identifiers, with nothing interpolated from outside.
class SetUtf8mb4TableDefaults < ActiveRecord::Migration[7.2]
  TABLES = %w[
    api_keys collection_numbers comments copyright_changes donations
    external_links external_site_usages external_sites
    glossary_term_images glossary_term_versions glossary_terms herbaria
    herbarium_curators herbarium_records image_votes images interests
    languages licenses location_description_admins
    location_description_authors location_description_editors
    location_description_readers location_description_versions
    location_description_writers location_descriptions location_versions
    locations name_description_admins name_description_authors
    name_description_editors name_description_readers
    name_description_versions name_description_writers name_descriptions
    name_trackers name_versions names naming_reasons namings
    observation_collection_numbers observation_herbarium_records
    observation_images observation_views observations
    project_external_site_alerts project_external_sites project_images
    project_observations project_species_lists projects publications
    query_records rss_logs species_list_observations species_lists
    synonyms translation_string_versions translation_strings triples
    user_group_users user_groups users votes
  ].freeze

  def up
    retarget("utf8mb4", "utf8mb4_general_ci")
  end

  def down
    retarget("utf8mb3", "utf8mb3_general_ci")
  end

  private

  def retarget(charset, collation)
    TABLES.each do |table|
      execute("ALTER TABLE #{quote_table_name(table)} " \
              "DEFAULT CHARACTER SET #{charset} COLLATE #{collation}")
    end
  end
end
