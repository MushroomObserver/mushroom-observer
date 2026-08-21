# frozen_string_literal: true

# First incremental step toward issue #4625 (full utf8mb4 conversion):
# the two free-text columns users have hit with 4-byte characters
# (emoji), each a production 500. TEXT columns sit in no index, so the
# index-key-length concerns that defer #4625 don't apply here. The
# connection already runs utf8mb4, so these columns are the only barrier.
class ConvertCommentAndUserNotesToUtf8mb4 < ActiveRecord::Migration[7.2]
  def up
    change_column(:comments, :comment, :text,
                  collation: "utf8mb4_general_ci")
    change_column(:users, :notes, :text,
                  collation: "utf8mb4_general_ci")
  end

  def down
    change_column(:comments, :comment, :text,
                  collation: "utf8mb3_general_ci")
    change_column(:users, :notes, :text,
                  collation: "utf8mb3_general_ci")
  end
end
