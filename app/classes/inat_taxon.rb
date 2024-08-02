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
class InatTaxon
  def initialize(inat_taxon)
    @inat_taxon = inat_taxon
  end

  def name
    mo_names = Name.where(text_name: @inat_taxon[:name],
                          rank: @inat_taxon[:rank].titleize).
               # iNat doesn't have taxon names "sensu xxx"
               # so don't map them to MO Names sensu xxx
               where.not(Name[:author] =~ /^sensu /)
    return Name.unknown if mo_names.none?
    return mo_names.first if mo_names.one?

    # iNat name maps to multiple MO Names
    # So for the moment, just map it to Fungi
    # TODO: refine this.
    # Ideas: check iNat and MO authors, possibly prefer non-deprecated MO Name
    # - might need a dictionary here
    Name.unknown
  end
end
