# frozen_string_literal: true

module Mappable
  class MinimalObservation
    include ActiveModel::Model
    include ActiveModel::Attributes
    include Mappable::BoxMethods

    attribute :id, :integer
    attribute :lat, :float
    attribute :lng, :float
    attribute :location_id, :integer
    attribute :location, :array

    validates :lat, numericality: { in: -90..90 }
    validates :lng, numericality: { in: -180..180 }
    validate :location_must_be_a_location_array

    # def location
    #   @location ||= location_id.nil? ? nil : ::Location.find(location_id)
    # end

    # def location=(loc)
    #   if loc
    #     @location = loc
    #     self.location_id = loc.id
    #   else
    #     @location = nil
    #     self.location_id = nil
    #   end
    # end

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

    def location_must_be_a_location_array
      return if location.blank?

      location = [location] unless location.is_a?(Array)

      location.each do |loc|
        unless loc.is_a?(Location)
          errors.add(:location, "must be a Location object")
        end
      end
    end
  end
end
