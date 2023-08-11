# frozen_string_literal: true

module Tabs
  module CoercedQueriesHelper
    def coerced_observation_query_link(query)
      [*coerced_query_link(query, Observation),
       { class: __method__.to_s }]
    end

    def coerced_location_query_link(query)
      [*coerced_query_link(query, Location),
       { class: __method__.to_s }]
    end

    def coerced_image_query_link(query)
      [*coerced_query_link(query, Image),
       { class: __method__.to_s }]
    end

    def coerced_name_query_link(query)
      [*coerced_query_link(query, Name),
       { class: __method__.to_s }]
    end

    def object_return_link(obj)
      [:cancel_and_show.t(type: obj.type_tag),
       add_query_param(obj.show_link_args),
       { class: "#{obj.type_tag}_return_link" }]
    end

    def show_object_link(obj)
      [:show_object.t(type: obj.type_tag),
       obj.show_link_args,
       { class: __method__.to_s }]
    end

    def show_parent_link(obj)
      [:show_object.t(type: obj.parent.type_tag),
       obj.parent.show_link_args,
       { class: __method__.to_s }]
    end
  end
end
