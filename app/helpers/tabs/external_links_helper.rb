# frozen_string_literal: true

# Custom View Helpers for External Links views
#
module Tabs
  module ExternalLinksHelper
    def new_external_link_tab(obs:, site:)
      InternalLink.new(
        :show_observation_add_link.l,
        new_external_link_path(id: obs.id, site: site.id),
        html_options: { icon: :add, class: "new_external_link_link_#{site.id}" }
      ).tab
    end

    def edit_external_link_tab(link:)
      InternalLink::Model.new(
        :EDIT.l, link,
        edit_external_link_path(id: link),
        html_options: { icon: :edit }
      ).tab
    end
  end
end
