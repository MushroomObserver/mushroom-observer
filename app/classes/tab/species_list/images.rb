# frozen_string_literal: true

# "Images" link on the species-list show page's action-tab strip.
# Delegates URL-building to `Tab::RelatedQuery` (the Location-via-
# Observation bridge query, the same gate `Locations` uses -- see
# `Tab::SpeciesList::ShowActions`), but keeps a plain title to match
# this row's other plain nouns (Map, Observations, Names, Locations).
class Tab::SpeciesList::Images < Tab::Base
  def initialize(query:, controller:)
    super()
    @related = Tab::RelatedQuery.new(
      model: ::Image, filter: :Observation,
      current_query: query, controller: controller
    )
  end

  def title
    :images.ti
  end

  delegate :path, to: :@related

  def alt_title
    "images"
  end
end
