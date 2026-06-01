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
    observations_path(name: @name.id, related_taxa: "1")
  end

  def model
    @name
  end
end
