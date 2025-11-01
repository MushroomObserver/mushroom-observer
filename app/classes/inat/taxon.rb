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
    def initialize(inat_taxon)
      @inat_taxon = inat_taxon
    end

    def name
      mo_names = matching_mo_names
      return ::Name.unknown if mo_names.none?
      return mo_names.first if mo_names.one?

      # iNat name maps to multiple MO Names
      # So for the moment, just map it to Fungi
      # For possible improvements, see
      # https://github.com/MushroomObserver/mushroom-observer/issues/2381
      ::Name.unknown
    end

    #########

    private

    def matching_mo_names
      return matching_complexes if complex?

      ::Name.where(text_name: @inat_taxon[:name],
                   rank: @inat_taxon[:rank].titleize).
        # iNat doesn't have taxon names "sensu xxx"
        # so don't map them to MO Names sensu xxx
        where.not(::Name[:author] =~ /^sensu /)
    end

    def complex?
      @inat_taxon[:rank] == "complex"
    end

    def matching_complexes
      # text_names of MO groups include "group" or the like
      ::Name.where(::Name[:text_name] =~ /^#{@inat_taxon[:name]}/).
        where(rank: "Group")
    end
  end
end
