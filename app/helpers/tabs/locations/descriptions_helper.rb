# frozen_string_literal: true

# html used in tabsets
module Tabs
  module Locations
    module DescriptionsHelper
      def location_description_index_links(query:)
        [
          map_locations_link,
          locations_index_link,
          coerced_location_query_link(query)
        ]
      end

      def location_description_form_new_links(description:)
        [object_return_link(description.location)]
      end

      def location_description_form_edit_links(description:)
        [
          object_return_link(description.location),
          object_return_link(description)
        ]
      end

      def location_description_form_permissions_links(description:)
        [
          object_return_link(description.location),
          object_return_link(description,
                             :show_object.t(type: :location_description))
        ]
      end

      def location_description_version_links(description:, desc_title:)
        [
          object_return_link(
            description,
            :show_location_description.t(description: desc_title)
          )
        ]
      end
    end
  end
end
