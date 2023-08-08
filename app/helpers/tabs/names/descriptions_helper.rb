# frozen_string_literal: true

# html used in tabsets
module Tabs
  module Names
    module DescriptionsHelper
      def name_description_index_links(query:)
        [
          [*coerced_query_link(query, Name), { class: "name_query_link" }]
        ]
      end

      def name_description_form_new_links(description:)
        [
          [:cancel_and_show.t(type: :name),
           add_query_param(name_path(description.name_id)),
           { class: "name_return_link" }]
        ]
      end

      def name_description_form_edit_links(description:, user:)
        tabs = [
          [:show_object.t(type: :name),
           add_query_param(name_path(description.name_id)),
           { class: "name_return_link" }],
          [:cancel_and_show.t(type: :name_description),
           add_query_param(name_description_path(description.id)),
           { class: "name_description_return_link" }]
        ]
        if description.is_admin?(user) || in_admin_mode?
          tabs << [:show_description_adjust_permissions.t,
                   edit_name_description_permissions_path(description.id),
                   { class: "adjust_permissions_link" }]
        end
        tabs
      end

      def name_description_form_permissions_links(description:)
        [
          [:show_object.t(type: :name),
           add_query_param(name_path(description.name_id)),
           { class: "name_return_link" }],
          [:show_object.t(type: :name_description),
           add_query_param(name_description_path(description.id)),
           { class: "name_description_return_link" }]
        ]
      end

      def name_description_version_links(description:, desc_title:)
        [
          [:show_name_description.t(description: desc_title),
           add_query_param(name_description_path(description.id)),
           { class: "name_description_return_link" }]
        ]
      end
    end
  end
end
