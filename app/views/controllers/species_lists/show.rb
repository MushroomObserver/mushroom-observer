# frozen_string_literal: true

# Action view for the species_list show page. Sets project banner +
# show title + edit / interest icons + context-nav + pager / pagination
# + column layout, then renders the left column body: details panel,
# project-button row (download / map / observations / names / etc.),
# search box, observations list, comments, object footer.
module Views::Controllers::SpeciesLists
  class Show < Views::Base
    # rubocop:disable Metrics/ParameterLists
    # See `Edit#initialize` — action views forward whatever the page
    # needs; `ParameterLists` isn't on the CLAUDE.md "always refactor"
    # list.
    def initialize(species_list:, user:, query:, pagination_data:,
                   objects:, comments:, object_names:, project: nil)
      super()
      @species_list = species_list
      @user = user
      @query = query
      @pagination_data = pagination_data
      @objects = objects
      @comments = comments
      @object_names = object_names
      @project = project
    end
    # rubocop:enable Metrics/ParameterLists

    def view_template
      add_chrome
      div(class: "row") do
        div(class: content_for(:left_columns)) { render_left_column }
      end
    end

    private

    def add_chrome
      add_project_banner(@project) if @project
      add_show_title(@species_list)
      add_interest_icons(@user, @species_list)
      add_edit_icons(@species_list, @user)
      add_context_nav(
        ::Tab::SpeciesList::Show.new(
          list: @species_list,
          can_manage: permission?(@species_list),
          q_param: q_param
        )
      )
      # `add_pager_for` walks prev/next species_lists — not pages of
      # observations within this list (which `add_pagination` does).
      add_pager_for(@species_list)
      add_pagination(@pagination_data)
      container_class(:double)
      column_classes(:nine_three)
    end

    def render_left_column
      render(Views::Controllers::SpeciesLists::Details.new(
               species_list: @species_list, query: @query
             ))
      render_project_buttons
      render_list_search
      paginated_results { render_observations }
      render_comments
      render(Components::ObjectFooter.new(
               user: @user, obj: @species_list
             ))
    end

    def render_project_buttons
      div(id: "project_species_list_buttons") do
        trusted_html(
          project_species_list_buttons(@species_list, @query).safe_join
        )
      end
    end

    def render_list_search
      render(Components::ListSearch.new(
               object: @species_list,
               object_names: @object_names,
               project: @project
             ))
    end

    def render_observations
      div(class: "list-group") do
        if @objects.any?
          @objects.each { |obs| render_observation_row(obs) }
        else
          div { trusted_html(:species_list_show_no_members.tp) }
        end
      end
    end

    def render_observation_row(observation)
      render(Views::Controllers::SpeciesLists::Observation.new(
               observation: observation,
               user: @user,
               species_list: @species_list,
               image: observation.thumb_image.present?,
               remove: permission?(@species_list)
             ))
    end

    # `comments/comments_for_object` is still ERB — same wrap-in-
    # `trusted_html` pattern as `render_list_search` above.
    def render_comments
      trusted_html(
        view_context.render(
          partial: "comments/comments_for_object",
          locals: { object: @species_list, comments: @comments,
                    controls: @user, limit: nil }
        )
      )
    end
  end
end
