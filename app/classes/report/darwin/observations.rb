# frozen_string_literal: true

module Report
  module Darwin
    # Darwin Core Observations format.
    class Observations < Report::CSV
      attr_accessor :ids, :taxon_set

      self.separator = "\t"

      def initialize(args)
        super(args)
        self.taxon_set = Set.new
        self.ids = []
      end

      def labels
        %w[
          CatalogNumber
          OccurrenceID
          BasisOfRecord
          DateLastModified
          InstitutionCode
          CollectionCode
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
        ].freeze
      end

      # rubocop:disable Metrics/AbcSize
      def format_row(row)
        taxon_set.add([row.name_id, row.name_text_name])
        ids.append(row.obs_id)
        [
          row.obs_id,
          "#{MO.http_domain}/#{row.obs_id}",
          "HumanObservation",
          row.obs_updated_at,
          "MushroomObserver",
          nil,
          row.name_text_name,
          clean_value(row.name_author),
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
          clean_value(row.obs_notes)
        ]
      end
      # rubocop:enable Metrics/AbcSize

      def clean_value(value)
        value&.tr("\t", " ")&.gsub("\n", "  ")&.gsub("\r", "  ")
      end

      def sort_after(rows)
        rows.sort_by { |row| row[0].to_i }
      end

      def taxa
        taxon_set.to_a
      end
    end
  end
end
