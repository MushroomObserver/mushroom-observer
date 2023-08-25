# frozen_string_literal: true

# html used in tabsets
module Tabs
  module Locations
    module DescriptionsHelper
      def location_description_index_tabs(query:)
        [
          map_locations_tab,
          locations_index_tab,
          coerced_location_query_tab(query)
        ]
      end

      def location_description_form_new_tabs(description:)
        [object_return_tab(description.location)]
      end

      def location_description_form_edit_tabs(description:)
        [
          object_return_tab(description.location),
          object_return_tab(description)
        ]
      end

      def location_description_form_permissions_tabs(description:)
        [
          object_return_tab(description.location),
          object_return_tab(description,
                            :show_object.t(type: :location_description))
        ]
      end

      def location_description_version_tabs(description:, desc_title:)
        [
          object_return_tab(
            description,
            :show_location_description.t(description: desc_title)
          )
        ]
      end
    end
  end
end
