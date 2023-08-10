# frozen_string_literal: true

# html used in tabsets
module Tabs
  module Locations
    module DescriptionsHelper
      def location_description_index_links(query:)
        [
          [:list_place_names_map.t, add_query_param(map_locations_path),
           { class: "map_locations_link" }],
          [:all_objects.t(type: :location), locations_path,
           { class: "locations_index_link" }],
          [*coerced_query_link(query, Location),
           { class: "location_query_link" }]
        ]
      end

      def location_description_form_new_links(description:)
        [description_location_return_link(description)]
      end

      def location_description_form_edit_links(description:)
        [
          description_location_return_link(description),
          [:cancel_and_show.t(type: :location_description),
           add_query_param(description.show_link_args),
           { class: "location_description_return_link" }]
        ]
      end

      def location_description_form_permissions_links(description:)
        [
          description_location_return_link(description),
          [:show_object.t(type: :location_description),
           add_query_param(location_description_path(description.id)),
           { class: "location_description_return_link" }]
        ]
      end

      def location_description_version_links(description:, desc_title:)
        [
          [:show_location_description.t(description: desc_title),
           add_query_param(location_description_path(description.id)),
           { class: "location_description_return_link" }]
        ]
      end

      def description_location_return_link(description)
        [:cancel_and_show.t(type: :location),
         add_query_param(location_path(description.location_id)),
         { class: "location_return_link" }]
      end
    end
  end
end
