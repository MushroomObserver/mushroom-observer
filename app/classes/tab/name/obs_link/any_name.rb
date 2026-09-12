# frozen_string_literal: true

# "Observations of this taxon under any name (N)" link. Query
# expands to the synonym set without exclusion — covers both this
# Name's observations and observations consensus'd to any synonym.
class Tab::Name::ObsLink::AnyName < Tab::Name::ObsLink
  private

  def label_key
    :obss_of_taxon
  end

  def filter_attr
    :any_name
  end
end
