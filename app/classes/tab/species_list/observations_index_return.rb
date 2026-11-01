# frozen_string_literal: true

# "Cancel" link back to the observations index, used from the
# add/remove-from-species-list edit form. No model — the original
# helper carried no per-model selector; auto-derived class is a
# plain title-derived `<…>_link`.
class Tab::SpeciesList::ObservationsIndexReturn < Tab::Base
  def initialize(index_filter: nil)
    super()
    @index_filter = index_filter
  end

  def title
    :species_list_add_remove_cancel.t
  end

  def path
    with_index_filter(observations_path, @index_filter)
  end
end
