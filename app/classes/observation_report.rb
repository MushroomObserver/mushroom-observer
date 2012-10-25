# encoding: utf-8

module ObservationReport
  class Base
    attr_accessor :query
    attr_accessor :encoding

    class_inheritable_accessor :default_encoding
    class_inheritable_accessor :mime_type
    class_inheritable_accessor :extension
    class_inheritable_accessor :header

    def initialize(args)
      self.query    = args[:query]
      self.encoding = args[:encoding] || self.default_encoding
      raise "ObservationReport initialized without query!"    if !query
      raise "ObservationReport initialized without encoding!" if !encoding
    end

    def filename
      "observations_#{query.id.alphabetize}.#{extension}"
    end

    def body
      case encoding
        when 'UTF-8'
          render
        when 'ASCII'
          render.to_ascii
        else
          render.iconv(encoding)
      end
    end

    OBS_ID = 0
    OBS_WHEN = 1
    OBS_LAT = 2
    OBS_LONG = 3
    OBS_ALT = 4
    OBS_SPECIMEN = 5
    OBS_IS_COLLECTION_LOCATION = 6
    OBS_VOTE_CACHE = 7
    OBS_THUMB_IMAGE_ID = 8
    OBS_NOTES = 9
    OBS_MODIFIED = 10
    USER_ID = 11
    USER_LOGIN = 12
    USER_NAME = 13
    NAME_ID = 14
    NAME_TEXT_NAME = 15
    NAME_AUTHOR = 16
    NAME_RANK = 17
    LOC_ID = 18
    LOC_NAME = 19
    LOC_NORTH = 20
    LOC_SOUTH = 21
    LOC_EAST = 22
    LOC_WEST = 23
    LOC_HIGH = 24
    LOC_LOW = 25

    def rows_without_location
      query.select_rows(
        :select => [
            'observations.id',
            'observations.when',
            'observations.lat',
            'observations.long',
            'observations.alt',
            'observations.specimen',
            'observations.is_collection_location',
            'observations.vote_cache',
            'observations.thumb_image_id',
            'observations.notes',
            'observations.modified',
            'users.id',
            'users.login',
            'users.name',
            'names.id',
            'names.text_name',
            'names.author',
            'names.rank',
            '""',
            'observations.where',
            '""',
            '""',
            '""',
            '""',
            '""',
            '""',
          ].join(','),
        :join => [:users, :names],
        :where => 'observations.location_id IS NULL',
        :order => 'observations.id ASC'
      )
    end

    def rows_with_location
      query.select_rows(
        :select => [
            'observations.id',
            'observations.when',
            'observations.lat',
            'observations.long',
            'observations.alt',
            'observations.specimen',
            'observations.is_collection_location',
            'observations.vote_cache',
            'observations.thumb_image_id',
            'observations.notes',
            'observations.modified',
            'users.id',
            'users.login',
            'users.name',
            'names.id',
            'names.text_name',
            'names.author',
            'names.rank',
            'locations.id',
            'locations.name',
            'locations.north',
            'locations.south',
            'locations.east',
            'locations.west',
            'locations.high',
            'locations.low',
          ].join(','),
        :join => [:users, :locations, :names],
        :order => 'observations.id ASC'
      )
    end

    def all_rows
      rows_with_location + rows_without_location
    end

    def clean_boolean(val)
      val == 1 ? 'X' : nil
    end

    def clean_integer(val)
      val.blank? ? nil : val.to_f.round
    end

    def clean_float(val, places, multiplier=1.0)
      val.blank? ? nil : (val.to_f * multiplier).round(places)
    end

    def clean_string(val)
      val.blank? ? nil : val
    end

    def clean_rank(val)
      val.blank? ? nil : val.downcase   # :"rank_#{val.downcase}".l
    end

    def split_location(val)
      if val.blank?
        return nil
      else
        country, state, county, location = Location.reverse_name(val).split(', ', 4)
        if !county || !county.sub!(/ Co\.$/, '')
          country, state, location = Location.reverse_name(val).split(', ', 3)
          county = nil
        end
        return [country, state, county, location]
      end
    end

    def split_name(name, author, rank)
      gen = cf = sp = ssp = var = f = sp_author = ssp_author = var_author = f_author = nil
      cf = 'cf.' if name.sub!(/ cf\. /, ' ')
      if %[Genus Species Subspecies Variety Form].include?(rank)
        f   = $2 if name.sub!(/ f. (\S+)$/, '')
        var = $2 if name.sub!(/ var. (\S+)$/, '')
        ssp = $2 if name.sub!(/ ssp. (\S+)$/, '')
        sp  = $1 if name.sub!(/ (\S+)$/, '')
        gen = name
        f_author   = author if rank == 'Form'
        var_author = author if rank == 'Variety'
        ssp_author = author if rank == 'Subspecies'
        sp_author  = author if rank == 'Species'
      else
        gen = name.sub(/ .*/, '')
      end
      return [ gen, sp, ssp, var, f, sp_author, ssp_author, var_author, f_author, cf ]
    end
  end

  class CSV < Base
    self.default_encoding = 'UTF-8'
    self.mime_type = 'text/csv'
    self.extension = 'csv'
    self.header = { :header => 'present' }

    def render
      FasterCSV.generate do |csv|
        csv << labels
        rows.each do |row|
          csv << row
        end
      end.force_encoding('UTF-8')
    end
  end

