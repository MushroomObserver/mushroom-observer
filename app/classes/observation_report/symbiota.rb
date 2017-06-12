module ObservationReport
  # Symbiota-style csv report.
  class Symbiota < ObservationReport::CSV
    def labels
      %w(
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
        updated_at
        fieldNotes
      )
    end

    # rubocop:disable Metrics/AbcSize
    def format_row(row)
      [
        row.name_text_name,
        row.name_author,
        row.name_rank,
        row.genus,
        row.species,
        row.form_or_variety_or_subspecies,
        row.user_name_or_login,
        row.obs_id,
        row.obs_when,
        row.year,
        row.month,
        row.day,
        row.country,
        row.state,
        row.county,
        row.locality,
        row.best_lat,
        row.best_long,
        row.best_low,
        row.best_high,
        row.obs_updated_at,
        row.obs_notes
      ]
    end

    def sort_after(rows)
      rows.sort_by { |row| row[7].to_i }
    end
  end
end
