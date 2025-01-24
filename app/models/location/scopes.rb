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

    scope :in_region, lambda { |place_name|
      place_name = Location.reverse_name_if_necessary(place_name)
      where(Location[:name].matches("%#{place_name}"))
    }
    scope :name_contains,
          ->(phrase) { search_columns(Location[:name], phrase) }
    scope :with_notes,
          -> { where(Location[:notes].not_blank) }
    scope :without_notes,
          -> { where(Location[:notes].blank) }
    scope :notes_contain,
          ->(phrase) { search_columns(Location[:notes], phrase) }
    scope :search_content,
          ->(phrase) { search_columns(Location.searchable_columns, phrase) }
    # More comprehensive search of Location fields, plus descriptions/comments.
    scope :search_content_and_associations, lambda { |phrase|
      fields = Location.search_content(phrase).map(&:id)
      comments = Location.comments_contain(phrase).map(&:id)
      descs = Location.description_contains(phrase).map(&:id)
      where(id: fields + comments + descs).distinct
    }

    scope :with_comments,
          -> { joins(:comments).distinct }
    scope :without_comments,
          -> { where.not(id: with_comments) }
    scope :comments_contain,
          ->(phrase) { joins(:comments).merge(Comment.search_content(phrase)) }

    scope :with_description,
          -> { where.not(description_id: nil) }
    scope :without_description,
          -> { where(description_id: nil) }
    scope :description_contains, lambda { |phrase|
      joins(:descriptions).
        merge(LocationDescription.search_content(phrase)).distinct
    }
    scope :with_description_created_by, lambda { |user|
      joins(:descriptions).merge(LocationDescription.where(user: user))
    }
    scope :with_description_reviewed_by, lambda { |user|
      joins(:descriptions).merge(LocationDescription.where(reviewer: user))
    }
    scope :with_description_of_type, lambda { |source|
      # Check that it's a valid source type (string enum value)
      return none if Description::ALL_SOURCE_TYPES.exclude?(source)

      joins(:descriptions).merge(LocationDescription.where(source_type: source))
    }

    # Returns locations whose bounding box is entirely within the given box.
    # Pass kwargs (:north, :south, :east, :west), any order
    scope :in_box, lambda { |**args|
      box = Mappable::Box.new(**args)
      return none unless box.valid?

      if box.straddles_180_deg?
        in_box_straddling_dateline(**args)
      else
        in_box_regular(**args)
      end
    }
    # mostly a helper for in_box
    scope :in_box_straddling_dateline, lambda { |**args|
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
    scope :with_observations,
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
