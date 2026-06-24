# frozen_string_literal: true

# Action template for the Projects index.
#
# `ProjectsController#render_index_view` overrides the
# `ApplicationController` default to render this class directly with
# explicit props.
module Views::Controllers::Projects
  class Index < Views::FullPageBase
    prop :query, ::Query::Projects
    prop :pagination_data, ::PaginationData
    prop :objects, _Array(::Project)

    def view_template
      add_index_title(@query)
      add_context_nav(Tab::Project::IndexNav.new)
      add_sorter(@query, controller.index_sort_options)
      add_pagination(@pagination_data)
      container_class(:text_image)

      render(::Components::PaginatedResults.new) { render_list_group }
    end

    private

    def render_list_group
      render(Components::ListGroup::Base.new) do |list|
        @objects.each do |project|
          list.item(class: "d-flex align-items-start") do
            render(ListItem.new(project: project))
          end
        end
      end
    end
  end
end
