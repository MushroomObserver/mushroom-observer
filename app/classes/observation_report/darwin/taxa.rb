# frozen_string_literal: true

module ObservationReport
  module Darwin
    # Darwin Core Observations format.
    class Taxa < ObservationReport::CSV
      attr_accessor :observations

      self.separator = "\t"

      def initialize(args)
        super(args)
        self.observations = args[:observations]
    end

      def formatted_rows
        sort_after(self.observations.taxa)
      end

      def labels
        %w[
          taxonID
          scientificName
        ]
      end

      def format_row(row)
        [
          row[0],
          row[1]
        ]
      end

      def sort_after(rows)
        rows.sort_by { |row| row[0].to_i }
      end
    end
  end
end
