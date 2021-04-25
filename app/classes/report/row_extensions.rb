# frozen_string_literal: true

module Report
  module RowExtensions
    def year
      @date ||= split_date
      @date[0]
    end

    def month
      @date ||= split_date
      @date[1]
    end

    def day
      @date ||= split_date
      @date[2]
    end

    def split_date
      year, month, day = obs_when.to_s.split("-")
      month.sub!(/^0/, "")
      day.sub!(/^0/, "")
      [year, month, day]
    end

    # --------------------

    def country
      @location ||= split_location
      @location[0]
    end

    def state
      @location ||= split_location
      @location[1]
    end

    def county
      @location ||= split_location
      @location[2]
    end

    def locality
      @location ||= split_location
      @location[3]
    end

    def locality_with_county
      val = Location.reverse_name(loc_name)
      return nil if val.blank?

      val.split(", ", 3)[2]
    end

    def split_location
      val = Location.reverse_name(loc_name)
      return [nil, nil, nil, nil] if val.blank?

      country, state, county, locality = val.split(", ", 4)
      if county && !county.sub!(/ (Co\.|Parish)$/, "")
        locality = locality.blank? ? county : "#{county}, #{locality}"
        county = nil
      end
      [country, state, county, locality]
    end

    # --------------------

    def best_lat(prec = 4)
      lat = obs_lat(prec)
      return lat if lat.present?

      north = loc_north(prec + 10)
      south = loc_south(prec + 10)
      return nil unless north && south

      ((north + south) / 2).round(prec)
    end

    def best_long(prec = 4)
      long = obs_long(prec)
      return long if long.present?

      east = loc_east(prec + 10)
      west = loc_west(prec + 10)
      return nil unless east && west

      ((east + west) / 2).round(prec)
    end

    def best_north(prec = 4)
      obs_lat(prec) || loc_north(prec)
    end

    def best_south(prec = 4)
      obs_lat(prec) || loc_south(prec)
    end

    def best_east(prec = 4)
      obs_long(prec) || loc_east(prec)
    end

    def best_west(prec = 4)
      obs_long(prec) || loc_west(prec)
    end

    def best_high
      obs_alt || loc_high
    end

    def best_low
      obs_alt || loc_low
    end

    # --------------------

    def genus
      @name ||= split_name
      @name[0]
    end

    def species
      @name ||= split_name
      @name[1]
    end

    def subspecies
      @name ||= split_name
      @name[2]
    end

    def variety
      @name ||= split_name
      @name[3]
    end

    def form
      @name ||= split_name
      @name[4]
    end

    def form_or_variety_or_subspecies
      form || variety || subspecies
    end

    def species_author
      @name ||= split_name
      @name[5]
    end

    def subspecies_author
      @name ||= split_name
      @name[6]
    end

    def variety_author
      @name ||= split_name
      @name[7]
    end

    def form_author
      @name ||= split_name
      @name[8]
    end

    def cf
      @name ||= split_name
      @name[9]
    end

    def split_name
      name = name_text_name.dup
      cf = name.sub!(/ cfr?\.( |$)/, "\\1") ? "cf." : nil
      gen, sp, ssp, var, f = split_name_string(name)
      sp_auth, ssp_auth, var_auth, f_auth = which_author(sp)
      [gen, sp, ssp, var, f, sp_auth, ssp_auth, var_auth, f_auth, cf]
    end

    def split_name_string(name)
      f   = Regexp.last_match(1) if name.sub!(/ f. (\S+)$/, "")
      var = Regexp.last_match(1) if name.sub!(/ var. (\S+)$/, "")
      ssp = Regexp.last_match(1) if name.sub!(/ ssp. (\S+)$/, "")
      sp  = Regexp.last_match(1) if name.sub!(/ (\S.*)$/, "")
      [name, sp, ssp, var, f]
    end

    def which_author(species)
      author = name_author
      rank   = name_rank
      return [nil, nil, nil, author] if rank == "Form"
      return [nil, nil, author, nil] if rank == "Variety"
      return [nil, author, nil, nil] if rank == "Subspecies"
      return [author, nil, nil, nil] if species.present?

      [nil, nil, nil, nil]
    end

    # --------------------

    def notes_export_formatted
      Observation.export_formatted(notes_to_hash).strip
    end

    def notes_to_hash
      # prefer safe_load to load for safety & to make RuboCop happy
      # 2nd argumnet whitelists Symbols, needed because notes have symbol keys
      YAML.safe_load(@vals[9], [Symbol])
    end
  end
end
