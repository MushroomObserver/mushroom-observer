# frozen_string_literal: true

# html used in tabsets
module Tabs
  module Locations
    module DescriptionsHelper
      def location_description_index_links
        links = [
          [:list_place_names_map.t, add_query_param(map_locations_path)],
          [:all_objects.t(type: :location), locations_path]
        ]
        links << coerced_query_link(query, Location)
        links
      end

      def location_description_form_new_links(description)
        [
          [:cancel_and_show.t(type: :location),
           add_query_param(description.location.show_link_args)]
        ]
      end

      def location_description_form_edit_links(description)
        [
          [:show_object.t(type: :location),
           add_query_param(description.location.show_link_args)],
          [:cancel_and_show.t(type: :location_description),
           add_query_param(description.show_link_args)]
        ]
      end

      def location_description_form_permissions_links(description)
        [
          [:show_object.t(type: :location),
           add_query_param(location_path(description.location_id))],
          [:show_object.t(type: :location_description),
           add_query_param(location_description_path(description.id))]
        ]
      end

      def location_description_version_links(description, desc_title)
        [:show_location_description.t(description: desc_title),
         add_query_param(location_description_path(description.id))]
      end
    end
  end
end
