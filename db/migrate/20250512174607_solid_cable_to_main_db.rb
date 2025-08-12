# frozen_string_literal: true

class SolidCableToMainDb < ActiveRecord::Migration[7.2]
  def change
    create_table("solid_cable_messages", charset: "utf8mb4",
                                         collation: "utf8mb4_0900_ai_ci",
                                         force: :cascade) do |t|
      t.binary("channel", limit: 1024, null: false)
      t.binary("payload", size: :long, null: false)
      t.datetime("created_at", null: false)
      t.bigint("channel_hash", null: false)
      t.index(["channel"], name: "index_solid_cable_messages_on_channel")
      t.index(["channel_hash"],
              name: "index_solid_cable_messages_on_channel_hash")
      t.index(["created_at"], name: "index_solid_cable_messages_on_created_at")
    end
  end
end
