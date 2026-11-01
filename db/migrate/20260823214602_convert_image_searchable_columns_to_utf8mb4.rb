# frozen_string_literal: true

# Second incremental step toward issue #4625 (full utf8mb4 conversion),
# same shape as #5153's comments/users.notes conversion: a free-text
# column users have hit with 4-byte characters (emoji in an iNat
# import's copyright notice, #4804), a production 500. None of these
# three columns are indexed, so the index-key-length concerns that
# defer #4625 don't apply.
#
# All three of Image::SEARCHABLE_FIELDS convert together, not just
# copyright_holder: AbstractModel.searchable_columns concatenates them
# with Arel `+` (Image.pattern, Image.copyright_holder_has's sibling
# scopes), and #5153 already hit "Illegal mix of collations" from
# concatenating two different collations of the same (utf8mb4) charset
# in this kind of expression. Converting copyright_holder alone while
# original_name/notes stayed utf8mb3 would reintroduce that.
#
# utf8mb4_general_ci, not utf8mb4_0900_ai_ci, matching #5153's choice:
# the connection collation is utf8mb4_general_ci, and 0900_ai_ci has to
# wait until #4625 flips the connection collation and every table
# together.
#
# Image.pattern also concatenates these three with observations.where
# and names.search_name, both still utf8mb3. Unlike the same-charset
# mismatch above, mixing utf8mb3 with utf8mb4 is a documented, safe
# case: utf8mb4 is a superset of utf8mb3, so the expression resolves
# to utf8mb4 using the utf8mb4 operand's collation (MySQL 8.4
# Reference Manual, 12.9.1 "The utf8mb4 Character Set").
class ConvertImageSearchableColumnsToUtf8mb4 < ActiveRecord::Migration[7.2]
  def up
    change_table(:images, bulk: true) do |t|
      t.change(:copyright_holder, :string, collation: "utf8mb4_general_ci")
      t.change(:original_name, :string, limit: 120, default: "",
                                        collation: "utf8mb4_general_ci")
      t.change(:notes, :text, collation: "utf8mb4_general_ci")
    end
  end

  def down
    change_table(:images, bulk: true) do |t|
      t.change(:copyright_holder, :string, collation: "utf8mb3_general_ci")
      t.change(:original_name, :string, limit: 120, default: "",
                                        collation: "utf8mb3_general_ci")
      t.change(:notes, :text, collation: "utf8mb3_general_ci")
    end
  end
end
