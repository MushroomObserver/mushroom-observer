# frozen_string_literal: true

# "Nonpersonal Herbaria" filter link — surfaces on the herbaria
# index when viewing the unfiltered list, offering the
# nonpersonal-only filtered view.
class Tab::Herbarium::LabeledNonpersonalIndex < Tab::Base
  def title
    :herbarium_index_nonpersonal_herbaria.l
  end

  def path
    herbaria_path(nonpersonal: true)
  end
end
