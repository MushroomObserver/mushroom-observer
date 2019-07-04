module ObservationReport
  # Format for export to Mycoflora.
  class Mycoflora < ObservationReport::CSV
    MYCOFLORA_PROJECT_NAME = "North American Mycoflora Project".freeze

    def labels
      %w[
        scientificName
        scientificNameAuthorship
        recordedBy
        recordNumber
        fieldNumber
        catalogNumber
        specimenFlag
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
        date
        eventID
        imageUrls
        labelProject
        collectorsName
        substrate
        habitat
        host
        occurrenceRemarks
      ]
    end

    # rubocop:disable Metrics/AbcSize
    def format_row(row)
      [
        row.name_text_name,
        row.name_author,
        row.user_name_or_login,
        record_numbers(row),       # recordNumber
        mo_number(row),            # fieldNumber
        "",                        # catalogNumber
        row.obs_specimen ? 1 : 0,
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
        row.obs_when,
        row.obs_url,
        image_urls(row),
        "NA Mycoflora Project",
        *explode_notes(row)
      ]
    end

    def record_numbers(row)
      str = collector_numbers(row)
      str = "; " + str if str.present?
      mo_number(row) + str
    end

    def mo_number(row)
      "MO #{row.obs_id}"
    end

    def collector_numbers(row)
      row.val(2).to_s.tr("\t", " ").gsub(/\n/, ", ")
    end

    def explode_notes(row)
      notes = row.obs_notes_as_hash
      [
        extract_notes_field(notes, :"Collector's_Name"),
        extract_notes_field(notes, :Substrate),
        extract_notes_field(notes, :Habitat),
        extract_notes_field(notes, :Host),
        export_other_notes(notes)
      ]
    end

    def extract_notes_field(notes, field)
      notes.delete(field).to_s.strip.t.html_to_ascii
    end

    def export_other_notes(notes)
      Observation.export_formatted(notes).strip.t.html_to_ascii
    end

    # 6371000 = radius of earth in meters
    # x / 360 * 2 * pi = converts degrees to radians
    def radius(row)
      return nil if row.obs_lat.present?

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
        map { |id| image_url(id) }.join(" ")
    end

    def image_url(id)
      Image.url(:full_size, id, transferred: true)
    end

    def sort_before(rows)
      rows.sort_by(&:obs_id)
    end

    def extend_data!(rows)
      add_image_ids!(rows, 1)
      add_collector_ids!(rows, 2)
    end
  end
end
