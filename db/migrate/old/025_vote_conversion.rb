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

    for match in Observation.find_by_sql %(
        SELECT o.id
        FROM observations o, namings n
        WHERE o.id = n.observation_id and o.name_id != n.name_id
      )
      o = Observation.find(match.id)
      print "Updating observation ##{o.id}\n"
      o.calc_consensus
    end
  end
end
