# frozen_string_literal: true

class Inat
  # Classifies an MO observation against its cached iNat counterpart for
  # reflection resolution (#4585). The image-set relation is the primary
  # signal — computed on perceptual-hash (dHash) identity so it survives the
  # resolution difference between MO originals and iNat renditions — and
  # drives the #4585 case number. Field diffs are secondary, reported for
  # distribution analysis so the deferred per-field rules can be specified
  # from real data.
  #
  # Inputs are pre-resolved so the class stays pure and testable: the caller
  # supplies the two dHash lists (nil entries — un-hashable images — count as
  # unmatched) plus the MO observation and the InatObsExtract for the field
  # comparison.
  class ReflectionComparator
    # Max Hamming distance for two dHashes to count as the same photo. 0 is
    # identical; a few bits absorb resolution/recompression. Provisional —
    # the point of the first report is to pick this from the distribution.
    SAME_PHOTO_MAX_DISTANCE = 8

    # iNat obscures coordinates of sensitive taxa; the public point can sit
    # anywhere within public_accuracy meters of the truth. Never call a
    # difference inside that radius a location edit. Fallback radius (meters)
    # when an obscured obs reports no accuracy.
    DEFAULT_OBSCURED_RADIUS = 30_000

    # Meters within which two unobscured points count as the same place —
    # absorbs coordinate precision/rounding between MO and iNat. Provisional;
    # location_meters is reported raw so this can be tuned from the data.
    BASE_MATCH_RADIUS = 1_000

    # Field statuses are tri-state (:match / :differ / :na) so "nothing to
    # compare" stays distinct from "compared and differs" in the report.
    Result = Struct.new(
      :image_relation, :case_number, :mo_image_count, :inat_photo_count,
      :matched_image_count, :date_status, :location_status, :taxon_status,
      :location_meters, :mo_coord_source,
      keyword_init: true
    )

    def initialize(mo_obs:, extract:, mo_hashes:, inat_hashes:)
      @obs = mo_obs
      @extract = extract
      @mo_hashes = mo_hashes.compact
      @inat_hashes = inat_hashes.compact
    end

    def compare
      relation = image_relation
      Result.new(
        image_relation: relation,
        case_number: case_number_for(relation),
        mo_image_count: @mo_hashes.size,
        inat_photo_count: @inat_hashes.size,
        matched_image_count: matched_count,
        date_status: date_status,
        location_status: location_status,
        taxon_status: taxon_status,
        location_meters: location_meters,
        mo_coord_source: mo_coord_source
      )
    end

    # :identical | :mo_subset_of_inat | :inat_subset_of_mo | :overlapping |
    # :disjoint | :no_images
    def image_relation
      return :no_images if @mo_hashes.empty? && @inat_hashes.empty?

      relation_for(matched_count,
                   @mo_hashes.size - matched_count,
                   @inat_hashes.size - matched_count)
    end

    private

    def relation_for(matched, extra_mo, extra_inat)
      return :identical if extra_mo.zero? && extra_inat.zero?
      return :mo_subset_of_inat if extra_mo.zero?
      return :inat_subset_of_mo if extra_inat.zero?
      # Both sides have unmatched images from here.
      return :disjoint if matched.zero?

      :overlapping
    end

    # Greedy bipartite match: each MO image claims at most one still-unclaimed
    # iNat photo within threshold. Photo counts are tiny, so greedy is fine.
    def matched_count
      return @matched_count if defined?(@matched_count)

      used = Array.new(@inat_hashes.size, false)
      @matched_count = @mo_hashes.count do |mo|
        idx = @inat_hashes.each_index.find do |i|
          !used[i] && Image::Dhash.distance(mo, @inat_hashes[i]) <=
            SAME_PHOTO_MAX_DISTANCE
        end
        used[idx] = true if idx
        idx
      end
    end

    # #4585 cases: 1 identical/MO⊆iNat, 2 iNat⊊MO, 3 disjoint, 4 overlapping.
    def case_number_for(relation)
      case relation
      when :identical, :mo_subset_of_inat then 1
      when :inat_subset_of_mo then 2
      when :disjoint then 3
      when :overlapping then 4
      end
    end

    def date_status
      return :na unless @obs.when && @extract.observed_on

      @obs.when == @extract.observed_on ? :match : :differ
    end

    # MO's effective coordinates: the observation's own GPS point when set,
    # else its named Location's centroid (many MO obs — including imports —
    # carry only a Location, no point). Tracked so the report can tell point
    # comparisons from coarser centroid ones.
    def mo_lat = @obs.lat || @obs.location_lat
    def mo_lng = @obs.lng || @obs.location_lng

    def mo_coord_source
      return :point if @obs.lat && @obs.lng
      return :location if @obs.location_lat && @obs.location_lng

      :none
    end

    # Great-circle meters between the MO and iNat points, or nil if either
    # side lacks coordinates. Reported raw so the match threshold can be
    # tuned from the distribution.
    def location_meters
      return @location_meters if defined?(@location_meters)
      return @location_meters = nil unless mo_lat && mo_lng &&
                                           @extract.lat && @extract.lng

      @location_meters =
        haversine_m(mo_lat, mo_lng, @extract.lat, @extract.lng).round
    end

    # Obscured iNat coords match if the MO point is within the obscuring
    # radius (not a real edit); otherwise within BASE_MATCH_RADIUS.
    def location_status
      meters = location_meters
      return :na if meters.nil?

      meters <= tolerance_meters ? :match : :differ
    end

    def tolerance_meters
      return BASE_MATCH_RADIUS unless @extract.obscured

      if @extract.public_accuracy&.positive?
        @extract.public_accuracy
      else
        DEFAULT_OBSCURED_RADIUS
      end
    end

    def taxon_status
      return :na if @extract.taxon_name.blank? || @obs.text_name.blank?

      @extract.taxon_name.casecmp?(@obs.text_name) ? :match : :differ
    end

    def haversine_m(lat1, lng1, lat2, lng2)
      rad = Math::PI / 180
      a = haversine_a((lat2 - lat1) * rad, (lng2 - lng1) * rad,
                      lat1 * rad, lat2 * rad)
      6_371_000 * 2 * Math.asin(Math.sqrt(a))
    end

    def haversine_a(dlat, dlng, lat1_rad, lat2_rad)
      (Math.sin(dlat / 2)**2) +
        (Math.cos(lat1_rad) * Math.cos(lat2_rad) * (Math.sin(dlng / 2)**2))
    end
  end
end
