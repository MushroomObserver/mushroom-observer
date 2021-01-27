# frozen_string_literal: true

module Report
  module Darwin
    class ImageObservations < Report::CSV
      attr_accessor :observations

      self.separator = "\t"

      def initialize(args)
        super(args)
        self.observations = args[:observations]
      end

      def formatted_rows
        gbif_row = GbifRow.new
        observations.map do |row|
          gbif_row.row = row
          [
            gbif_row.observation_id,
            "#{MO.http_domain}/#{gbif_row.observation_id}",
            "HumanObservation",
            gbif_row.updated_at,
            "MushroomObserver",
            nil,
            gbif_row.name_text_name,
            gbif_row.name_author,
            gbif_row.name_rank,
            gbif_row.genus,
            gbif_row.species,
            gbif_row.form_or_variety_or_subspecies,
            gbif_row.user_name,
            gbif_row.obs_when,
            gbif_row.year,
            gbif_row.month,
            gbif_row.day,
            gbif_row.country,
            gbif_row.state,
            gbif_row.county,
            gbif_row.locality,
            gbif_row.best_lat,
            gbif_row.best_long,
            gbif_row.best_low,
            gbif_row.best_high,
            gbif_row.obs_notes
          ]
        end
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
    end
  end
end
