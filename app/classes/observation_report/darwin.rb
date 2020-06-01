# frozen_string_literal: true

module ObservationReport
  # Darwin format.
  class Darwin < ObservationReport::CSV
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

    # rubocop:disable Metrics/AbcSize
    def format_row(row)
      [
        row.obs_updated_at,
        "MushroomObserver",
        nil,
        row.obs_id,
        row.name_text_name,
        row.name_author,
        row.name_rank,
        row.genus,
        row.species,
        row.form_or_variety_or_subspecies,
        row.user_name_or_login,
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
        row.obs_notes
      ]
    end

    def sort_after(rows)
      rows.sort_by { |row| row[3].to_i }
    end
  end
end
