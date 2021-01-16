# frozen_string_literal: true

module Report
  module Darwin
    class ImageTaxa < Report::CSV
      attr_accessor :taxa

      self.separator = "\t"

      def initialize(args)
        super(args)
        self.taxa = args[:taxa]
      end

      def formatted_rows
        taxa.sort_by { |row| row[1] }
      end

      def labels
        %w[
          taxonID
          scientificName
        ]
      end
    end
  end
end
