# frozen_string_literal: true

module Mappable
  class MinimalObservation
    attr_accessor :id, :lat, :lng, :location_id

    def initialize(id, lat, lng, location_or_id)
      @id = id
      @lat = lat
      @lng = lng
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

    def lat_lng_dubious?
      lat && location && !location.lat_lng_close?(lat, lng)
    end
  end
end
