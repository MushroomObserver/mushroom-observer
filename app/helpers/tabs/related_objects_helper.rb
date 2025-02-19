# frozen_string_literal: true

module Tabs
  module RelatedObjectsHelper
    # These build links for indexes of a related object, filtered by the
    # current query (or indexes of the same object, from a map). This new
    # joined filtered query is passed as a new, provisional `q` - it is not
    # saved as a QueryRecord because it's derived from that original query.
    #
    # The `model` is the index you want, the `type` is the filtering subquery.
    def related_objects_tab(model, type, current_query)
      InternalLink::RelatedQuery.new(model, type, current_query, controller).tab
    end

    def related_images_tab(type, current_query)
      return unless current_query && Query.related?(:Image, type)

      related_objects_tab(Image, type, current_query)
    end

    def related_locations_tab(type, current_query)
      return unless current_query && Query.related?(:Location, type)

      related_objects_tab(Location, type, current_query)
    end

    def related_names_tab(type, current_query)
      return unless current_query && Query.related?(:Name, type)

      related_objects_tab(Name, type, current_query)
    end

    def related_observations_tab(type, current_query)
      return unless current_query && Query.related?(:Observation, type)

      related_objects_tab(Observation, type, current_query)
    end
  end
end
