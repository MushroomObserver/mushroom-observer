# frozen_string_literal: true

module Tabs
  module Locations
    module DescriptionsHelper
      # Migrated to `Tab::LocationDescription::*` Collection POROs.
      # Delegators below preserve the legacy `[title, url, opts]`
      # array shape for existing callers.

      def location_description_index_tabs(query:)
        ::Tab::LocationDescription::IndexActions.new(
          query: query, q_param: q_param(query),
          controller: controller
        ).map(&:to_a)
      end

      def location_description_form_new_tabs(description:)
        ::Tab::LocationDescription::FormNew.new(
          description: description
        ).map(&:to_a)
      end

      def location_description_form_edit_tabs(description:)
        ::Tab::LocationDescription::FormEdit.new(
          description: description
        ).map(&:to_a)
      end

      def location_description_form_permissions_tabs(description:)
        ::Tab::LocationDescription::FormPermissions.new(
          description: description
        ).map(&:to_a)
      end

      def location_description_version_tabs(description:, desc_title:)
        ::Tab::LocationDescription::VersionActions.new(
          description: description, desc_title: desc_title
        ).map(&:to_a)
      end
    end
  end
end
