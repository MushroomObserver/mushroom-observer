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
      add_sorter(@query, sort_options)
      add_pagination(@pagination_data)
      container_class(:wide)

      flash_error(@error) if @error && @objects.empty?

      paginated_results { render_list }
    end

    private

    def sort_options
      rss_log = @query&.params&.dig(:order_by) == :rss_log
      [
        ["title",      :sort_by_title.t],
        ["date",       :sort_by_date.t],
        ["user",       :sort_by_user.t],
        ["created_at", :sort_by_created_at.t],
        [(rss_log ? "rss_log" : "updated_at"), :sort_by_updated_at.t]
      ]
    end

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
