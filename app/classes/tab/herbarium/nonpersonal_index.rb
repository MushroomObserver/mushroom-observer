# frozen_string_literal: true

# "Herbarium Index" return link — sent from show / new / edit /
# curator-request pages back to the nonpersonal-herbaria index (the
# canonical herbaria list). Carries the current `q_param` so a
# filtered round trip preserves the filter.
class Tab::Herbarium::NonpersonalIndex < Tab::Base
  def initialize(q_param: nil)
    super()
    @q_param = q_param
  end

  def title
    :herbarium_index.t
  end

  def path
    with_q_param(herbaria_path(nonpersonal: true), @q_param)
  end

  def alt_title
    "nonpersonal_herbaria_index"
  end
end
