class CreateArticles < ActiveRecord::Migration
  def change
    create_table :articles do |t|
      t.string  :name
      t.text    :body
      t.integer :user_id
      t.integer :rss_log_id

      t.timestamps null: false
    end
  end
end
