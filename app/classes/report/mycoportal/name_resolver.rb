# frozen_string_literal: true

module Report
  class Mycoportal
    # Resolves a Report::Row's Name into MCP's DwC-ish sciname /
    # identificationQualifier / taxonRemarks trio. MCP (like GBIF) is
    # species-focused, so anything MO can name more precisely than that --
    # misspellings, code names, provisional/inedit names, groups/complexes,
    # sensu non stricto, and infrageneric ranks (section, subgenus, etc.) --
    # needs translating down to a bare genus plus a qualifier/remark MCP
    # can actually store.
    #
    # Reads the row's `:corrected_text_name` / `:corrected_author` /
    # `:corrected_rank` extension values, which Report::Mycoportal's
    # #add_correct_spelling! populates via a batched Name lookup before
    # any row reaches here -- this class never queries the database itself.
    class NameResolver
      CODE_NAME_QUALIFIER = "code name aff. species"
      # Matches the epithet segment of a code name like 'flavorubellus-IN04'
      # or 'acicula-PNW01' (epithet, dash, state/region abbreviation, digits).
      CODE_EPITHET_PATTERN = /\A([a-z][a-z-]*)-[A-Za-z]{2,}\d+\z/

      def initialize(row)
        @row = row
      end

      # taxon name, without authority or qualification (such as "group")
      def sciname
        # Code names and infrageneric ranks (section, subgenus, etc.) can
        # only be usefully exported to MCP as a bare genus.
        return genus_only if code_name? || infrageneric_rank?
        # The last word in text_name could be Group or Complex
        return text_name_without_last_word if group?

        normalized_text_name
      end

      # Qualifies unpublished MO text_name.
      # Examples: nom. prov., comb. prov., group, sensu lato, sensu auct.,
      # aff. section, aff. <code name epithet>
      def identification_qualifier
        return nil unless unregistrable_name?
        return code_name_qualifier if code_name?
        return group_token if group?
        return infrageneric_qualifier if infrageneric_rank?
        return prov_token if provisional?

        sensu_token
      end

      # Full name+author for code names, provisional names, groups, and
      # infrageneric ranks (section, subgenus, etc.)
      def taxon_remarks
        return unless code_name? || provisional? || group? ||
                      infrageneric_rank?

        "#{text_name} #{author}".strip
      end

      def self.infrageneric_ranks
        @infrageneric_ranks ||=
          (Name.ranks_above_species & Name.ranks_below_genus) - ["Group"]
      end

      private

      attr_reader :row

      def text_name
        row.val(:corrected_text_name) || row.name_text_name
      end

      def author
        row.val(:corrected_author) || row.name_author
      end

      def rank
        row.val(:corrected_rank) || row.name_rank
      end

      # Strips a leading "Gen. " token off "Gen. 'Foo' sp. 'bar-ST01'"-style
      # code names so they're treated as a bare code name.
      def normalized_text_name
        text_name.sub(/\AGen\.\s+/, "")
      end

      def genus_only
        normalized_text_name.split.first.delete("'")
      end

      def text_name_without_last_word
        normalized_text_name.split[0...-1].join(" ")
      end

      def unregistrable_name?
        group? || infrageneric_rank? || sensu_non_stricto? ||
          provisional? || code_name?
      end

      def group?
        normalized_text_name.match?(/(group|complex|clade)$/)
      end

      def group_token
        normalized_text_name.match(/(group|complex|clade)$/)[0]
      end

      def sensu_non_stricto?
        author.present? && author.match(/sensu(?!.*stricto)/)
      end

      def sensu_token
        author&.match(/sensu.*/)&.[](0)
      end

      def provisional?
        author&.match?(/\w+\. (?:prov|ined(?:it)?)\.?/)
      end

      def prov_token
        author&.match(/\w+\. (?:prov|ined(?:it)?)\.?/)&.[](0)
      end

      def code_name?
        normalized_text_name.match?(/'/)
      end

      # Ranks strictly between Species and Genus that MCP can only take as
      # a bare genus (Section, Subsection, Series, Stirps, Subgenus).
      # "Group" is excluded -- it's handled by #group?/#group_token
      # instead, since its text_name already carries a
      # "group"/"complex"/"clade" suffix to strip.
      def infrageneric_rank?
        self.class.infrageneric_ranks.include?(rank)
      end

      def infrageneric_qualifier
        "aff. #{rank.downcase}"
      end

      # Genus sp. 'epithet-STATEnn' code names get a qualifier naming the
      # epithet (e.g. "aff. flavorubellus") instead of the generic
      # CODE_NAME_QUALIFIER, when the quoted segment parses cleanly.
      def code_name_qualifier
        precise_code_name_qualifier || CODE_NAME_QUALIFIER
      end

      def precise_code_name_qualifier
        epithet = code_epithet
        return nil if epithet.blank?

        "aff. #{epithet}"
      end

      # Scans every quoted segment (not just the first -- "Gen. 'Foo' sp.
      # 'bar-ST01'" quotes the genus too) for the one that parses as an
      # "epithet-STATEnn" code.
      def code_epithet
        normalized_text_name.scan(/'([^']+)'/).flatten.
          filter_map { |quoted| quoted.match(CODE_EPITHET_PATTERN)&.[](1) }.
          first
      end
    end
  end
end
