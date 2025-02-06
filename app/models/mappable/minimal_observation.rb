# frozen_string_literal: true

module Mappable
  class MinimalObservation
    include ActiveModel::Model
    include ActiveModel::Attributes
    include ActiveModel::Validations::Callbacks
    include Mappable::BoxMethods

    attribute :id, :integer
    attribute :lat, :float
    attribute :lng, :float
    attribute :location_id, :integer

    validates :lat, numericality: { in: -90..90 }
    validates :lng, numericality: { in: -180..180 }

    before_validation :determine_location_id_if_instance

    def location
      @location ||= location_id.nil? ? nil : ::Location.find(@location_id)
    end

    def location=(loc)
      if loc
        @location = loc
        self.location_id = loc.id
      else
        @location = nil
        self.location_id = nil
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

    private

    def determine_location_id_if_instance
      case location_id
      when Integer, String
        self.location_id = location_id.to_i
      when Location
        @location = location_id
        self.location_id = location_id.id
      end
    end
  end
end
