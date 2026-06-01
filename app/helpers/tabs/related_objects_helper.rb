# frozen_string_literal: true

module Tabs
  module RelatedObjectsHelper
    # The related-query tab definitions migrated to
    # `Tab::Related::Query` (under `app/classes/tab/related/query.rb`).
    # Use `Tab::Related::Query.for(model:, filter:, current_query:,
    # controller:)` from new code — the factory returns nil when no
    # bridge exists between `filter` and `model.name.to_sym`
    # (matching the original `return unless ...` guard).
    #
    # The methods below remain as thin legacy-shape adapters during
    # the migration. Each downstream helper / view that consumed
    # them migrates to the PORO directly; once all callers have
    # migrated, this file can be deleted.

    def related_objects_tab(model, type, current_query)
      ::Tab::Related::Query.new(
        model: model, filter: type,
        current_query: current_query, controller: controller
      ).to_a
    end

    def related_images_tab(type, current_query)
      ::Tab::Related::Query.for(
        model: Image, filter: type,
        current_query: current_query, controller: controller
      )&.to_a
    end

    def related_locations_tab(type, current_query)
      ::Tab::Related::Query.for(
        model: Location, filter: type,
        current_query: current_query, controller: controller
      )&.to_a
    end

    def related_names_tab(type, current_query)
      ::Tab::Related::Query.for(
        model: Name, filter: type,
        current_query: current_query, controller: controller
      )&.to_a
    end

    def related_observations_tab(type, current_query)
      ::Tab::Related::Query.for(
        model: Observation, filter: type,
        current_query: current_query, controller: controller
      )&.to_a
    end
  end
end
