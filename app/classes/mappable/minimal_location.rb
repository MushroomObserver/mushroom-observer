# frozen_string_literal: true

module Mappable
  class MinimalLocation
    attr_accessor :id, :name, :north, :south, :east, :west

    def initialize(id, name, north, south, east, west)
      @id    = id
      @name  = name
      @north = north
      @south = south
      @east  = east
      @west  = west
    end

    include Mappable::BoxMethods

    def display_name
      if ::User.current_location_format == "scientific"
        ::Location.reverse_name(name)
      else
        name
      end
    end
  end
end
