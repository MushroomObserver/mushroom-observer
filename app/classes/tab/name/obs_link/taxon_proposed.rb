# frozen_string_literal: true

# "Observations of other taxa where this taxon was proposed (N)"
# link. Joins through Namings (not just the consensus) and excludes
# observations where this taxon IS the consensus — leaves
# observations whose consensus is something else but where this
# Name (or a synonym) was offered as a proposed naming.
class Tab::Name::ObsLink::TaxonProposed < Tab::Name::ObsLink
  private

  def label_key
    :obss_taxon_proposed
  end

  def filter_attr
    :look_alikes
  end
end
