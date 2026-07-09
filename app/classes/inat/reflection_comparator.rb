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

    # Degrees-to-radians, and meters per degree of latitude (constant; a
    # degree of longitude shrinks by cos(lat), applied where used).
    RAD = Math::PI / 180
    METERS_PER_DEGREE = 111_320.0

    # Field statuses are tri-state (:match / :differ / :na) so "nothing to
    # compare" stays distinct from "compared and differs" in the report.
    Result = Struct.new(
      :image_relation, :case_number, :mo_image_count, :inat_photo_count,
      :matched_image_count, :date_status, :location_status, :taxon_status,
      :collector_status, :location_meters, :mo_coord_source,
      keyword_init: true
    )

    # mo_context carries pre-resolved MO-side reference data that isn't on
    # the observation's own columns, so the class stays pure and testable:
    #   :box    — the named Location's bounding box (responds to
    #             north/south/east/west); nil disables box-aware location
    #             judgments.
    #   :logins — the MO side's iNat login(s): the owner's, plus the
    #             collector's when set. Compared against the extract's
    #             inat_login for the collector/observer check.
    def initialize(mo_obs:, extract:, mo_hashes:, inat_hashes:, mo_context: {})
      @obs = mo_obs
      @extract = extract
      @mo_hashes = mo_hashes.compact
      @inat_hashes = inat_hashes.compact
      @box = mo_context[:box]
      @mo_logins = Array(mo_context[:logins]).compact
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
        collector_status: collector_status,
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
          # Each iNat entry is a single dHash or its four rotation dHashes;
          # match against the closest so a rotated copy still counts.
          !used[i] && Image::Dhash.min_distance(mo, @inat_hashes[i]) <=
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

    # :match | :differ | :mo_gps_suspect | :na. An MO point that sits
    # outside its own named Location is corrupt (e.g. a South-Pole point on
    # a US observation); iNat's coordinate is authoritative there, so that's
    # a data error to fix, not a location edit to preserve.
    def location_status
      return :na if location_meters.nil?
      return :match if location_meters <= tolerance_meters
      return :mo_gps_suspect if mo_gps_suspect?

      :differ
    end

    # A centroid (no obs point) is compared against a coarse named area, so
    # its tolerance is that Location's own radius — a point anywhere in the
    # box is the same place. A real obs point keeps the tight base radius.
    # iNat's obscuring displacement is added on top in either case.
    def tolerance_meters
      base = if centroid_source? && @box
               location_radius_meters
             else
               BASE_MATCH_RADIUS
             end
      base + obscuring_slop
    end

    def centroid_source? = mo_coord_source == :location

    # iNat shifts obscured points randomly by up to public_accuracy meters.
    def obscuring_slop
      return 0 unless @extract.obscured

      if @extract.public_accuracy&.positive?
        @extract.public_accuracy
      else
        DEFAULT_OBSCURED_RADIUS
      end
    end

    # Centroid-to-NE-corner: the half-diagonal of the named Location's box.
    def location_radius_meters
      haversine_m(@obs.location_lat, @obs.location_lng,
                  @box.north, @box.east).round
    end

    # A stored point outside its own named Location can't be trusted; when
    # iNat's point does fall inside that Location (fuzzily, see
    # inat_in_mo_box?) the place still agrees and only the point is bad.
    def mo_gps_suspect?
      @box && mo_coord_source == :point &&
        !point_in_box?(@obs.lat, @obs.lng) && inat_in_mo_box?
    end

    # Fuzzy so iNat's obscuring displacement doesn't push a genuinely-inside
    # point just outside a small box. A point well inside is unambiguous;
    # one comfortably outside stays a plain differ.
    def inat_in_mo_box?
      point_in_box?(@extract.lat, @extract.lng,
                    BASE_MATCH_RADIUS + obscuring_slop)
    end

    # Point within the box, expanded by buffer_m meters on every side. The
    # longitude buffer widens with latitude (a degree of longitude shrinks
    # toward the poles); the box's own mid-latitude is the reference.
    def point_in_box?(lat, lng, buffer_m = 0)
      return false unless lat && lng

      dlat, dlng = buffer_degrees(buffer_m)
      lat.to_f.between?(@box.south - dlat, @box.north + dlat) &&
        lng_in_box?(lng.to_f, dlng)
    end

    # buffer_m in [lat, lng] degrees; a degree of longitude shrinks by
    # cos(lat), taken at the box's mid-latitude.
    def buffer_degrees(buffer_m)
      ref_lat = (@box.north + @box.south) / 2.0
      [buffer_m / METERS_PER_DEGREE,
       buffer_m / (METERS_PER_DEGREE * Math.cos(ref_lat * RAD))]
    end

    def lng_in_box?(lng, buf = 0)
      west = @box.west - buf
      east = @box.east + buf
      return lng.between?(west, east) if @box.west <= @box.east

      lng >= west || lng <= east # box straddles the antimeridian
    end

    def taxon_status
      return :na if @extract.taxon_name.blank? || @obs.text_name.blank?

      @extract.taxon_name.casecmp?(@obs.text_name) ? :match : :differ
    end

    # Does the MO observation's owner (or collector) correspond to the iNat
    # observer? Match on any candidate MO login (from the curated
    # users.inat_username mapping) equal to the extract's inat_login,
    # case-insensitively.
    #
    # Deliberately strict: :na means "no curated identity link" and must not
    # be resolved by inferring identity from MO login == iNat login, even on
    # an exact match. Identity comes from explicit user claiming of iNat
    # ids, not automated inference. :na is a signal to leave alone, not a
    # gap for the comparator to paper over.
    def collector_status
      return :na if @extract.inat_login.blank? || @mo_logins.empty?

      if @mo_logins.any? { |login| login.casecmp?(@extract.inat_login) }
        :match
      else
        :differ
      end
    end

    def haversine_m(lat1, lng1, lat2, lng2)
      a = haversine_a((lat2 - lat1) * RAD, (lng2 - lng1) * RAD,
                      lat1 * RAD, lat2 * RAD)
      6_371_000 * 2 * Math.asin(Math.sqrt(a))
    end

    def haversine_a(dlat, dlng, lat1_rad, lat2_rad)
      (Math.sin(dlat / 2)**2) +
        (Math.cos(lat1_rad) * Math.cos(lat2_rad) * (Math.sin(dlng / 2)**2))
    end
  end
end
