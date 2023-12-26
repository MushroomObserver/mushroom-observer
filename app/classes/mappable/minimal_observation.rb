# frozen_string_literal: true

module Mappable
  class MinimalObservation
    attr_accessor :id, :lat, :lng, :location_id # , :long

    # The observation has the attr `long`, but the MapSet needs to provide `lng`
    def initialize(id, lat, long, location_or_id)
      @id = id
      @lat = lat
      @lng = long
      # @long = long # Not sure if anyone needs `long`
      case location_or_id
      when Integer, String
        @location_id = location_or_id.to_i
      when Location
        @location = location_or_id
        @location_id = location_or_id.id
      end
    end

    def location
      @location ||= @location_id.nil? ? nil : ::Location.find(@location_id)
    end

    def location=(loc)
      if loc
        @location = loc
        @location_id = loc.id
      else
        @location = nil
        @location_id = nil
      end
    end

    def location?
      false
    end

    def observation?
      true
    end

    def lat_long_dubious?
      lat && location && !location.lat_long_close?(lat, lng)
    end
  end
end
