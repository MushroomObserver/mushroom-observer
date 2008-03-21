class TweakedAverageVotes < ActiveRecord::Migration
  def self.up
    add_column :observations, "vote_cache", :float, :default => 0
    add_column :namings, "vote_cache", :float, :default => 0

    Naming.connection.update %(
      UPDATE namings
      SET vote_cache=(
        SELECT sum(votes.value)/(count(votes.value)+1)
        FROM votes
        WHERE namings.id = votes.naming_id
      )
    )

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
    remove_column :observations, "vote_cache"
    remove_column :namings, "vote_cache"

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
