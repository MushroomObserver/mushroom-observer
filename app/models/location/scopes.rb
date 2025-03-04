# frozen_string_literal: true

module Location::Scopes
  # This is using Concern so we can define the scopes in this included module.
  extend ActiveSupport::Concern

  # NOTE: To improve Coveralls display, avoid one-line stabby lambda scopes.
  # Two line stabby lambdas are OK, it's just the declaration line that will
  # always show as covered.
  included do # rubocop:disable Metrics/BlockLength
    # default ordering for index queries
    scope :index_order,
          -> { order(name: :asc, id: :desc) }

    scope :in_regions, lambda { |place_names|
      place_names = [place_names].flatten
      if place_names.length > 1
        starting = in_region(place_names.shift)
        place_names.reduce(starting) do |result, place_name|
          result.or(Location.in_region(place_name))
        end
      else
        in_region(place_names.first)
      end
    }
    scope :in_region, lambda { |place_name|
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

    scope :has_notes, lambda { |bool = true|
      if bool.to_s.to_boolean == true
        where(Location[:notes].not_blank)
      else
        has_no_notes
      end
    }
    scope :has_no_notes,
          -> { where(Location[:notes].blank) }
    scope :notes_has,
          ->(phrase) { search_columns(Location[:notes], phrase) }

    scope :search_content,
          ->(phrase) { search_columns(Location.searchable_columns, phrase) }
    # Location[:name] + descriptions, Observation[:notes] + comments
    # Does not search location notes or location comments.
    scope :advanced_search, lambda { |phrase|
      ids = Location.name_has(phrase).map(&:id)
      ids += Location.description_has(phrase).map(&:id)
      ids += Observation.advanced_search(phrase).
             includes(:location).map(&:location).flatten.uniq
      where(id: ids).distinct
    }
    # Does not search location notes, observation notes or comments on either.
    # We do not yet support location comment queries.
    scope :pattern, lambda { |phrase|
      cols = Location[:name] + LocationDescription.searchable_columns
      joins_default_descriptions.search_columns(cols, phrase)
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

    scope :has_description, lambda { |bool = true|
      if bool.to_s.to_boolean == true
        where.not(description_id: nil)
      else
        has_no_description
      end
    }
    scope :has_no_description,
          -> { where(description_id: nil) }
    scope :description_has, lambda { |phrase|
      joins(:descriptions).
        merge(LocationDescription.search_content(phrase)).distinct
    }
    scope :has_description_created_by, lambda { |user|
      joins(:descriptions).
        merge(LocationDescription.where(user: user)).distinct
    }
    scope :has_description_reviewed_by, lambda { |user|
      joins(:descriptions).
        merge(LocationDescription.where(reviewer: user)).distinct
    }
    scope :has_description_of_type, lambda { |source|
      # Check that it's a valid source type (string enum value)
      return none if Description::ALL_SOURCE_TYPES.exclude?(source)

      joins(:descriptions).
        merge(LocationDescription.where(source_type: source)).distinct
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

      where((Location[:south] >= box.south).and(Location[:north] <= box.north).
            # Location[:west] between w & 180 OR between 180 and e
            and((Location[:west] >= box.west).or(Location[:west] <= box.east)).
            and((Location[:east] >= box.west).or(Location[:east] <= box.east)))
    }
    # mostly a helper for in_box
    scope :in_box_regular, lambda { |**args|
      box = Mappable::Box.new(**args)
      return none unless box.valid?

      where((Location[:south] >= box.south).and(Location[:north] <= box.north).
            and(Location[:west] >= box.west).and(Location[:east] <= box.east).
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
      where((Location[:south]).lteq(lat).and((Location[:north]).gteq(lat)).
            and(Location[:west].lteq(lng).and(Location[:east].gteq(lng)).
                or(Location[:west].gteq(lng).and(Location[:east].lteq(lng)))))
    }
    # Use named parameters (lat:, lng:), any order
    scope :with_minimum_bounding_box_containing_point, lambda { |**args|
      args => {lat:, lng:}
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
    scope :has_observations,
          -> { joins(:observations).distinct }

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
