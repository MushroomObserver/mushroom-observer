# frozen_string_literal: true

module Tabs
  module GeneralHelper
    def search_tab_for(site_symbol, search_string)
      return unless (url = external_search_urls[site_symbol])

      InternalLink.new(
        site_symbol.to_s.titlecase, "#{url}#{search_string}",
        html_options: { id: "search_link_to_#{site_symbol}_#{search_string}" }
      ).tab
    end

    # Dictionary of urls for searches on external sites
    def external_search_urls
      {
        Google_Maps: "https://maps.google.com/maps?q=",
        Google_Search: "https://www.google.com/search?q=",
        Wikipedia: "https://en.wikipedia.org/w/index.php?search="
      }.freeze
    end

    def object_return_tab(obj, text = nil)
      text ||= :cancel_and_show.t(type: obj.type_tag)

      InternalLink::Model.new(
        text, obj, obj.show_link_args,
        html_options: { class: "#{obj.type_tag}_return_link" }
      ).tab
    end

    def show_object_tab(obj, text = nil)
      text ||= :show_object.t(type: obj.type_tag)

      InternalLink::Model.new(
        text, obj, obj.show_link_args,
        html_options: { class: "#{obj.type_tag}_link" }
      ).tab
    end

    def show_parent_tab(obj, text = nil)
      text ||= :show_object.t(type: obj.parent.type_tag)

      InternalLink::Model.new(
        text, obj, obj.parent.show_link_args,
        html_options: { class: "parent_#{obj.parent.type_tag}_link" }
      ).tab
    end

    def object_index_tab(obj, text = nil)
      text ||= :list_objects.t(type: obj.type_tag)

      InternalLink::Model.new(
        text, obj, add_query_param(obj.index_link_args),
        html_options: { class: "#{obj.type_tag.to_s.pluralize}_index_link" }
      ).tab
    end
  end
end
