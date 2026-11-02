# frozen_string_literal: true

module Views::Controllers::Locations
  module Descriptions
    # Index of LocationDescriptions — a striped table of links to each
    # description's show page: the Location's name, the description's
    # type (Public/User's/Draft/etc.), and an id badge.
    class Index < Views::FullPageBase
      prop :query, ::Query
      prop :descriptions, _Array(::LocationDescription)
      prop :pagination_data, ::PaginationData

      def view_template
        register_chrome

        PaginatedResults do
          render_table if @descriptions.any?
        end
      end

      private

      def register_chrome
        add_index_title(@query)
        add_context_nav(::Tab::LocationDescription::IndexActions.new(
                          query: @query, q_param: q_param(@query),
                          controller: controller
                        ))
        add_sorter(@query, controller.index_sort_options)
        add_pagination(@pagination_data)
        container_class(:wide)
      end

      def render_table
        Table(@descriptions,
              variant: :striped, identifier: "location-descriptions",
              class: "w-100") { |t| build_table_columns(t) }
      end

      def build_table_columns(table)
        table.column(:place.ti) { |desc| render_name_cell(desc) }
        table.column(:type.ti) { |desc| render_type_cell(desc) }
        table.column(:mo_id.t, class: "text-right") do |desc|
          IDBadge(object: desc, size: :md, extra_class: "mr-0")
        end
      end

      def render_name_cell(desc)
        trusted_html(desc.location.name.t)
      end

      def render_type_cell(desc)
        type_name = desc.partial_format_name.t
        Link(type: :get, name: type_name, target: desc.show_link_args) do
          trusted_html(type_name)
        end
      end
    end
  end
end
