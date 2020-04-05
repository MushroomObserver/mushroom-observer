class DeanonymizeImageVotes < ActiveRecord::Migration[4.2]
  def self.up
    values = []
    for image_id, votes in Image.connection.select_rows %(
        SELECT id, votes FROM images WHERE votes IS NOT null AND votes != ""
      )
      hash = Hash[*votes.split(" ")]
      for user_id, value in hash
        values << [image_id, user_id, value]
      end
    end

    create_table :image_votes, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: true do |t|
      t.column "image_id",  :integer, null: false
      t.column "user_id",   :integer, null: false
      t.column "value",     :integer, null: false
      t.column "anonymous", :boolean, null: false, default: false
    end

    Image.connection.insert %(
      INSERT INTO image_votes (image_id, user_id, value, anonymous)
      VALUES (#{values.map { |i, u, v| "#{i},#{u},#{v},TRUE" }.join("),(")})
    )
  end

  def self.down
    drop_table :image_votes
  end
end
