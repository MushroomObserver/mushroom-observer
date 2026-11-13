# frozen_string_literal: true

module Views::Controllers::Names::Descriptions
  # Index of NameDescriptions — a striped table of links to each
  # description's show page: the Name's name, the description's type
  # (Public/User's/Draft/etc.), and an id badge.
  class Index < Views::FullPageBase
    prop :query, ::Query
    prop :descriptions, _Array(::NameDescription)
    prop :pagination_data, ::PaginationData

    def view_template
      register_chrome

      PaginatedResults do
        render_table if @descriptions.any?
      end
    end

    private

    def register_chrome
      container_class(:full)
      add_index_title(@query)
      add_context_nav(::Tab::NameDescription::IndexActions.new(
                        query: @query, controller: controller
                      ))
      add_sorter(@query, controller.index_sort_options)
      add_pagination(@pagination_data)
      add_descriptions_caption
    end

    # Puts "Descriptions" ahead of whatever filter caption
    # `add_index_title` set (or didn't -- the rubric alone just reads
    # "Names", with no indication this index is descriptions rather
    # than names themselves).
    def add_descriptions_caption
      content_for(:filters, flush: true) do
        capture do
          span { plain(:descriptions.ti) }
          render_filter_caption_if_present
        end
      end
    end

    def render_filter_caption_if_present
      klass = ::Views::Layouts::Header::IndexBar::FilterCaption
      return unless klass.filters_present?(@query)

      whitespace
      render(klass.new(query: @query))
    end

    def render_table
      Table(@descriptions,
            variant: :striped, identifier: "name-descriptions",
            class: "w-100") { |t| build_table_columns(t) }
    end

    def build_table_columns(table)
      table.column(:name.ti) { |desc| render_name_cell(desc) }
      table.column(:type.ti) { |desc| render_type_cell(desc) }
      table.column(:mo_id.t, align: :right, class: "text-nowrap") do |desc|
        IDBadge(object: desc, size: :md, extra_class: "mr-0")
      end
    end

    def render_name_cell(desc)
      trusted_html(desc.name.display_name(current_user).t)
    end

    def render_type_cell(desc)
      type_name = desc.partial_format_name.t
      Link(type: :get, name: type_name,
           target: name_description_path(desc.id)) do
        trusted_html(type_name)
      end
    end
  end
end
