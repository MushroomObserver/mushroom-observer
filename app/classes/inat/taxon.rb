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
      # iNat infrageneric Observation ID's need special handling because
      # iNat does not provide a name string which includes the genus.
      return infrageneric_name_string if infrageneric?

      # iNat infraspecific :name strings omit the rank.
      # Ex: "Inonotus obliquus sterilis"
      return insert_rank_between_species_and_final_epithet if infraspecific?

      @taxon[:name]
    end

    #########

    private

    def complex? = @taxon[:rank] == "complex"

    def matching_group_names
      # MO equivalent could be "group", "clade", or "complex"
      ::Name.where(::Name[:text_name] =~ /^#{@taxon[:name]}/).
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

    # Get the genus of an iNat infrageneric taxon via an API query
    # requesting the taxon's ancestor which has rank: genus.
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

    # Fetch the genus name for an infrageneric taxon from the iNat taxa API.
    # Raises RuntimeError on network/timeout errors, malformed JSON, or when
    # the API returns no matching genus — the error propagates to the import
    # job's StandardError handler in ObservationImporter#import_one_result.
    def ancestor_genus_name
      ancestor_ids = self[:ancestor_ids].join(",")
      results = fetch_genus_lookup_results(ancestor_ids)
      if results.blank?
        raise("iNat genus lookup returned no results for " \
              "#{@taxon[:rank]} #{@taxon[:name]}")
      end

      results.first[:name]
    rescue RestClient::Exception, JSON::ParserError => e
      raise("iNat genus lookup failed for #{@taxon[:rank]} " \
            "#{@taxon[:name]} (#{e.class}): #{e.message}")
    end

    def fetch_genus_lookup_results(ancestor_ids)
      params = { id: ancestor_ids, rank: "genus" }
      url = "#{API_BASE}/taxa?#{params.to_query}"

      response = RestClient::Request.execute(
        method: :get,
        url: url,
        headers: { Accept: "application/json" },
        open_timeout: 5,
        timeout: 10
      )
      JSON.parse(response.body, symbolize_names: true)[:results]
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
