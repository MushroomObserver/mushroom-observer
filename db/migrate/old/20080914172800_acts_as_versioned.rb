require 'name'
require 'location'

class ActsAsVersioned < ActiveRecord::Migration
  def self.up
    remove_column :past_names, :created
    remove_column :past_locations, :created
    add_column :past_names, :reviewer_id, :integer, :default => nil, :null => true
    add_column :past_names, :last_review, :datetime

    pns = {}
    for pn in Name::PastName.find(:all)
      pns["#{pn.name_id} #{pn.version}"] = true
    end

    for n in Name.find(:all)
      Name::PastName.new(
        :name_id          => n.id,
        :modified         => n.modified,
        :user_id          => n.user_id,
        :version          => n.version,
        :text_name        => n.text_name,
        :author           => n.author,
        :display_name     => n.display_name,
        :observation_name => n.observation_name,
        :search_name      => n.search_name,
        :notes            => n.notes,
        :deprecated       => n.deprecated,
        :citation         => n.citation,
        :rank             => n.rank
      ).save if !pns["#{n.id} #{n.version}"]
    end

    pls = {}
    for pl in Location::PastLocation.find(:all)
      pls["#{pl.location_id} #{pl.version}"] = true
    end

    for l in Location.find(:all)
      Location::PastLocation.new(
        :location_id  => l.id,
        :modified     => l.modified,
        :user_id      => l.user_id,
        :version      => l.version,
        :display_name => l.display_name,
        :notes        => l.notes,
        :north        => l.north,
        :south        => l.south,
        :west         => l.west,
        :east         => l.east,
        :high         => l.high,
        :low          => l.low
      ).save if !pls["#{l.id} #{l.version}"]
    end
  end

  def self.down
  end
end
