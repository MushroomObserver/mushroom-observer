# frozen_string_literal: true

module Report
  module Darwin
    # Darwin Core Observations format.
    class Taxa < Report::CSV
      attr_accessor :query

      self.separator = "\t"

      def initialize(args)
        super(args)
        self.query = args[:query]
      end

      def formatted_rows
        query.select_rows(
          select: "DISTINCT names.id, names.text_name",
          join: [:names]
        )
      end

      def labels
        %w[
          taxonID
          scientificName
        ].freeze
      end
    end
  end
end
