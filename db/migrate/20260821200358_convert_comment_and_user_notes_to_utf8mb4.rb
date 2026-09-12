# frozen_string_literal: true

# First incremental step toward issue #4625 (full utf8mb4 conversion):
# the free-text columns users have hit with 4-byte characters (emoji),
# each a production 500. TEXT columns sit in no index, so the
# index-key-length concerns that defer #4625 don't apply; the one
# converted indexed column (comments.target_type, varchar(30) = 120
# bytes as utf8mb4) is far under InnoDB's key limit. The connection
# already runs utf8mb4, so the columns are the only barrier.
#
# utf8mb4_general_ci, NOT the newer utf8mb4_0900_ai_ci the schema's
# other (standalone) utf8mb4 tables use: the connection collation is
# utf8mb4_general_ci, and Arel's `+` string concat (the search_columns
# pattern scopes, e.g. Comment.pattern) wraps its left operand in a
# bare CAST(... AS CHAR), which takes the CONNECTION collation no
# matter what the column's is. CONCAT(general_ci, 0900_ai_ci) then
# aggregates to utf8mb4_bin with no derivation, and MySQL 8 rejects
# the pattern-search LIKE on it ("Illegal mix of collations" -- caught
# by CI; MySQL 9 tolerates it, so it did not reproduce locally).
# 0900_ai_ci has to wait until #4625 flips the connection collation
# and every table together. All of comments' string columns convert
# in one pass so the table stays single-collation; users.notes has no
# concat partner (the user pattern search reads login + name only).
class ConvertCommentAndUserNotesToUtf8mb4 < ActiveRecord::Migration[7.2]
  def up
    change_column(:comments, :comment, :text,
                  collation: "utf8mb4_general_ci")
    change_column(:comments, :summary, :string,
                  limit: 100, collation: "utf8mb4_general_ci")
    change_column(:comments, :target_type, :string,
                  limit: 30, collation: "utf8mb4_general_ci")
    change_column(:users, :notes, :text,
                  collation: "utf8mb4_general_ci")
  end

  def down
    change_column(:comments, :comment, :text,
                  collation: "utf8mb3_general_ci")
    change_column(:comments, :summary, :string,
                  limit: 100, collation: "utf8mb3_general_ci")
    change_column(:comments, :target_type, :string,
                  limit: 30, collation: "utf8mb3_general_ci")
    change_column(:users, :notes, :text,
                  collation: "utf8mb3_general_ci")
  end
end