################################################################################

  class Raw < CSV
    def labels
      %w[
        observation_id
        user_id
        user_login
        user_name
        collection_date
        has_specimen
        consensus_name_id
        consensus_name
        consensus_author
        consensus_rank
        confidence
        location_id
        country
        state
        county
        location
        latitude
        longitude
        altitude
        north_edge
        south_edge
        east_edge
        west_edge
        max_altitude
        min_altitude
        is_collection_location
        thumbnail_image_id
        notes
      ]
    end

    def rows
      return all_rows.map do |row|
        observation_id         = clean_integer(row[OBS_ID])
        user_id                = clean_integer(row[USER_ID])
        user_login             = clean_string(row[USER_LOGIN])
        user_name              = clean_string(row[USER_NAME])
        collection_date        = clean_string(row[OBS_WHEN])
        has_specimen           = clean_boolean(row[OBS_SPECIMEN])
        consensus_name_id      = clean_integer(row[NAME_ID])
        consensus_name         = clean_string(row[NAME_TEXT_NAME])
        consensus_author       = clean_string(row[NAME_AUTHOR])
        consensus_rank         = clean_rank(row[NAME_RANK])
        confidence             = clean_float(row[OBS_VOTE_CACHE], 1, 100.0 / 3.0)
        location_id            = clean_integer(row[LOC_ID])
        country, state, county, location = split_location(row[LOC_NAME])
        latitude               = clean_float(row[OBS_LAT], 4)
        longitude              = clean_float(row[OBS_LONG], 4)
        altitude               = clean_integer(row[OBS_ALT])
        north_edge             = clean_float(row[LOC_NORTH], 4)
        south_edge             = clean_float(row[LOC_SOUTH], 4)
        east_edge              = clean_float(row[LOC_EAST], 4)
        west_edge              = clean_float(row[LOC_WEST], 4)
        max_altitude           = clean_integer(row[LOC_HIGH])
        min_altitude           = clean_integer(row[LOC_LOW])
        is_collection_location = clean_boolean(row[OBS_IS_COLLECTION_LOCATION])
        thumbnail_image_id     = clean_integer(row[OBS_THUMB_IMAGE_ID])
        notes                  = clean_string(row[OBS_NOTES])
        [
          observation_id,
          user_id,
          user_login,
          user_name,
          collection_date,
          has_specimen,
          consensus_name_id,
          consensus_name,
          consensus_author,
          consensus_rank,
          confidence,
          location_id,
          country,
          state,
          county,
          location,
          latitude,
          longitude,
          altitude,
          north_edge,
          south_edge,
          east_edge,
          west_edge,
          max_altitude,
          min_altitude,
          is_collection_location,
          thumbnail_image_id,
          notes
        ]
      end.sort_by {|row| row[0].to_i}
    end
  end

