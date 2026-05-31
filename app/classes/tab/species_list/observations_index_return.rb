# frozen_string_literal: true

# "Cancel" link back to the observations index, used from the
# add/remove-from-species-list edit form. Plain InternalLink (no
# model variant) — the original helper carried no per-model selector.
class Tab::SpeciesList::ObservationsIndexReturn < Tab::Base
  def initialize(q_param: nil)
    super()
    @q_param = q_param
  end

  def title
    :species_list_add_remove_cancel.t
  end

  def path
    with_q_param(observations_path, @q_param)
  end
end
