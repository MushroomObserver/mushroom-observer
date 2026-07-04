# frozen_string_literal: true

# "In existing occurrence" link, shown on the occurrence form next to
# an observation that already belongs to a multi-observation
# occurrence.
class Tab::Occurrence::Existing < Tab::Base
  def initialize(obs:)
    super()
    @obs = obs
  end

  def title
    :in_existing_occurrence.l
  end

  def path
    occurrence_path(@obs.occurrence_id)
  end

  def html_options
    { icon: :matrix, class: "d-block" }
  end
end
