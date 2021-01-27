# frozen_string_literal: true

module Report
  class GbifRow
    include Report::RowExtensions

    def row=(row)
      @row = row
      reset
    end

    def observation_id
      @row["observation_id"]
    end

    def updated_at
      @row["updated_at"]
    end

    def name_text_name
      @row["text_name"]
    end

    def loc_name
      @row["location_name"]
    end

    def loc_north(prec)
      @row["north"].round(prec)
    end

    def loc_south(prec)
      @row["south"].round(prec)
    end

    def loc_east(prec)
      @row["east"].round(prec)
    end

    def loc_west(prec)
      @row["west"].round(prec)
    end

    def loc_high
      @row["high"]
    end

    def loc_low
      @row["low"]
    end

    def name_author
      clean_value(@row["author"])
    end

    def name_rank
      Name.ranks[@row["rank"]]
    end

    def obs_when
      @row["obs_when"]
    end

    def obs_alt
      @row["alt"]
    end

    def obs_lat(prec = 4)
      @row["lat"].blank? ? nil : @row["lat"].to_f.round(prec)
    end

    def obs_long(prec = 4)
      @row["long"].blank? ? nil : @row["long"].to_f.round(prec)
    end

    def user_name
      @row["name"].to_s == "" ? @row["login"] : @row["name"]
    end

    def obs_notes
      clean_value(@row["notes"])
    end

    def clean_value(value)
      value&.tr("\t", " ")&.gsub("\n", "  ")&.gsub("\r", "  ")
    end
  end
end
