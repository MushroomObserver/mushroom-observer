# frozen_string_literal: true

# html used in tabsets
module Tabs
  module Names
    module DescriptionsHelper
      def name_description_index_tabs(query:)
        [coerced_name_query_tab(query)]
      end

      def name_description_form_new_tabs(description:)
        [object_return_tab(description.name)]
      end

      def name_description_form_edit_tabs(description:, user:)
        links = [
          object_return_tab(description.name, :show_object.t(type: :name)),
          object_return_tab(description)
        ]
        if description.is_admin?(user) || in_admin_mode?
          links << adjust_description_permissions_tab(description, :name, true)
        end
        links
      end

      def name_description_form_permissions_tabs(description:)
        [
          object_return_tab(description.name),
          object_return_tab(description,
                            :show_object.t(type: :name_description))
        ]
      end

      def name_description_version_tabs(description:, desc_title:)
        [object_return_tab(description,
                           :show_name_description.t(description: desc_title))]
      end
    end
  end
end
