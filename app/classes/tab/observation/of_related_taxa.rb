# frozen_string_literal: true

class Tab::Observation::OfRelatedTaxa < Tab::Base
  def initialize(name:)
    super()
    @name = name
  end

  def title
    :show_observation_related_taxa.l
  end

  def path
    observations_path(related_taxa: @name.id)
  end

  def model
    @name
  end
end
