# frozen_string_literal: true

#
#  = Map Set Class
#
#  This class is used to hold a set of mappable objects, and provide the
#  information needed to map these as a single point or box in Google Maps.
#
#  == Typical Usage
#
#    mapset = Mappable::MapSet.new(observations_at_one_location)
#    num_obs = mapset.observations.length
#    num_loc = mapset.locations.length
#    if mapset.is_point
#      draw_marker(mapset.center)
#    else
#      draw_box(mapset.north_west, mapset.north_east, ..., mapset.north_west)
#    end
#
#  AN 20231109
#  To avoid duplicating instance methods like `south_east`, `is_box` that will
#  be used in the stimulus controller that composes markers, i'm storing all
#  the derived values on the object too. They're called the same way in Ruby,
#  but when the object is sent `to_json` it will have all the values encoded.
#  The title and caption are accessors, so they can be set in the map helper.
#  The objects are an accessor, because they get stripped before sending to JS.
#
module Mappable
  class MapSet
    # Marker colors. Color is driven purely by observation consensus:
    # a set whose members all fall in the same consensus band gets that
    # band's traffic-light color; a mix of bands gets MIXED_COLOR. Sets
    # containing only locations (no observations) fall back to
    # LOCATION_ONLY_COLOR — there's no vote information to classify.
    # See issue #4159.
    CONFIRMED_COLOR = "#5CB85C" # >=80% — bootstrap success
    TENTATIVE_COLOR = "#F0AD4E" # 0<x<80% — bootstrap warning
    DISPUTED_COLOR  = "#D9534F" # <=0% — bootstrap danger
    MIXED_COLOR     = "#C69B71" # observations in different consensus bands
    LOCATION_ONLY_COLOR = "#3B79CC" # bootstrap primary; no obs to classify

    attr_reader :north, :south, :east, :west, :is_point, :is_box,
                :north_east, :south_east, :south_west, :north_west, :lat, :lng,
                :north_south_distance, :east_west_distance, :center, :edges
    attr_accessor :objects, :title, :caption, :color, :glyph, :border_style

    def initialize(objects = [])
      @objects = objects.is_a?(Array) ? objects : [objects]
      @north = @south = @east = @west = nil
      @north_south_distance = @east_west_distance = nil
      @lat = @lng = 0
      init_objects_and_derive_extents
    end

    def init_objects_and_derive_extents
      @objects.each do |obj|
        if obj.location? && !Location.is_unknown?(obj.name)
          update_extents_with_box(obj)
        elsif obj.observation?
          if obj.lat && !obj.lat_lng_dubious?
            update_extents_with_point(obj)
          elsif (loc = obj.location) &&
                !Location.is_unknown?(loc.name)
            update_extents_with_box(loc)
          end
        else
          raise("Tried to map #{obj.class}!")
        end
      end
    end

    # NOTE: does not update extents!
    def add_objects(objects)
      @objects += objects
    end

    # True iff the set represents exactly one observation. A set may
    # also contain a Location object (the obs's location, bucketed
    # into the same geographic cell), so count observations rather
    # than all @objects — otherwise single-obs sets that were
    # bucketed with their location get colored as groups.
    def single_observation?
      observations.length == 1
    end

    # Hex color for the marker or box stroke.
    # Aggregates the consensus bands of the set's observations:
    # - All observations in the same band → that band's color.
    # - Observations spanning multiple bands → MIXED_COLOR.
    # - No observations (location-only set) → LOCATION_ONLY_COLOR.
    def compute_color
      bands = observations.map { |o| consensus_band(o) }.uniq
      return LOCATION_ONLY_COLOR if bands.empty?
      return MIXED_COLOR if bands.length > 1

      case bands.first
      when :confirmed then CONFIRMED_COLOR
      when :tentative then TENTATIVE_COLOR
      when :disputed then DISPUTED_COLOR
      end
    end

    def consensus_band(obs)
      pct = ::Vote.percent(obs.vote_cache)
      return :disputed if pct <= 0
      return :confirmed if pct >= 80

      :tentative
    end

    # Glyph:
    #   :dot       — a single observation (rendered as a circle marker)
    #   :square    — multiple observations (rendered as a square marker
    #                at the box center on info maps)
    #   :rectangle — no observations; a location-only set whose box
    #                should render as the bare outline (#4159).
    def compute_glyph
      return :rectangle if observations.empty?
      return :dot if single_observation?

      :square
    end

    # Border style:
    # :crisp  — every observation has precise GPS (or the set is
    #           location-only, whose boundary is precise by definition).
    # :none   — no observation in the set has usable GPS.
    # :dashed — a mix of precise and location-only observations.
    def compute_border_style
      obs = observations
      return :crisp if obs.empty? # location-only

      with_gps = obs.count { |o| observation_has_gps?(o) }
      return :crisp if with_gps == obs.length
      return :none if with_gps.zero?

      :dashed
    end

    def observation_has_gps?(obs)
      obs.lat.present? && !obs.lat_lng_dubious?
    end

    def observations
      @objects.select(&:observation?)
    end

    def locations
      @objects.select(&:location?)
    end

    def underlying_locations
      @objects.filter_map do |obj|
        if obj.location?
          obj
        elsif obj.observation? && obj.location
          obj.location
        end
      end.uniq
    end

    def update_extents_with_point(loc)
      lat = loc.lat.to_f.round(4)
      lng = loc.lng.to_f.round(4)
      if @north
        @north = lat if lat > @north
        @south = lat if lat < @south
        if lng_outside_existing_extents?(lng)
          east_dist = lng > @east ? lng - @east : lng - @east + 360
          west_dist = lng < @west ? @west - lng : @west - lng + 360
          if east_dist <= west_dist
            @east = lng
          else
            @west = lng
          end
        end
      else
        @north = @south = lat
        @east = @west = lng
      end
      update_derived_attributes
    end

    def lng_outside_existing_extents?(lng)
      if @east >= @west
        lng > @east || lng < @west
      else
        lng > @east && lng < @west
      end
    end

    def update_extents_with_box(loc)
      n = loc.north.to_f.round(4)
      s = loc.south.to_f.round(4)
      e = loc.east.to_f.round(4)
      w = loc.west.to_f.round(4)
      if @north
        @north = n if n > @north
        @south = s if s < @south
        if new_box_not_contained_by_old_box?(e, w)
          update_east_west_extents([e, w])
        end
      else
        @north = n
        @south = s
        @east = e
        @west = w
      end
      update_derived_attributes
    end

    # deals with overlap, neither or both straddle dateline
    def update_east_west_extents(e_w)
      (e, w) = e_w
      if (@east >= @west && e >= w && w <= @east && e >= @west) ||
         (@east < @west && e < w)
        @east = e if e > @east
        @west = w if w < @west
      # overlap, old straddles dateline
      elsif @east < @west && e >= w && (w <= @east || e >= @west)
        @east = e if e > @east && w < @east
        @west = w if w < @west && e > @west
      # overlap, new straddles dateline
      elsif @east >= @west && e < w && (w <= @east || e >= @west)
        @east = e if e > @east || w < @east
        @west = w if w < @west || e > @west
      # no overlap
      else
        east_dist = w > @east ? w - @east : w - @east + 360
        west_dist = e < @west ? @west - e : @west - e + 360
        east_dist < west_dist ? @east = e : @west = w
      end
    end

    def new_box_not_contained_by_old_box?(east, west)
      if @east >= @west
        east < west || west < @west || east > @east
      else
        east >= west || west < @west || east > @east
      end
    end

    def update_derived_attributes
      @north_west = [@north, @west]
      @north_east = [@north, @east]
      @south_west = [@south, @west]
      @south_east = [@south, @east]
      @edges = [@north, @south, @east, @west]
      if @north && @south
        @is_point = @north ? (@north - @south) < MO.box_epsilon : false
        @is_box = @north ? (@north - @south) >= MO.box_epsilon : false
        @lat = ((@north + @south) / 2.0).round(4)
        @north_south_distance = @north ? @north - @south : nil
      end
      if @east && @west
        @lng = ((@east + @west) / 2.0).round(4)
        @lng += 180 if @west > @east
        @east_west_distance = if @west > @east
                                @east - @west + 360
                              else
                                @east - @west
                              end
      end
      @center = [@lat, @lng]
    end
  end
end
