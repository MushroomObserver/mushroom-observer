class RecalcConsensus < ActiveRecord::Migration
  def self.up
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

  def self.down
  end
end
