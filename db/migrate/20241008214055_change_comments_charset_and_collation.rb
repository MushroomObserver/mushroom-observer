class ChangeCommentsCharsetAndCollation < ActiveRecord::Migration[7.1]
  def up
    execute <<-SQL
      ALTER TABLE comments CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
    SQL
  end

  def down
    execute <<-SQL
      ALTER TABLE comments CONVERT TO CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci;
    SQL
  end
end
