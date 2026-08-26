# frozen_string_literal: true

# "Observations where this Name was proposed (N)" link. Joins
# through Namings (not just the consensus) for this exact Name —
# observations whose consensus may be different, but where this
# Name appears among the proposed Namings.
class Tab::Name::ObsLink::NameProposed < Tab::Name::ObsLink
  private

  def label_key
    :obss_name_proposed
  end

  def filter_attr
    :name_proposed
  end
end
