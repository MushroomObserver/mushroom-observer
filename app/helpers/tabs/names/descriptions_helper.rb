# frozen_string_literal: true

module Tabs
  module Names
    module DescriptionsHelper
      # Migrated to `Tab::NameDescription::*` Collection POROs.
      # `form_edit` retains a delegator append for the "adjust
      # permissions" tab, which still comes from the unconverted
      # `descriptions_helper.rb`.

      def name_description_index_tabs(query:)
        ::Tab::NameDescription::IndexActions.new(
          query: query, controller: controller
        ).map(&:to_a)
      end

      def name_description_form_new_tabs(description:)
        ::Tab::NameDescription::FormNew.new(
          description: description
        ).map(&:to_a)
      end

      def name_description_form_edit_tabs(description:, user:)
        tabs = ::Tab::NameDescription::FormEdit.new(
          description: description
        ).map(&:to_a)
        if description.is_admin?(user) || in_admin_mode?
          tabs << adjust_description_permissions_tab(description, :name, true)
        end
        tabs
      end

      def name_description_form_permissions_tabs(description:)
        ::Tab::NameDescription::FormPermissions.new(
          description: description
        ).map(&:to_a)
      end

      def name_description_version_tabs(description:, desc_title:)
        ::Tab::NameDescription::VersionActions.new(
          description: description, desc_title: desc_title
        ).map(&:to_a)
      end
    end
  end
end