################################################################################

  class Adolf < CSV
    def labels
      [
        "Database Field",
        "Herbarium",
        "Accession Number",
        "Genus",
        "Qualifier",
        "Species",
        "Species Author",
        "Subspecies",
        "Subspecies Author",
        "Variety",
        "Variety Author",
        "Country",
        "ProvinceState",
        "Location",
        "VStart_LatDegree",
        "VStart_LongDegree",
        "VEnd_LatDegree",
        "VEnd_LongDegree",
        "Grid Ref.",
        "Habitat",
        "Host Substratum",
        "Altitude",
        "Date",
        "Collector",
        "Other Collectors",  # <-- Adolf puts MO obs num here
        "Number",
        "Determined by",
        "Notes",
        "Originally identified as",
        "Annotation 1",
        "Annotation 2",
        "Annotation 3",
        "More Annotations",
        "Original Herbarium",
        "GenBank",
        "Herbarium Notes",
        "WWW comments",
        "Database number"
      ]
    end

    def rows
      return all_rows.map do |row|
        genus, sp, ssp, var, f, sp_author, ssp_author, var_author, f_author, cf =
          split_name(row[NAME_TEXT_NAME], row[NAME_AUTHOR], row[NAME_RANK])
        country, state, county, location = split_location(row[LOC_NAME])
        location = "#{county} Co., #{location}".sub(/, $/, '') if county
        start_lat  = clean_float(row[OBS_LAT], 4)
        start_lon  = clean_float(row[OBS_LONG], 4)
        if !start_lat || !start_lon
          start_lat  = clean_float(row[LOC_NORTH], 4)
          end_lat    = clean_float(row[LOC_SOUTH], 4)
          start_long = clean_float(row[LOC_EAST], 4)
          end_long   = clean_float(row[LOC_WEST], 4)
        end
        altitude   = clean_integer(row[OBS_ALT])
        date       = clean_string(row[OBS_WHEN])
        collector  = clean_string(row[USER_NAME]) || clean_string(row[USER_LOGIN])
        others     = "MO # " + clean_integer(row[OBS_ID]).to_s
        notes      = clean_string(row[OBS_NOTES])
        original   = $1 if notes && notes.sub!(/original herbarium label: *(\S[^\n\r]*\S)/, '')
        notes = notes.strip if notes
        [
          nil, nil, nil,
          genus, cf, sp, sp_author, ssp, ssp_author, var, var_author,
          country, state, location,
          start_lat,
          start_long,
          end_lat,
          end_long,
          nil, nil, nil,
          altitude,
          date,
          collector,
          others,
          nil, nil,
          notes,
          original
        ]
      end.sort_by {|row| row[0].to_i}
    end
  end

