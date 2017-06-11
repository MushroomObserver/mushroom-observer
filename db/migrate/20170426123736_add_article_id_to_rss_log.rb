class AddArticleIdToRssLog < ActiveRecord::Migration
  def change
    add_column :rss_logs, :article_id, :integer
  end
end
