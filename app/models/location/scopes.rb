# frozen_string_literal: true

module Location::Scopes
  # This is using Concern so we can define the scopes in this included module.
  extend ActiveSupport::Concern

  # NOTE: To improve Coveralls display, avoid one-line stabby lambda scopes.
  # Two line stabby lambdas are OK, it's just the declaration line that will
  # always show as covered.
  included do
    # default ordering for index queries
    scope :order_by_default,
          -> { order_by(::Query::Locations.default_order) }

    # This should really be regions/region, but changing user prefs/filters and
    # autocompleters is very involved, requires migration and script.
    scope :region, lambda { |place_names|
      place_names = [place_names].flatten
      place_names.map! { |val| one_region(val) }
      or_clause(*place_names).distinct
    }
    scope :one_region, lambda { |place_name|
      region = Location.reverse_name_if_necessary(place_name)

      if understood_continent?(region)
        countries = countries_in_continent(region)
        where(Location[:name] =~ ", (#{countries.join("|")})$")
      else
        where(Location[:name].matches("%#{region}"))
      end
    }
    scope :name_has,
          ->(phrase) { search_columns(Location[:name], phrase) }
    # Used by Lookup::Locations
    # to match the most general area containing all search terms
    scope :shortest_names_with, lambda { |pattern|
      return none if pattern.blank?

      name_has(pattern).order(Location[:name].length)
    }

    scope :has_notes,
          ->(bool = true) { not_blank_condition(Location[:notes], bool:) }
    scope :notes_has,
          ->(phrase) { search_columns(Location[:notes], phrase) }

    # This is a convenience for lookup by text name. Used by `observation_query`
    scope :locations, lambda { |locations|
      location_ids = Lookup::Locations.new(locations).ids
      where(id: location_ids).distinct
    }

    # Does not search location notes, observation notes or comments on either.
    # We do not yet support location comment queries.
    scope :pattern, lambda { |phrase|
      cols = Location[:name] + LocationDescription.searchable_columns
      joins_default_descriptions.search_columns(cols, phrase)
    }
    scope :regexp, lambda { |phrase|
      where(Location[:name] =~ phrase.to_s.strip.squeeze(" ")).distinct
    }
    # https://stackoverflow.com/a/77064711/3357635
    # AR's assumed join condition is
    #   `Location[:id].eq(LocationDescription[:location_id])`
    # but we want the converse. It is a bit complicated to write a left outer
    # join in AR that joins on a non-standard condition, so here it is:
    scope :joins_default_descriptions, lambda {
      joins(
        Location.arel_table.
        join(LocationDescription.arel_table, Arel::Nodes::OuterJoin).
        on(Location[:description_id].eq(LocationDescription[:id])).join_sources
      )
    }

    # Query currently ignores "false" in both these cases
    scope :has_descriptions, lambda { |bool = true|
      return all unless bool

      presence_condition(Location[:description_id], bool:)
    }
    scope :has_observations, lambda { |bool = true|
      return all unless bool

      joins(:observations).distinct
    }

    # Returns locations whose bounding box is entirely within the given box.
    # Pass kwargs (:north, :south, :east, :west), any order
    scope :in_box, lambda { |**args|
      box = Mappable::Box.new(**args)
      return none unless box.valid?

      if box.straddles_180_deg?
        in_box_over_dateline(**args)
      else
        in_box_regular(**args)
      end
    }
    # mostly a helper for in_box
    scope :in_box_over_dateline, lambda { |**args|
      box = Mappable::Box.new(**args)
      return none unless box.valid?

      e = MO.box_epsilon
      where((Location[:south] >= box.south - e).
            and(Location[:north] <= box.north + e).
            # Location[:west] between w & 180 OR between 180 and e
            and((Location[:west] >= box.west - e).
                or(Location[:west] <= box.east + e)).
            and((Location[:east] >= box.west - e).
                or(Location[:east] <= box.east + e)))
    }
    # mostly a helper for in_box
    scope :in_box_regular, lambda { |**args|
      box = Mappable::Box.new(**args)
      return none unless box.valid?

      e = MO.box_epsilon
      where((Location[:south] >= box.south - e).
            and(Location[:north] <= box.north + e).
            and(Location[:west] >= box.west - e).
            and(Location[:east] <= box.east + e).
            and(Location[:west] <= Location[:east]))
    }
    # Pass kwargs (:north, :south, :east, :west), any order
    scope :not_in_box, lambda { |**args|
      box = Mappable::Box.new(**args)
      return none unless box.valid?

      in_box(**args).invert_where
    }
    # Use named parameters (lat:, lng:), any order
    scope :contains_point, lambda { |**args|
      args => { lat:, lng: }
      where(Location[:south].lteq(lat).and(Location[:north].gteq(lat)).
            and(Location[:west].lteq(lng).and(Location[:east].gteq(lng)).
                or(Location[:west].gteq(lng).and(Location[:east].lteq(lng)))))
    }
    # Use named parameters (lat:, lng:), any order
    scope :with_minimum_bounding_box_containing_point, lambda { |**args|
      args => { lat:, lng: }
      containers = contains_point(lat: lat, lng: lng)
      # prevents returning all containers if contaimers empty
      return none if containers.empty?

      containers.min_by(&:box_area)
    }
    # Use named parameters, north:, south:, east:, west:
    #
    #   w/e    | Location     | Location contains w/e
    #   ______ | ____________ | ______________________
    #   w <= e | west <= east | west <= w && e <= east
    #   w <= e | west > east  | west <= w || e <= east
    #   w > e  | west <= east | none
    #   w > e  | west > east  | west <= w && e <= east
    #
    scope :contains_box, lambda { |**args|
      args => { north:, south:, east:, west: }

      if west <= east # w / e don't straddle 180
        where(Location[:south].lteq(south).and(Location[:north].gteq(north)).
              # Location doesn't straddle 180
              and(Location[:west].lteq(Location[:east]).
              and(Location[:west] <= west).and(Location[:east] >= east).
              # Location straddles 180
              or(Location[:west].gt(Location[:east]).
                and((Location[:west] <= west).or(Location[:east] >= east)))))
      else # Location straddles 180
        where(Location[:south].lteq(south).and(Location[:north].gteq(north)).
              # Location 100% wrap; necessarily straddles w/e
              and(Location[:west].eq(Location[:east] - 360)).
              # Location < 100% wrap-around
              or(Location[:west].gt(Location[:east]).
                and(Location[:west] <= west).and(Location[:east] >= east)))
      end
    }

    scope :description_query, lambda { |hash|
      joins(:descriptions).subquery(:LocationDescription, hash)
    }
    # Filter :locations and :region directly in the outer Location query,
    # not via observations.
    scope :observation_query, lambda { |hash|
      scope = all
      locations = hash.delete(:locations)
      scope = scope.locations(locations) if locations.present?
      regions = hash.delete(:region)
      scope = scope.region(regions) if regions.present?
      scope.joins(:observations).subquery(:Observation, hash)
    }

    scope :show_includes, lambda {
      strict_loading.includes(
        { comments: :user },
        { description: { comments: :user } },
        { descriptions: [:authors, :editors] },
        :interests,
        :observations,
        :rss_log,
        :versions
      )
    }
  end

  module ClassMethods
    # class methods here, `self` included
  end
end
