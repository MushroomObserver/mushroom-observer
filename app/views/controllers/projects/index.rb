# frozen_string_literal: true

# Action template for the Projects index. Replaces
# `app/views/controllers/projects/index.html.erb`.
#
# `ProjectsController#render_index_view` overrides the
# `ApplicationController` default to render this class directly with
# explicit props.
module Views::Controllers::Projects
  class Index < Views::Base
    prop :query, ::Query::Projects
    prop :pagination_data, ::PaginationData
    prop :objects,
         _Union(Array, ::ActiveRecord::Relation,
                ::ActiveRecord::Associations::CollectionProxy)
    prop :error, _Nilable(String), default: nil

    def view_template
      add_index_title(@query)
      add_context_nav(Tab::Project::IndexNav.new)
      add_sorter(@query, controller.index_sort_options)
      add_pagination(@pagination_data)
      container_class(:text_image)

      flash_error(@error) if @error && @objects.empty?

      paginated_results { render_list_group }
    end

    private

    def render_list_group
      render(Components::ListGroup.new) do |list|
        @objects.each do |project|
          list.item(class: "d-flex align-items-start") do
            render(ListItem.new(project: project))
          end
        end
      end
    end
  end
end
