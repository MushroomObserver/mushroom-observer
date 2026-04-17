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
    attribute :location, Location
    # Additional attributes used by map popups (issue #4131). They are
    # optional — callers that don't set them leave the popup without the
    # corresponding field. All map to columns on `observations`.
    attribute :name_id, :integer
    attribute :text_name, :string
    # Textile-formatted display name from the Name model — bold italic
    # for non-deprecated names, italic-only for deprecated. Safe to pass
    # through `.t` to produce the popup-ready HTML.
    attribute :display_name, :string
    attribute :when, :date
    attribute :vote_cache, :float
    attribute :thumb_image_id, :integer

    validates :lat, numericality: { in: -90..90 }
    validates :lng, numericality: { in: -180..180 }
    validate :location_must_be_a_location

    def location
      @location ||= location_id.nil? ? nil : ::Location.find(location_id)
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

    def location_must_be_a_location
      return unless location.present? && !location.is_a?(Location)

      errors.add(:location, "must be a Location object")
    end
  end
end
