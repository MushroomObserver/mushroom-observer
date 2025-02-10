# frozen_string_literal: true

module Tabs
  module GeneralHelper
    # Replacement for coercions (or "coercion"-style links to index same class)
    # Query needs to know which joins are necessary to make these conversions
    # work, so this list needs to be maintained if the Query class is updated.
    RELATED_TYPES = {
      # model.table_name.to_sym: [:associations],
      images: [:observations],
      locations: [:descriptions, :names, :observations, :rss_logs],
      names: [:descriptions, :observations, :rss_logs],
      observations: [:images, :locations, :names, :rss_logs, :sequences]
    }.freeze

    # The `model` is the index you're going to, the `type` is the join subquery
    def related_objects_tab(model, type, current_query)
      obj_query = current_or_related_objects_query(model, type, current_query)

      [:show_objects.t(type: model.type_tag),
       add_query_param({ controller: model.show_controller,
                         action: model.index_action }, obj_query)]
    end

    # Links to regular indexes of the same objects can come from maps.
    # If that's the case, just use the same query. Otherwise, make a new query
    # for the related model.
    def current_or_related_objects_query(model, type, current_query)
      if model.to_s.underscore.pluralize == type
        current_query
      else
        Query.lookup(:"#{model}", "#{type}_query": current_query)
      end
    end

    def related_images_tab(type, current_query)
      return unless current_query && RELATED_TYPES[:images].include(type)

      tab = related_objects_tab(Image, type, current_query)
      [*tab, { class: tab_id(__method__.to_s) }]
    end

    def related_locations_tab(type, current_query)
      return unless current_query && RELATED_TYPES[:locations].include(type)

      tab = related_objects_tab(Location, type, current_query)
      [*tab, { class: tab_id(__method__.to_s) }]
    end

    def related_names_tab(type, current_query)
      return unless current_query && RELATED_TYPES[:names].include(type)

      tab = related_objects_tab(Name, type, current_query)
      [*tab, { class: tab_id(__method__.to_s) }]
    end

    def related_observations_tab(type, current_query)
      return unless current_query && RELATED_TYPES[:observations].include(type)

      tab = related_objects_tab(Observation, type, current_query)
      [*tab, { class: tab_id(__method__.to_s) }]
    end

    def coerced_query_tab(query, model)
      return nil unless query&.coercable?(model.name.to_sym)

      [:show_objects.t(type: model.type_tag),
       add_query_param({ controller: model.show_controller,
                         action: model.index_action }, query)]
    end

    def coerced_observation_query_tab(query)
      return unless query && (tab = coerced_query_tab(query, Observation))

      [*tab, { class: tab_id(__method__.to_s) }]
    end

    def coerced_location_query_tab(query)
      return unless query && (tab = coerced_query_tab(query, Location))

      [*tab, { class: tab_id(__method__.to_s) }]
    end

    def coerced_image_query_tab(query)
      return unless query && (tab = coerced_query_tab(query, Image))

      [*tab, { class: tab_id(__method__.to_s) }]
    end

    def coerced_name_query_tab(query)
      return unless query && (tab = coerced_query_tab(query, Name))

      [*tab, { class: tab_id(__method__.to_s) }]
    end

    def search_tab_for(site_symbol, search_string)
      return unless (url = external_search_urls[site_symbol])

      [site_symbol.to_s.titlecase, "#{url}#{search_string}",
       { id: "search_link_to_#{site_symbol}_#{search_string}" }]
    end

    # Dictionary of urls for searches on external sites
    def external_search_urls
      {
        Google_Maps: "https://maps.google.com/maps?q=",
        Google_Search: "https://www.google.com/search?q=",
        Wikipedia: "https://en.wikipedia.org/w/index.php?search="
      }.freeze
    end

    def object_return_tab(obj, text = nil)
      text ||= :cancel_and_show.t(type: obj.type_tag)
      [text, add_query_param(obj.show_link_args),
       { class: "#{obj.type_tag}_return_link" }]
    end

    def show_object_tab(obj, text = nil)
      text ||= :show_object.t(type: obj.type_tag)
      [text, add_query_param(obj.show_link_args),
       { class: "#{obj.type_tag}_link" }]
    end

    def show_parent_tab(obj, text = nil)
      text ||= :show_object.t(type: obj.parent.type_tag)
      [text, add_query_param(obj.parent.show_link_args),
       { class: "parent_#{obj.parent.type_tag}_link" }]
    end

    def object_index_tab(obj, text = nil)
      text ||= :list_objects.t(type: obj.type_tag)
      [text, add_query_param(obj.index_link_args),
       { class: "#{obj.type_tag.to_s.pluralize}_index_link" }]
    end
  end
end
