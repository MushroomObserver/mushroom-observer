module ObservationReport
  # Row in raw data table.  Initialization values array comes directly from a
  # sequel query (model.connection.select_values).  Columns are:
  #
  # 0:: observations.id
  # 1:: observations.when
  # 2:: observations.lat
  # 3:: observations.long
  # 4:: observations.alt
  # 5:: observations.specimen
  # 6:: observations.is_collection_location
  # 7:: observations.vote_cache
  # 8:: observations.thumb_image_id
  # 9:: observations.notes
  # 10:: observations.updated_at
  # 11:: users.id
  # 12:: users.login
  # 13:: users.name
  # 14:: names.id
  # 15:: names.text_name
  # 16:: names.author
  # 17:: names.rank
  # 18:: locations.id
  # 19:: locations.name
  # 20:: locations.north
  # 21:: locations.south
  # 22:: locations.east
  # 23:: locations.west
  # 24:: locations.high
  # 25:: locations.low
  #
  # Subclasses of ObservationReport::Base can add/access added columns with
  # +row.val(N) = "valN"+ where N is 1, 2, and so on.
  #
  class Row
    include ObservationReport::RowExtensions

    def initialize(vals)
      @vals = vals
    end

    def obs_id
      @vals[0].blank? ? nil : @vals[0].to_i
    end

    def obs_url
      "#{MO.http_domain}/#{obs_id}"
    end

    def obs_when
      @vals[1].blank? ? nil : @vals[1].to_s
    end

    def obs_lat(prec = 4)
      @vals[2].blank? ? nil : @vals[2].to_f.round(prec)
    end

    def obs_long(prec = 4)
      @vals[3].blank? ? nil : @vals[3].to_f.round(prec)
    end

    def obs_alt
      @vals[4].blank? ? nil : @vals[4].round
    end

    def obs_specimen
      @vals[5] == 1 ? "X" : nil
    end

    def obs_is_collection_location
      @vals[6] == 1 ? "X" : nil
    end

    def obs_vote_cache(prec = 4)
      @vals[7].blank? ? nil : (@vals[7].to_f * 100 / 3).round(prec)
    end

    def obs_thumb_image_id
      @vals[8].blank? ? nil : @vals[8].to_i
    end

    def obs_notes
      @vals[9].blank? ? nil : notes_export_formatted
    end

    def obs_notes_as_hash
      @vals[9].blank? ? nil : notes_to_hash
    end

    def obs_updated_at
      @vals[10].blank? ? nil : @vals[10].to_s
    end

    def user_id
      @vals[11].blank? ? nil : @vals[11].to_i
    end

    def user_login
      @vals[12].blank? ? nil : @vals[12].to_s
    end

    def user_name
      @vals[13].blank? ? nil : @vals[13].to_s
    end

    def user_name_or_login
      user_name || user_login
    end

    def name_id
      @vals[14].blank? ? nil : @vals[14].to_i
    end

    def name_text_name
      @vals[15].blank? ? nil : @vals[15].to_s
    end

    def name_author
      @vals[16].blank? ? nil : @vals[16].to_s
    end

    def name_rank
      val = @vals[17]
      val.blank? ? nil : Name.ranks.key(val).to_s
    end

    def loc_id
      @vals[18].blank? ? nil : @vals[18].to_i
    end

    def loc_name
      @vals[19].blank? ? nil : @vals[19].to_s
    end

    def loc_name_sci
      @vals[19].blank? ? nil : Location.reverse_name(@vals[19].to_s)
    end

    def loc_north(prec = 4)
      @vals[20].blank? ? nil : @vals[20].to_f.round(prec)
    end

    def loc_south(prec = 4)
      @vals[21].blank? ? nil : @vals[21].to_f.round(prec)
    end

    def loc_east(prec = 4)
      @vals[22].blank? ? nil : @vals[22].to_f.round(prec)
    end

    def loc_west(prec = 4)
      @vals[23].blank? ? nil : @vals[23].to_f.round(prec)
    end

    def loc_high
      @vals[24].blank? ? nil : @vals[24].to_f.round
    end

    def loc_low
      @vals[25].blank? ? nil : @vals[25].to_f.round
    end

    def val(num)
      @vals[25 + num]
    end

    def add_val(val, num)
      @vals[25 + num] = val
    end
  end
end
