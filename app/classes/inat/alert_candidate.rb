# frozen_string_literal: true

class Inat
  # One observation as the alert poll sees it (#5416): the few fields
  # the cycle reads out of an iNat API result, named.
  #
  # `Inat::Obs` is the importer's view of an observation and knows how
  # to turn one into MO records. Nothing is imported here, so this
  # reads the handful of fields a match and a message need.
  class AlertCandidate
    def initialize(result)
      @result = result || {}
    end

    def id
      @result["id"].to_s
    end

    def url
      "#{Inat::Constants::SITE}/observations/#{id}"
    end

    def observed_on
      value = @result["observed_on"]
      return nil if value.blank?

      Date.parse(value.to_s)
    rescue Date::Error
      nil
    end

    def lat
      coordinates&.last
    end

    def lng
      coordinates&.first
    end

    # iNat withdraws an identification rather than deleting it, so a
    # withdrawn one comes back with `current` false. Only what the
    # observation says now can alert.
    def current_identifications
      Array(@result["identifications"]).
        select { |ident| ident["current"] }.
        filter_map { |ident| identification(ident) }
    end

    def to_h
      { id: id, observed_on: observed_on }
    end

    private

    def identification(ident)
      taxon = ident["taxon"] || {}
      return nil if taxon["id"].blank?

      { id: ident["id"], taxon_id: taxon["id"], name: taxon["name"].to_s }
    end

    # iNat writes a point as "lat,lng" in `location`, and withholds it
    # for an obscured or private observation.
    def coordinates
      return @coordinates if defined?(@coordinates)

      lat, lng = @result["location"].to_s.split(",")
      @coordinates = lng.blank? ? nil : [lng.to_f, lat.to_f]
    end
  end
end
