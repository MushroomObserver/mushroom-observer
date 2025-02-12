# frozen_string_literal: true

module Tabs
  module GeneralHelper
    # Replacement for coercions (or "coercion"-style links to index same class)
    # Query needs to know which joins are necessary to make these conversions
    # work, so this list needs to be maintained if the Query class is updated.
    RELATED_TYPES = {
      # model.table_name.to_sym: [:Association],
      images: [:Observation],
      locations: [:LocationDescription, :Name, :Observation],
      names: [:NameDescription, :Observation],
      observations: [:Image, :Location, :Name, :Sequence]
    }.freeze

    # The `model` is the index you're going to, the `type` is the join subquery
    # Controller is needed to access the method `add_query_param` in order to
    # add a new, non-q query param. Subquery is provisional, not the current `q`
    def related_objects_tab(model, type, current_query)
      obj_query = current_or_related_objects_query(model, type, current_query)

      InternalLink::RelatedQuery.new(obj_query, model, controller).tab
    end

    # Links to regular indexes of the same objects can come from maps.
    # and just reuse the current_query.
    # Other links could come from an index that itself was the result of a
    # subquery. Observations of these names -> Locations of these observations
    # -> Map of these locations -> Observations of these locations.
    # In this case, check for the original (obs) query nested within the params.
    # Otherwise, make a new query for the related model.
    def current_or_related_objects_query(model, type, current_query)
      existing_subquery = existing_subquery_param(model, type)
      if model.name.to_sym == type
        current_query.params
      elsif current_query.params.deep_find(existing_subquery).present?
        current_query.params[existing_subquery]
      else
        query_class = "Query::#{model.name.pluralize}".constantize
        subquery = query_class.find_subquery_param_name(type)
        Query.lookup(:"#{model}", "#{subquery}": current_query.params)
      end
    end

    def existing_subquery_param(model, type)
      existing_query_class = "Query::#{type.to_s.pluralize}".constantize
      existing_query_class.find_subquery_param_name(model.name.to_sym)
    end

    def related_images_tab(type, current_query)
      return unless current_query && RELATED_TYPES[:images].include?(type)

      related_objects_tab(Image, type, current_query)
    end

    def related_locations_tab(type, current_query)
      return unless current_query && RELATED_TYPES[:locations].include?(type)

      related_objects_tab(Location, type, current_query)
    end

    def related_names_tab(type, current_query)
      return unless current_query && RELATED_TYPES[:names].include?(type)

      related_objects_tab(Name, type, current_query)
    end

    def related_observations_tab(type, current_query)
      return unless current_query && RELATED_TYPES[:observations].include?(type)

      related_objects_tab(Observation, type, current_query)
    end

    def search_tab_for(site_symbol, search_string)
      return unless (url = external_search_urls[site_symbol])

      InternalLink.new(
        site_symbol.to_s.titlecase, "#{url}#{search_string}",
        html_options: { id: "search_link_to_#{site_symbol}_#{search_string}" }
      ).tab
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

      InternalLink::Model.new(
        text, obj, add_query_param(obj.show_link_args),
        html_options: { class: "#{obj.type_tag}_return_link" }
      ).tab
    end

    def show_object_tab(obj, text = nil)
      text ||= :show_object.t(type: obj.type_tag)

      InternalLink::Model.new(
        text, obj, add_query_param(obj.show_link_args),
        html_options: { class: "#{obj.type_tag}_link" }
      ).tab
    end

    def show_parent_tab(obj, text = nil)
      text ||= :show_object.t(type: obj.parent.type_tag)

      InternalLink::Model.new(
        text, obj, add_query_param(obj.parent.show_link_args),
        html_options: { class: "parent_#{obj.parent.type_tag}_link" }
      ).tab
    end

    def object_index_tab(obj, text = nil)
      text ||= :list_objects.t(type: obj.type_tag)

      InternalLink::Model.new(
        text, obj, add_query_param(obj.index_link_args),
        html_options: { class: "#{obj.type_tag.to_s.pluralize}_index_link" }
      ).tab
    end
  end
end
