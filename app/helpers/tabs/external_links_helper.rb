# frozen_string_literal: true

# Custom View Helpers for External Links views
#
module Tabs
  module ExternalLinksHelper
    def new_external_link_tab(obs:, site:)
      [:ADD.l,
       new_external_link_path(id: obs, site: site),
       { class: tab_id(__method__.to_s), icon: :add }]
    end

    def edit_external_link_tab(link:)
      [:EDIT.l,
       edit_external_link_path(id: link),
       { class: tab_id(__method__.to_s), icon: :edit }]
    end
  end
end
