# encoding: utf-8

require "user"
class User
  def self.get_old_auth_code(password)
    old_auth_code(password)
  end
end

class AddAuthCodeToUsers < ActiveRecord::Migration[4.2]
  def self.up
    begin
      add_column(:users, :auth_code, :string, limit: 40)
    rescue
      nil
    end
    fill_in_auth_codes
  end

  def self.down
    remove_column :users, :auth_code
  end

  def self.fill_in_auth_codes
    data = []
    for id, password in User.connection.select_rows %(
      SELECT id, password FROM users
    )
      data[id.to_i] = User.get_old_auth_code(password)
    end
    vals = data.map { |v| User.connection.quote(v.to_s) }.join(",")
    User.connection.update %(
      UPDATE users SET auth_code = ELT(id+1, #{vals})
    )
  end
end
