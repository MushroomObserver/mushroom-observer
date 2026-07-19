# frozen_string_literal: true

# #4807's I18n::Backend::DbFallback introduced the first-ever live
# `find_by(tag: ...)` query against translation_strings.tag at
# request-serving time; the column had no index at all before now,
# because no caller ever point-queried it live until this PR.
#
# Originally paired with a utf8mb3_bin collation change too, needed
# because en.txt carried both `NOTES` and `notes` as distinct tags and
# the column's default utf8mb3_general_ci collation is case-INsensitive,
# so a lookup for one could nondeterministically return the other's
# row. #4843 eliminated every ALL-CAPS/lowercase twin tag in the app --
# every tag is lowercase-only now -- so that case-sensitivity
# requirement no longer exists and the collation change was dropped
# here. Just the index remains.
class AddIndexToTranslationStringsTag < ActiveRecord::Migration[7.2]
  def change
    add_index(:translation_strings, [:language_id, :tag])
  end
end
