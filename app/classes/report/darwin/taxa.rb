# frozen_string_literal: true

module Report
  module Darwin
    # Darwin Core Observations format.
    class Taxa < Report::CSV
      attr_accessor :observations

      self.separator = "\t"

      def initialize(args)
        super(args)
        self.observations = args[:observations]
      end

      def formatted_rows
        sort_after(observations.taxa)
      end

      def labels
        %w[
          taxonID
          scientificName
        ].freeze
      end

      def sort_after(rows)
        rows.sort_by { |row| row[0].to_i }
      end
    end
  end
end
