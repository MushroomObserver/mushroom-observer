# frozen_string_literal: true

module Views::Controllers::Locations
  module Undefined
    # Undefined-locations index — free-text Observation#where strings
    # with no matching Location record. Split out of the main Locations
    # index into a separate page.
    class Index < Views::FullPageBase
      # `[Observation, count]` pairs — one per unique unmatched
      # location string on the current page.
      prop :undef_data, _Array(_Tuple(::Observation, ::Integer))
      prop :pagination_data, ::PaginationData

      def view_template
        register_chrome

        Container(width: :text_image) do
          render_help
          PaginatedResults { render_list }
        end
      end

      private

      def register_chrome
        container_class(:full)
        add_page_title(:list_place_names_undef.t)
        add_context_nav(::Tab::Location::Index.new)
        content_for(:filters) do
          capture { div(class: "small") { plain(:list_place_names_undef.t) } }
        end
        add_pagination(@pagination_data)
      end

      def render_help
        ContentPadded(id: "undefined_locations_help") do
          plain(:list_place_names_undef_help.l)
          div(class: "text-right mt-3") do
            plain(:list_place_names_parenthetical.l)
          end
        end
      end

      def render_list
        ListGroup do |list|
          @undef_data.each { |obs, count| render_item(list, obs, count) }
        end
      end

      def render_item(list, obs, count)
        location_name = obs[:where]
        list.item(class: "d-flex align-items-start") do
          div(class: "flex-grow-1") do
            Link(type: :location, where: location_name)
            whitespace
            render_merge_link(location_name)
            whitespace
            render_define_link(location_name)
          end
          div(class: "obs-count-col") { plain("(#{count})") }
        end
      end

      def render_merge_link(location_name)
        Link(type: :get, class: "icon-text-gap",
             name: :list_place_names_merge.l,
             target: matching_locations_for_observations_path(
               where: location_name
             ),
             icon: :merge, show_label: :hidden,
             title: :list_place_names_undef_merge_tooltip.t,
             data: { title: :list_place_names_undef_merge_tooltip.t })
      end

      def render_define_link(location_name)
        Link(type: :get, class: "icon-text-gap",
             name: :list_observations_location_define.t,
             target: new_location_path(where: location_name),
             icon: :map, show_label: :hidden,
             title: :list_place_names_undef_define_tooltip.t,
             data: { title: :list_place_names_undef_define_tooltip.t })
      end
    end
  end
end
