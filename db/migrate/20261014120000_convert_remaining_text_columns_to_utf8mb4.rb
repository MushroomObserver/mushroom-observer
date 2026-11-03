# frozen_string_literal: true

# #4625, closing out what 20260821200358 and 20261012130000 each took a
# piece of: every remaining TEXT column still on utf8mb3. The
# connection runs utf8mb4 now, so a 4-byte character reaches the column
# instead of being refused at the connection, and any of these rejects
# the row -- "Incorrect string value" -- which is a 500 wherever a
# person typed it. Observation notes, naming reasons, descriptions,
# species list notes and herbarium record notes are the paths people
# type into daily.
#
# TEXT columns sit in no index, so the index-key-length audit that
# defers the rest of #4625 does not apply to any of these, which is
# what makes the whole set safe to take in one pass. Every one is
# nullable with no default, so the type and collation are the only
# things the change restates.
#
# utf8mb4_general_ci to match the connection collation and the columns
# converted so far. The varchar columns, the table defaults and the
# move to utf8mb4_0900_ai_ci stay with #4625.
#
# Measured at ~1s per table on a copy of production, including
# namings (871k rows) and observations (664k).
class ConvertRemainingTextColumnsToUtf8mb4 < ActiveRecord::Migration[7.2]
  COLUMNS = {
    api_keys: :notes,
    external_sites: [:description, :media_hosts],
    glossary_term_versions: :description,
    glossary_terms: :description,
    herbaria: [:description, :mailing_address],
    herbarium_records: :notes,
    location_description_versions: [:ecology, :gen_desc, :notes, :refs,
                                    :species],
    location_descriptions: [:ecology, :gen_desc, :notes, :refs, :species],
    location_versions: :notes,
    locations: :notes,
    name_description_versions: [:diag_desc, :distribution, :gen_desc, :habitat,
                                :look_alikes, :notes, :refs, :uses],
    name_descriptions: [:diag_desc, :distribution, :gen_desc, :habitat,
                        :look_alikes, :notes, :refs, :uses],
    name_trackers: :note_template,
    name_versions: [:citation, :classification, :notes],
    names: [:citation, :classification, :notes],
    naming_reasons: :notes,
    namings: :reasons,
    observations: [:notes, :skeleton_omissions],
    project_external_sites: :alert_recipient_ids,
    projects: :summary,
    publications: [:full, :how_helped],
    species_lists: :notes,
    translation_string_versions: :text,
    translation_strings: :text,
    users: [:alert, :mailing_address, :notes_template]
  }.freeze

  def up
    convert("utf8mb4_general_ci")
  end

  # Narrowing only works while no row holds a 4-byte character, which
  # is in the nature of the column rather than a fault here.
  def down
    convert("utf8mb3_general_ci")
  end

  private

  def convert(collation)
    COLUMNS.each do |table, columns|
      Array(columns).each do |column|
        change_column(table, column, :text, collation: collation)
      end
    end
  end
end
