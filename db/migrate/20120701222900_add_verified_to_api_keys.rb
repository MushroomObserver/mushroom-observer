# encoding: utf-8

class AddVerifiedToApiKeys < ActiveRecord::Migration[4.2]
  def self.up
    add_column(:api_keys, :verified, :datetime)
    ApiKey.connection.update %(
      UPDATE api_keys SET verified = NOW()
    )
  end

  def self.down
    remove_column :api_keys, :verified
  end
end
