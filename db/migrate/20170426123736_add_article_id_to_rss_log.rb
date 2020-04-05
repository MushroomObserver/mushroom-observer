class AddArticleIdToRssLog < ActiveRecord::Migration[4.2]
  def change
    add_column :rss_logs, :article_id, :integer
  end
end
