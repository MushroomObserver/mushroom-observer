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
          gbif_row.output_row(row)
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
