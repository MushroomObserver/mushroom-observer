# frozen_string_literal: true

#  maps an iNat taxon to an MO Name
#
#  Operates on an iNat :taxon hash:
#   :taxon in a result of an iNat API observation search
#   :identifications[:taxon] in a result of an iNat API observation search
#  The hash includes:
#   { id: Integer, name: String, rank: String, ...}
#  and for identifications, also:
#   { ancestor_ids: [Integer, ...] }
#
#  == Usage
#  example usages
#   obs_taxon = Inat::Taxon.new(inat_obs[:taxon])
#   name = obs_taxon.name
#
#   ident_taxon = Inat::Taxon.new(identification[:taxon])
#   name = ident_taxon.name
#
#  The primary reason for the existence of this class is that
#  the results of an iNat observation search do not include
#  the ICN scientific names of taxa at infrageneric and infraspecific ranks.
#
#  == Class methods
#
#  == Instance methods
#
#  name::             MO Name matching the iNat taxon, or nil if none found
#  full_name_string:: ICN-format name string, used by callers to create MO Names
#
class Inat
  class Taxon
    include Inat::Constants

    # Allow hash key access to the iNat observation data
    delegate :[], to: :@taxon

    def initialize(taxon)
      @taxon = taxon
    end

    # Returns the matching MO Name, or nil if none found.
    def name
      names =
        # iNat "Complex" definition
        # https://www.inaturalist.org/pages/curator+guide#complexes
        if complex?
          matching_group_names
        else
          matching_names_at_regular_ranks
        end
      best_mo_name(names)
    end

    # The ICN-format name string for this taxon.
    # Handles special cases: infrageneric names (which need the genus prepended)
    # and infraspecific names (which need the rank inserted).
    def full_name_string
      return monomial_complex_name_string if monomial_complex?

      # iNat infrageneric Observation ID's need special handling because
      # iNat does not provide a name string which includes the genus.
      return infrageneric_name_string if infrageneric?

      # iNat infraspecific :name strings omit the rank.
      # Ex: "Inonotus obliquus sterilis"
      return insert_rank_between_species_and_final_epithet if infraspecific?

      @taxon[:name]
    end

    def importable?
      ancestor_ids = @taxon[:ancestor_ids]
      return false if ancestor_ids.blank?

      ancestor_ids.intersect?(IMPORTABLE_TAXON_IDS)
    end

    #########

    private

    def complex? = @taxon[:rank] == "complex"

    def monomial_complex? = complex? && @taxon[:name].exclude?(" ")

    def matching_group_names
      # MO equivalent could be "group", "clade", or "complex"
      safe = Name.sanitize_sql_like(full_name_string)
      ::Name.where(::Name[:text_name].matches("#{safe}%")).
        where(rank: "Group", correct_spelling_id: nil).
        order(deprecated: :asc)
    end

    def matching_names_at_regular_ranks
      ::Name.where(
        # parse it to get MO's text_name rank abbreviation
        # E.g. "sect." instead of "section"
        text_name: ::Name.parse_name(full_name_string).text_name,
        rank: @taxon[:rank].titleize,
        correct_spelling_id: nil
      ).
        # iNat lacks taxa "sensu xxx", so ignore MO Names sensu xxx
        where.not(::Name[:author] =~ /^sensu /).
        order(deprecated: :asc)
    end

    # Returns e.g. "Amanita mappae" (no "complex" suffix —
    # create_mo_name appends it).
    def monomial_complex_name_string
      "#{ancestor_genus_name} #{@taxon[:name].downcase}"
    end

    # NOTE: 2025-10-29 jdc
    # iNat infrageneric name strings lack the genus.
    # They're just the epithet, e.g. "Validae",
    # which iNat displays as rank + epithet, e.g. "section Validae".
    #
    # Use an API taxa request, rather than try to parse the results of
    # the iNat API observation request.
    # The latter proved too complex and unreliable.
    def infrageneric_name_string
      "#{ancestor_genus_name} #{@taxon[:rank]} #{@taxon[:name]}"
    end

    # Look up the genus ancestor of this taxon via the iNat taxa API.
    def ancestor_genus_name
      path = "taxa?#{{ id: self[:ancestor_ids].join(","),
                       rank: "genus" }.to_query}"
      res = Inat::APIRequest.new(nil).request(path: path)
      JSON.parse(res.body, symbolize_names: true)[:results].first[:name]
    end

    def infrageneric?
      %w[subgenus section subsection stirps series subseries].
        include?(@taxon[:rank])
    end

    def insert_rank_between_species_and_final_epithet
      words = @taxon[:name].split
      "#{words[0..1].join(" ")} #{@taxon[:rank]} #{words[2]}"
    end

    def infraspecific? = %w[subspecies variety form].include?(@taxon[:rank])

    def taxon_name = @taxon[:name]

    def best_mo_name(names)
      # Simplest to pick the 1st one if there are any
      # (They've already been sorted)
      return names.first if names.any?

      nil
    end
  end
end
