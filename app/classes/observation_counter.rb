# frozen_string_literal: true

# Bulk per-owner Observation counts for an index page's count badge
# -- one query instead of one COUNT per row. `owners` is an
# ActiveRecord::Relation or Array of any model with a
# `has_many :observations` association, direct (Name, Location) or
# through a join model (SpeciesList, Project) -- `.joins(:observations)`
# builds the right join either way.
class ObservationCounter
  def self.counts_for(owners)
    owners = owners.to_a
    return {} if owners.empty?

    owners.first.class.where(id: owners.map(&:id)).
      joins(:observations).group(:id).count
  end
end
