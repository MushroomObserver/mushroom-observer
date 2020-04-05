# encoding: utf-8
class ImageVotes < ActiveRecord::Migration[4.2]
  def self.up
    add_column :images, :votes, :text
    add_column :images, :vote_cache, :float
    Image.connection.update %(
      UPDATE images
      SET votes = CONCAT(reviewer_id, " ", IF(quality = "low", 1, IF(quality = "medium", 2, 3))),
          vote_cache = IF(quality = "low", 1, IF(quality = "medium", 2, 3))
      WHERE quality != "unreviewed" AND reviewer_id IS NOT NULL
    )
    remove_column :images, :quality
    remove_column :images, :reviewer_id
  end

  def self.down
    remove_column :images, :votes
    remove_column :images, :vote_cache
    add_column :images, :quality, :enum, limit: [:unreviewed, :low, :medium, :high], default: :unreviewed, null: false
    add_column :images, :reviewer_id, :integer
  end
end
