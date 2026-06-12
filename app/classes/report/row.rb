# frozen_string_literal: true

module Report
  # Row in raw data table. Wraps a Hash of column-name → value
  # produced by `select_all(...).to_a` (one Hash per row).
  #
  # The base set of columns is defined by Report::BaseTable's SELECT
  # aliases (see BASE_KEYS below). For without-location obs the
  # `loc_name` slot is populated with `observations.where` (the
  # user-typed place string) and the lat/lng/high/low slots are
  # blank — mirroring the legacy positional layout.
  #
  # Subclasses can attach extra named values via Row#add_val(value, key)
  # and read them back via Row#val(key). Extension keys are symbols.
  #
  # Switched from positional Array storage to named Hash storage in
  # #3637 to eliminate intermittent column-misalignment errors that
  # surfaced under parallel testing.
  class Row
    include Report::RowExtensions

    BASE_KEYS = %w[
      obs_id obs_when obs_lat obs_lng obs_alt obs_specimen
      obs_is_collection_location obs_vote_cache obs_thumb_image_id
      obs_notes obs_updated_at
      user_id user_login user_name
      name_id name_text_name name_author name_rank
      loc_id loc_name loc_north loc_south loc_east loc_west
      loc_high loc_low
    ].freeze

    def initialize(vals)
      @vals = vals.to_h
    end

    # Generic getter for a base column. Distinguishes "missing
    # column" from "present-but-false/nil" via `key?` so a stored
    # `false` isn't masked into nil. Returns nil for missing keys
    # (the implicit value of the falsey `if`).
    def [](key)
      @vals[key.to_s] if @vals.key?(key.to_s)
    end

    def obs_id
      self["obs_id"].presence&.to_i
    end

    def obs_url
      "#{MO.http_domain}/obs/#{obs_id}"
    end

    def obs_when
      self["obs_when"].presence&.to_s
    end

    def obs_lat(prec = 4)
      self["obs_lat"].blank? ? nil : self["obs_lat"].to_f.round(prec)
    end

    def obs_lng(prec = 4)
      self["obs_lng"].blank? ? nil : self["obs_lng"].to_f.round(prec)
    end

    def obs_alt
      self["obs_alt"].presence&.round
    end

    def obs_specimen
      self["obs_specimen"] == 1 ? "X" : nil
    end

    def obs_is_collection_location
      self["obs_is_collection_location"] == 1 ? "X" : nil
    end

    def obs_vote_cache(prec = 4)
      val = self["obs_vote_cache"]
      val.blank? ? nil : (val.to_f * 100 / 3).round(prec)
    end

    def obs_thumb_image_id
      self["obs_thumb_image_id"].presence&.to_i
    end

    def obs_notes
      self["obs_notes"].blank? ? nil : notes_export_formatted
    end

    def obs_notes_as_hash
      self["obs_notes"].blank? ? nil : notes_to_hash
    end

    def obs_updated_at
      self["obs_updated_at"].presence&.to_s
    end

    def user_id
      self["user_id"].presence&.to_i
    end

    def user_login
      self["user_login"].presence&.to_s
    end

    def user_name
      self["user_name"].presence&.to_s
    end

    def user_name_or_login
      user_name || user_login
    end

    def name_id
      self["name_id"].presence&.to_i
    end

    def name_text_name
      self["name_text_name"].presence&.to_s
    end

    def name_author
      self["name_author"].presence&.to_s
    end

    def name_rank
      val = self["name_rank"]
      val.blank? ? nil : Name.ranks.key(val).to_s
    end

    def loc_id
      self["loc_id"].presence&.to_i
    end

    def loc_name
      self["loc_name"].presence&.to_s
    end

    def loc_name_sci
      val = self["loc_name"]
      val.blank? ? nil : Location.reverse_name(val.to_s)
    end

    def loc_north(prec = 4)
      self["loc_north"].blank? ? nil : self["loc_north"].to_f.round(prec)
    end

    def loc_south(prec = 4)
      self["loc_south"].blank? ? nil : self["loc_south"].to_f.round(prec)
    end

    def loc_east(prec = 4)
      self["loc_east"].blank? ? nil : self["loc_east"].to_f.round(prec)
    end

    def loc_west(prec = 4)
      self["loc_west"].blank? ? nil : self["loc_west"].to_f.round(prec)
    end

    def loc_high
      self["loc_high"].blank? ? nil : self["loc_high"].to_f.round
    end

    def loc_low
      self["loc_low"].blank? ? nil : self["loc_low"].to_f.round
    end

    # Extension columns added by Report::BaseTable#add_*! helpers.
    # Keys are symbols (e.g. :collector_ids, :gps_hidden_flag).
    def val(key)
      @vals[key.to_sym]
    end

    def add_val(value, key)
      @vals[key.to_sym] = value
    end
  end
end
