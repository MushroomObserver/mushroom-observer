# frozen_string_literal: true

module Views::Controllers::Locations
  module Descriptions
    # Index of LocationDescriptions — a paginated list of links to each
    # description's show page.
    class Index < Views::Base
      prop :query, ::Query
      prop :descriptions, _Array(::LocationDescription)
      prop :pagination_data, ::PaginationData
      prop :error, _Nilable(::String), default: nil

      def view_template
        register_chrome
        flash_error(@error) if @error && @descriptions.empty?

        paginated_results { render_list if @descriptions.any? }
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

      def render_list
        render(::Components::ListGroup::Base.new) do |list|
          @descriptions.each do |desc|
            list.item do
              link_to(desc.show_link_args) { trusted_html(desc.format_name.t) }
            end
          end
        end
      end
    end
  end
end
