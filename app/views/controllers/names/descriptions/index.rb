# frozen_string_literal: true

module Views::Controllers::Names::Descriptions
  # Paginated list of NameDescription records — one striped table
  # of links to each description's show page.
  class Index < Views::FullPageBase
    prop :query, ::Query
    prop :descriptions, _Array(::NameDescription)
    prop :pagination_data, ::PaginationData

    def view_template
      register_chrome

      paginated_results { render_table if @descriptions.any? }
    end

    private

    def register_chrome
      add_index_title(@query)
      add_context_nav(::Tab::NameDescription::IndexActions.new(
                        query: @query, controller: controller
                      ))
      add_sorter(@query, controller.index_sort_options)
      add_pagination(@pagination_data)
    end

    def render_table
      render(::Components::Table.new(@descriptions,
                                     class: "table-striped",
                                     show_headers: false)) do |tbl|
        tbl.column("") do |desc|
          link_to(name_description_path(desc.id)) do
            trusted_html(desc.format_name.t)
          end
        end
      end
    end
  end
end
