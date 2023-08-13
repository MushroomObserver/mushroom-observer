# frozen_string_literal: true

# html used in tabsets
module Tabs
  module Names
    module DescriptionsHelper
      def name_description_index_links(query:)
        [coerced_name_query_link(query)]
      end

      def name_description_form_new_links(description:)
        [description_name_return_link(description)]
      end

      def name_description_form_edit_links(description:, user:)
        links = [
          object_return_link(description.name, :show_object.t(type: :name)),
          object_return_link(description)
        ]
        if description.is_admin?(user) || in_admin_mode?
          links << adjust_description_permissions_link(description, :name, true)
        end
        links
      end

      def name_description_form_permissions_links(description:)
        [
          object_return_link(description.name),
          object_return_link(description,
                             :show_object.t(type: :name_description))
        ]
      end

      def name_description_version_links(description:, desc_title:)
        [object_return_link(description,
                            :show_name_description.t(description: desc_title))]
      end
    end
  end
end
