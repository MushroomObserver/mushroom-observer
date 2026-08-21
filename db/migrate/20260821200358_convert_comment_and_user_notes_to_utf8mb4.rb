# frozen_string_literal: true

# First incremental step toward issue #4625 (full utf8mb4 conversion):
# the two free-text columns users have hit with 4-byte characters
# (emoji), each a production 500. TEXT columns sit in no index, so the
# index-key-length concerns that defer #4625 don't apply here. The
# connection already runs utf8mb4, so these columns are the only barrier.
class ConvertCommentAndUserNotesToUtf8mb4 < ActiveRecord::Migration[7.2]
  # utf8mb4_0900_ai_ci matches every existing utf8mb4 table in the
  # schema (the MySQL 8+ default), so the eventual #4625 conversion
  # normalizes on a single collation.
  def up
    change_column(:comments, :comment, :text,
                  collation: "utf8mb4_0900_ai_ci")
    change_column(:users, :notes, :text,
                  collation: "utf8mb4_0900_ai_ci")
  end

  def down
    change_column(:comments, :comment, :text,
                  collation: "utf8mb3_general_ci")
    change_column(:users, :notes, :text,
                  collation: "utf8mb3_general_ci")
  end
end
