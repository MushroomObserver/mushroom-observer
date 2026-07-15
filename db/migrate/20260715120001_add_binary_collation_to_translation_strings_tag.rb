# frozen_string_literal: true

# translation_strings.tag had no explicit collation, so it inherited the
# table's default utf8mb3_general_ci -- case-INsensitive. That was
# harmless while the only reader was LanguageExporter, which loaded
# every row into a case-sensitive Ruby Hash keyed by Symbol (`:NOTES`
# and `:notes` are distinct Ruby symbols). #4807's
# I18n::Backend::DbFallback introduced the first-ever live
# `find_by(tag: ...)` query against this column at request-serving
# time, and under _ci collation MySQL treats "NOTES" and "notes" as
# equal -- en.txt genuinely has both as distinct tags (see
# config/locales/en.txt: "NOTES: Notes" / "notes: notes"), so a lookup
# for one can nondeterministically return the other's row (and then
# self-poison the cache with the wrong text under the requested tag).
#
# Switching to utf8mb3_bin is metadata-only -- same bytes, same
# length, no rewrite of existing rows.
#
# Also adds the [language_id, tag] index this exact query pattern
# needs: the column had no index at all before now, because no caller
# ever point-queried it live until this PR.
#
# CAVEAT for issue #4625 (utf8mb3 -> utf8mb4 conversion): that sweep's
# planned blanket collation is utf8mb4_0900_ai_ci -- the "ci" is
# case-INsensitive, same failure mode this migration just fixed. When
# #4625 reaches this table, this column must convert to utf8mb4_bin
# specifically, not the sweep's default collation, or the NOTES/notes
# collision comes back.
class AddBinaryCollationToTranslationStringsTag <
      ActiveRecord::Migration[7.2]
  def up
    change_tag_collation("utf8mb3_bin")
    add_index(:translation_strings, [:language_id, :tag])
  end

  def down
    remove_index(:translation_strings, [:language_id, :tag])
    change_tag_collation("utf8mb3_general_ci")
  end

  private

  def change_tag_collation(collation)
    change_column(:translation_strings, :tag, :string, limit: 100,
                                                       collation: collation)
  end
end
