class Latin1ToUtf8 < ActiveRecord::Migration[7.1]
  def up
    Article.connection.
      execute("ALTER TABLE articles CONVERT TO CHARACTER SET utf8mb4;")
    Sequence.connection.
      execute("ALTER TABLE sequences CONVERT TO CHARACTER SET utf8mb4;")
  end

  def down
    Article.connection.
      execute("ALTER TABLE articles CONVERT TO CHARACTER SET latin1;")
    Sequence.connection.
      execute("ALTER TABLE sequences CONVERT TO CHARACTER SET latin1;")
  end
end
