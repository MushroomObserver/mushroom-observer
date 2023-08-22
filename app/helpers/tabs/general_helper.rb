# frozen_string_literal: true

module Tabs
  module GeneralHelper
    def coerced_observation_query_link(query)
      return unless query && (link = coerced_query_link(query, Observation))

      [*link, { class: __method__.to_s }]
    end

    def coerced_location_query_link(query)
      return unless query && (link = coerced_query_link(query, Location))

      [*link, { class: __method__.to_s }]
    end

    def coerced_image_query_link(query)
      return unless query && (link = coerced_query_link(query, Image))

      [*link, { class: __method__.to_s }]
    end

    def coerced_name_query_link(query)
      return unless query && (link = coerced_query_link(query, Name))

      [*link, { class: __method__.to_s }]
    end

    def object_return_link(obj, text = nil)
      text ||= :cancel_and_show.t(type: obj.type_tag)
      [text, add_query_param(obj.show_link_args),
       { class: "#{obj.type_tag}_return_link" }]
    end

    def show_object_link(obj, text = nil)
      text ||= :show_object.t(type: obj.type_tag)
      [text, add_query_param(obj.show_link_args),
       { class: "#{obj.type_tag}_link" }]
    end

    def show_parent_link(obj, text = nil)
      text ||= :show_object.t(type: obj.parent.type_tag)
      [text, add_query_param(obj.parent.show_link_args),
       { class: "parent_#{obj.parent.type_tag}_link" }]
    end

    def object_index_link(obj, text = nil)
      text ||= :list_objects.t(type: obj.type_tag)
      [text, add_query_param(obj.index_link_args),
       { class: "#{obj.type_tag.to_s.pluralize}_index_link" }]
    end
  end
end
