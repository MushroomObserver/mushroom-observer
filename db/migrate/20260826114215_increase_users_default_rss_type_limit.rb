# frozen_string_literal: true

# Widen users.default_rss_type from 40 to 255 chars. It stores the
# selected RssLog type tags space-joined (e.g. "observation name
# location"); even a subset of the 7 tags can exceed 40 chars
# (5 of 7, worst case), raising Data too long instead of saving.
class IncreaseUsersDefaultRssTypeLimit < ActiveRecord::Migration[7.2]
  def up
    change_column(:users, :default_rss_type, :string, limit: 255)
  end

  def down
    change_column(:users, :default_rss_type, :string, limit: 40)
  end
end
