class VoteConversion < ActiveRecord::Migration
  def self.up
    Vote.connection.update("update votes set value = (value - 50)/10")
    Vote.connection.update("update votes set value = (value + 1)/2 where value > 0")
    Vote.connection.update("update votes set value = (value - 1)/2 where value < 0")
  end

  def self.down
    Vote.connection.update("update votes set value = value*2 + 1 where value < 0")
    Vote.connection.update("update votes set value = value*2 - 1 where value > 0")
    Vote.connection.update("update votes set value = value*10 + 50")
  end
end