################################################################################

  class Darwin < CSV
    def labels
      %w[
        DateLastModified
        InstitutionCode
        CollectionCode
        CatalogNumber
        ScientificName
        ScientificNameAuthor
        ScientificNameRank
        Genus
        Species
        Subspecies
        Collector
        DateCollected
        YearCollected
        MonthCollected
        DayCollected
        Country
        StateProvince
        County
        Locality
        Latitude
        Longitude
        MinimumElevation
        MaximumElevation
        Notes
      ]
    end

    def rows
      return all_rows.map do |row|
        modified = clean_string(row[OBS_MODIFIED])
        id = clean_integer(row[OBS_ID])
        name = clean_string(row[NAME_TEXT_NAME])
        rank = clean_rank(row[NAME_RANK])
        author = clean_string(row[NAME_AUTHOR])
        genus, sp, ssp, var, f, sp_author, ssp_author, var_author, f_author, cf =
          split_name(row[NAME_TEXT_NAME], row[NAME_AUTHOR], row[NAME_RANK])
        collector = clean_string(row[USER_NAME]) || clean_string(row[USER_LOGIN])
        date = clean_string(row[OBS_WHEN])
        year, month, day = date.to_s.split('-')
        month.sub!(/^0/, '')
        day.sub!(/^0/, '')
        notes = clean_string(row[OBS_NOTES])
        country, state, county, location = split_location(row[LOC_NAME])
        lat   = clean_float(row[OBS_LAT], 4)
        long  = clean_float(row[OBS_LONG], 4)
        alt   = clean_integer(row[OBS_ALT])
        north = clean_float(row[LOC_NORTH], 4)
        south = clean_float(row[LOC_SOUTH], 4)
        east  = clean_float(row[LOC_EAST], 4)
        west  = clean_float(row[LOC_WEST], 4)
        high  = clean_integer(row[LOC_HIGH])
        low   = clean_integer(row[LOC_LOW])
        lat  ||= ((north + south) / 2).round(4) if north and south
        long ||= ((east + west) / 2).round(4) if east and west
        low = high = alt if alt
        [
          modified, 'MushroomObserver', nil, id,
          name, author, rank, genus, sp, f || var || ssp,
          collector, date, year, month, day,
          country, state, county, location,
          lat, long, low, high,
          notes
        ]
      end.sort_by {|row| row[3].to_i}
    end
  end

################################################################################

  class Symbiota < CSV
    def labels
      %w[
        scientificName
        scientificNameAuthorship
        taxonRank
        genus
        specificEpithet
        infraspecificEpithet
        recordedBy
        recordNumber
        eventDate
        year
        month
        day
        country
        stateProvince
        county
        locality
        decimalLatitude
        decimalLongitude
        minimumElevationInMeters
        maximumElevationInMeters
        modified
        fieldNotes
      ]
    end

    def rows
      return all_rows.map do |row|
        modified = clean_string(row[OBS_MODIFIED])
        id = clean_integer(row[OBS_ID])
        name = clean_string(row[NAME_TEXT_NAME])
        rank = clean_rank(row[NAME_RANK])
        author = clean_string(row[NAME_AUTHOR])
        genus, sp, ssp, var, f, sp_author, ssp_author, var_author, f_author, cf =
          split_name(row[NAME_TEXT_NAME], row[NAME_AUTHOR], row[NAME_RANK])
        collector = clean_string(row[USER_NAME]) || clean_string(row[USER_LOGIN])
        date = clean_string(row[OBS_WHEN])
        year, month, day = date.to_s.split('-')
        month.sub!(/^0/, '')
        day.sub!(/^0/, '')
        notes = clean_string(row[OBS_NOTES])
        country, state, county, location = split_location(row[LOC_NAME])
        lat   = clean_float(row[OBS_LAT], 4)
        long  = clean_float(row[OBS_LONG], 4)
        alt   = clean_integer(row[OBS_ALT])
        north = clean_float(row[LOC_NORTH], 4)
        south = clean_float(row[LOC_SOUTH], 4)
        east  = clean_float(row[LOC_EAST], 4)
        west  = clean_float(row[LOC_WEST], 4)
        high  = clean_integer(row[LOC_HIGH])
        low   = clean_integer(row[LOC_LOW])
        lat  ||= ((north + south) / 2).round(4) if north and south
        long ||= ((east + west) / 2).round(4) if east and west
        low = high = alt if alt
        [
          name, author, rank, genus, sp, f || var || ssp,
          collector, id, date, year, month, day,
          country, state, county, location,
          lat, long, low, high,
          modified, notes
        ]
      end.sort_by {|row| row[7].to_i}
    end
  end
end
