# frozen_string_literal: true

# First incremental step toward issue #4625 (full utf8mb4 conversion):
# the free-text columns users have hit with 4-byte characters (emoji),
# each a production 500. TEXT columns sit in no index, so the
# index-key-length concerns that defer #4625 don't apply; the one
# converted indexed column (comments.target_type, varchar(30) = 120
# bytes as utf8mb4) is far under InnoDB's key limit. The connection
# already runs utf8mb4, so the columns are the only barrier.
#
# All of comments' string columns convert together: Comment.pattern
# CONCATs summary with comment, and on MySQL 8 a CONCAT mixing utf8mb3
# and utf8mb4 columns resolves to utf8mb4_bin with no derivation, so
# the pattern-search LIKE fails with "Illegal mix of collations"
# (caught by CI; MySQL 9's coercion rules tolerate the mix, so it did
# not reproduce locally). users.notes has no such partner -- the user
# pattern search reads login + name only.
#
# utf8mb4_0900_ai_ci matches every existing utf8mb4 table in the
# schema (the MySQL 8+ default), so the eventual #4625 conversion
# normalizes on a single collation.
class ConvertCommentAndUserNotesToUtf8mb4 < ActiveRecord::Migration[7.2]
  def up
    change_column(:comments, :comment, :text,
                  collation: "utf8mb4_0900_ai_ci")
    change_column(:comments, :summary, :string,
                  limit: 100, collation: "utf8mb4_0900_ai_ci")
    change_column(:comments, :target_type, :string,
                  limit: 30, collation: "utf8mb4_0900_ai_ci")
    change_column(:users, :notes, :text,
                  collation: "utf8mb4_0900_ai_ci")
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
