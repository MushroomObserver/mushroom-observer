# frozen_string_literal: true

module Report
  module RowExtensions
    def reset
      split_date
      split_location
      split_name
    end

    def year
      split_date if @year.nil?
      @year
    end

    def month
      split_date if @month.nil?
      @month
    end

    def day
      split_date if @day.nil?
      @day
    end

    def split_date
      @year, @month, @day = obs_when.to_s.split("-")
      @month.sub!(/^0/, "")
      @day.sub!(/^0/, "")
    end

    # --------------------

    def country
      split_location if @country.nil?
      @country
    end

    def state
      split_location if @state.nil?
      @state
    end

    def county
      split_location if @county.nil?
      @county
    end

    def locality
      split_location if @locality.nil?
      @locality
    end

    def locality_with_county
      val = Location.reverse_name(loc_name)
      return nil if val.blank?

      val.split(", ", 3)[2]
    end
 
    def split_location
      val = Location.reverse_name(loc_name)
      return empty_loc if val.blank?
      return @country = @state = @county = @locality = nil if val.blank?

      @country, @state, @county, @locality = val.split(", ", 4)
      if @county && !@county.sub!(/ (Co\.|Parish)$/, "")
        @locality = @locality.blank? ? @county : "#{county}, #{locality}"
        @county = nil
      end
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
      split_name if @genus.nil?
      @genus
    end

    def species
      split_name if @species.nil?
      @species
    end

    def subspecies
      split_name if @subspecies.nil?
      @subspecies
    end

    def variety
      split_name if @variety.nil?
      @variety
    end

    def form
      split_name if @form.nil?
      @form
    end

    def form_or_variety_or_subspecies
      @form || @variety || @subspecies
    end

    def species_author
      split_name if @species_author.nil?
      @species_author
    end

    def subspecies_author
      split_name if @subspecies_author.nil?
      @subspecies_author
    end

    def variety_author
      split_name if @variety_author.nil?
      @variety_author
    end

    def form_author
      split_name if @form_author.nil?
      @form_author
    end

    def cf
      split_name if @cf.nil?
      @cf
    end

    def split_name
      name = name_text_name.dup
      @cf = name.sub!(/ cfr?\.( |$)/, "\\1") ? "cf." : nil
      split_name_string(name)
      which_author(@species)
    end

    def split_name_string(name)
      @form = Regexp.last_match(1) if name.sub!(/ f. (\S+)$/, "")
      @variety = Regexp.last_match(1) if name.sub!(/ var. (\S+)$/, "")
      @subspecies = Regexp.last_match(1) if name.sub!(/ ssp. (\S+)$/, "")
      @species = Regexp.last_match(1) if name.sub!(/ (\S.*)$/, "")
      @genus = name
    end

    def which_author(species)
      author = name_author
      rank   = name_rank
      @species_author = nil
      @subspecies_author = nil
      @variety_author = nil
      @form_author = nil
      case rank
      when "Form"
        @form_author = author
      when "Variety"
        @variety_author = author
      when "Subspecies"
        @subspecies_author = author
      else
        @species_author = author if species.present?
      end
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
