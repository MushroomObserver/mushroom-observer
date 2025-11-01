# frozen_string_literal: true

# maps an iNat taxon to an MO Name
#
# operates on an iNat :taxon hash:
#   :taxon in a result of an iNat API observation search
#   :identifications[:taxon] in a result of an iNat API observation search
# The hash includes:
#   { id: Integer, name: String, rank: String, ...}
# and for identifications, also:
#   { ancestors_ids: [Integer, ...] }
#
#  == Usage
# example usages
#  obs_taxon = Inat::Taxon.new(inat_obs[:taxon])
#  name = obs_taxon.name
#
#  ident_taxon = Inat::Taxon.new(identification[:taxon])
#  name = ident_taxon.name
#
# The primary reason for the existence of this class is that
# the results of an iNat observation search do not include
# the ICN scientific names of taxa at infrageneric and infraspecific ranks.
#
#  == Class methods
#
#  == Instance methods
#
#  name:: MO Name corresponding to the iNat taxon
#
class Inat
  class Taxon
    # Allow hash key access to the iNat observation data
    delegate :[], to: :@taxon

    def initialize(taxon)
      @taxon = taxon
    end

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
        text_name: ::Name.parse_name(full_name).text_name,
        rank: @taxon[:rank].titleize,
        correct_spelling_id: nil
      ).
        # iNat lacks taxa "sensu xxx", so ignore MO Names sensu xxx
        where.not(::Name[:author] =~ /^sensu /).
        order(deprecated: :asc)
    end

    def full_name
      # iNat infrageneric ObservationID's need special handling because
      # they display as just the epithet, e.g, "Distantes"
      if infrageneric?
        # If species_guess is just an epithet,
        # get the genus and rank from the identifications
        # This will be the case if the ObservationID was suggested by a user
        if @obs[:species_guess].exclude?(" ")
          prepend_genus_and_rank
        # Otherwise, just use the species_guess as given
        # It will be the full name, e.g. "Morchella sect. Distantes"
        # This will be the case if the ObservationID was not suggested by a user
        else
          @obs[:species_guess]
        end
      elsif infraspecific?
        # iNat :name string omits the rank. Ex: "Inonotus obliquus sterilis"
        insert_rank_between_species_and_final_epithet
      else
        taxon_name
      end
    end

    def infrageneric?
      %w[subgenus section subsection stirps series subseries].
        include?(@taxon[:rank])
    end

    def infraspecific? = %w[subspecies variety form].include?(@taxon[:rank])

    def insert_rank_between_species_and_final_epithet
      words = @taxon[:name].split
      "#{words[0..1].join(" ")} #{@taxon[:rank]} #{words[2]}"
    end

    def taxon_name = @taxon[:name]

    def best_mo_name(names)
      # Simplest to pick the 1st one if there are any
      # (They've already been sorted)
      return names.first if names.any?

      ::Name.unknown
    end

=begin # pre-PR methods
    def matching_mo_names
      return matching_complexes if complex?

      ::Name.where(text_name: @inat_taxon[:name],
                   rank: @inat_taxon[:rank].titleize).
        # iNat doesn't have taxon names "sensu xxx"
        # so don't map them to MO Names sensu xxx
        where.not(::Name[:author] =~ /^sensu /)
    end
=end
  end
end
