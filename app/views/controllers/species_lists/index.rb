# frozen_string_literal: true

# Action view for the species_list index page. Sets the project
# banner when scoped to a project, page chrome (title, sort, pagination,
# container width), then renders a list of `Listing` rows.
module Views::Controllers::SpeciesLists
  class Index < Views::Base
    def initialize(query:, pagination_data:, objects:,
                   project: nil, error: nil)
      super()
      @query = query
      @pagination_data = pagination_data
      @objects = objects
      @project = project
      @error = error
    end

    def view_template
      add_project_banner(@project) if @project
      add_index_title(@query)
      # Sort table lives on the controller — single source of truth.
      add_sorter(@query, controller.index_sort_options)
      add_pagination(@pagination_data)
      container_class(:wide)

      flash_error(@error) if @error && @objects.empty?

      paginated_results { render_list }
    end

    private

    def render_list
      return unless @objects.any?

      # The d-flex / justify-content-between / align-items-start
      # classes used to live on `Listing`'s outer wrapper. After
      # moving the row wrapping into `Components::ListGroup::Base#item`,
      # those layout classes ride on the item itself.
      render(Components::ListGroup::Base.new) do |list|
        @objects.each do |species_list|
          list.item(
            class: "d-flex justify-content-between align-items-start"
          ) do
            render(Listing.new(
                     species_list: species_list, project: @project
                   ))
          end
        end
      end
    end
  end
end
