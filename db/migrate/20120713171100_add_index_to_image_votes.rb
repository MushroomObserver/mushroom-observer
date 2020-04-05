# encoding: utf-8

class AddIndexToImageVotes < ActiveRecord::Migration[4.2]
  def self.up
    # This improves the following query by orders of magnitude:
    #   Query.lookup(:Observation, :by_user, :user => 252, :by => owners_thumbnail_quality):
    #     SELECT DISTINCT observations.id
    #     FROM `observations`
    #     JOIN `images` ON observations.thumb_image_id = images.id
    #     JOIN `image_votes` ON image_votes.image_id = images.id
    #     WHERE observations.user_id = '252'
    #       AND image_votes.user_id = observations.user_id
    #     ORDER BY image_votes.value DESC;
    add_index :image_votes, :image_id
  end

  def self.down
    remove_index :image_votes, :image_id
  end
end
