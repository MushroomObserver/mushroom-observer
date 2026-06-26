# frozen_string_literal: true

# Builds the JSON collection consumed by the client-side
# `map_controller.js` from the component's `@objects`. Two paths:
#
# - Clustered (`use_clustering?`): each mappable object becomes a
#   singleton `Mappable::MapSet` and the client runs
#   `@googlemaps/markerclusterer` over them. Captions are NOT
#   pre-rendered — clicking a marker fires a separate JSON request
#   to `Observations::MapsController#popup` for the popup HTML
#   (issue #4159, where rendering N thumbnail-bearing popups during
#   bulk fetch dominated the refetch cost).
# - Collapsible (default): MapSets are grouped server-side by
#   `Mappable::CollapsibleCollectionOfObjects`; each set is
#   decorated with title + caption inline. Captions go through
#   `Components::Map::Popup` rendered into a captured SafeBuffer
#   so the caption HTML JSON-serializes into the `data-collection`
#   attribute on `#map_div`.
#
# Mixed into `Components::Map`. The instance methods consult
# `@objects` / `@query_param` and delegate the actual collection
# building to `Mappable::ClusteredCollection.new(objects,
# query_param:)`, so the controller's JSON-refetch endpoint can
# build the same collection shape without going through a Phlex
# render.
module Components::Map::Clustering
  private

  def use_clustering?
    @clustering &&
      mappable_objects.size <= Components::Map::CLUSTER_MAX_OBJECTS
  end

  def collection_for_js
    if use_clustering?
      ::Mappable::ClusteredCollection.new(
        mappable_objects, query_param: effective_query_param
      )
    else
      mappable_collection
    end
  end

  def mappable_collection
    collection = ::Mappable::CollapsibleCollectionOfObjects.new(
      mappable_objects
    )
    collection.sets.each_value { |mapset| decorate_mapset(mapset) }
    collection
  end

  def decorate_mapset(mapset)
    mapset.color = mapset.compute_color
    mapset.glyph = mapset.compute_glyph
    mapset.border_style = mapset.compute_border_style
    mapset.title = mapset_marker_title(mapset)
    mapset.caption = capture do
      render(::Components::Map::Popup.new(set: mapset,
                                          query: effective_query,
                                          **popup_bbox_queries(mapset)))
    end
    mapset.objects = nil # can't delete, it's part of the MapSet object
  end

  def popup_bbox_queries(mapset)
    box = popup_box_params(mapset)
    queries = {}
    if mapset.observations.length > 1
      queries[:observation_bbox_query] =
        controller.find_or_create_query(:Observation, in_box: box)
    end
    if mapset.locations.length > 1
      queries[:location_bbox_query] =
        controller.find_or_create_query(:Location, in_box: box)
    end
    queries
  end

  def popup_box_params(mapset)
    { north: [mapset.north.to_f + 0.001, 90].min,
      south: [mapset.south.to_f - 0.001, -90].max,
      east: [mapset.east.to_f + 0.001, 180].min,
      west: [mapset.west.to_f - 0.001, -180].max }
  end
end
