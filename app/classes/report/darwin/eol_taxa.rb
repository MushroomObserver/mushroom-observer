# frozen_string_literal: true

module Report
  module Darwin
    class EolTaxa < Report::CSV
      attr_accessor :taxa, :genus_cache

      self.separator = "\t"

      def initialize(args)
        super(args)
        self.taxa = args[:taxa]
        self.genus_cache = {}
      end

      def formatted_rows
        results = []
        taxa.each do |row|
          results.append([row[0], row[1]] + higher_taxa(row))
        end
        results.sort_by { |row| row[1] }
      end

      def labels
        %w[
          taxonID
          scientificName
          genus
          family
          kingdom
        ]
      end

      private

        def parse_genus(name)
          name.split(' ')[0]
        end

        def higher_taxa(row)
          genus = parse_genus(row[1])
          return genus_cache[genus] if genus_cache.key?(genus)

          family_and_kingdom = (parse_classification(row[2]) ||
                                genus_classification(genus))
          result = [genus] + family_and_kingdom
          genus_cache[genus] = result
          result
        end

        def parse_classification(classification)
          return nil unless classification

          kingdom = nil
          family = nil
          classification.split("_\r\n").each do |level|
            kingdom = extract_name(level) if level.start_with?("Kingdom")
            family = extract_name(level) if level.start_with?("Family")
            return [family, kingdom] if family && kingdom
          end
          return ["", kingdom] if kingdom
          nil
        end

        def extract_name(level)
          level.split(": _")[1].chomp("_")
        end

        def genus_classification(genus)
          name = Name.find_by(text_name: genus, rank: Name.ranks[:Genus])
          if name
            family_and_kingdom = parse_classification(name.classification)
            return family_and_kingdom if family_and_kingdom
          end
          ["", ""]
        end
    end
  end
end
