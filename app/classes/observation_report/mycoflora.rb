module ObservationReport
  # Format for export to Mycoflora.
  class Mycoflora < ObservationReport::CSV
    def labels
      %w[
        scientificName
        scientificNameAuthorship
        recordedBy
        recordNumber
        locality
        county
        state
        country
        decimalLatitude
        decimalLongitude
        coordinateUncertaintyInMeters
        minimumElevationInMeters
        maximumElevationInMeters
        day
        month
        year
        eventID
        imageUrls
        labelProject
        fieldNumber
        occurrenceRemarks
      ]
    end

    # rubocop:disable Metrics/AbcSize
    def format_row(row)
      [
        row.name_text_name,
        row.name_author,
        row.user_name_or_login,
        "MO #{row.obs_id}",
        row.locality,
        row.county,
        row.state,
        row.country,
        row.best_lat(4),
        row.best_long(4),
        radius(row),
        row.best_low,
        row.best_high,
        row.day,
        row.month,
        row.year,
        row.obs_url,
        image_urls(row),
        "NA Mycoflora Project",
        row.val(2).to_s,
        row.obs_notes.to_s.t.html_to_ascii
      ]
    end

    # 6371000 = radius of earth in meters
    # x / 360 * 2 * pi = converts degrees to radians
    def radius(row)
      return nil unless row.obs_lat.blank?
      r1 = lat_radius(row)
      r2 = long_radius(row)
      return nil if !r1 || !r2
      (r1 > r2 ? r1 : r2).to_f.round
    end

    def lat_radius(row)
      return nil if row.loc_north.blank? || row.loc_south.blank?
      (row.loc_north - row.loc_south) / 360 * 2 * Math::PI * 6_371_000 / 2
    end

    def long_radius(row)
      return nil if row.loc_east.blank? || row.loc_west.blank?
      (row.loc_east - row.loc_west) / 360 * 2 * Math::PI * 6_371_000 *
        Math.cos(row.best_lat / 360 * 2 * Math::PI) / 2
    end

    def image_urls(row)
      row.val(1).to_s.split(", ").sort_by(&:to_i).
        map { |id| "#{MO.http_domain}/#{image_path(id)}" }.join(" ")
    end

    def image_path(id)
      Image.url(:full_size, id, transferred: true)
    end

    def sort_before(rows)
      rows.sort_by(&:obs_id)
    end

    def extend_data!(rows)
      add_image_ids!(rows, 1)
      add_mycoflora_ids!(rows, 2)
    end

    def add_mycoflora_ids!(rows, col)
      herbarium = Herbarium.where(name: "Mycoflora Project").first
      return unless herbarium
      vals = HerbariumRecord.connection.select_rows %(
        SELECT ho.observation_id, h.accession_number
        FROM herbarium_records h,
             herbarium_records_observations ho,
             (#{query.query}) as ids
        WHERE ho.observation_id = ids.id AND
              ho.herbarium_record_id = h.id AND
              h.herbarium_id = #{herbarium.id}
      )
      add_column!(rows, vals, col)
    end
  end
end
