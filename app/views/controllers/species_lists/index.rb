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
      # Sort table lives on the controller — single source of
      # truth for both view rendering and `check_index_sorting`.
      add_sorter(@query, controller.index_sort_options)
      add_pagination(@pagination_data)
      container_class(:wide)

      flash_error(@error) if @error && @objects.empty?

      paginated_results { render_list }
    end

    private

    def render_list
      return unless @objects.any?

      div(class: "list-group") do
        @objects.each do |species_list|
          render(Views::Controllers::SpeciesLists::Listing.new(
                   species_list: species_list, project: @project
                 ))
        end
      end
    end
  end
end
