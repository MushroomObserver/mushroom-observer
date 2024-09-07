# frozen_string_literal: true

#
# class to map iNat taxa to MO Names
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
      # TODO: refine this.
      # Ideas: check iNat and MO authors, possibly prefer non-deprecated MO Name
      # - might need a dictionary here
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
