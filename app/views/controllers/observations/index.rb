# frozen_string_literal: true

# Action template for the Observations index.
#
# Composes the page chrome (project banner / observation buttons row
# when scoped to a project, container width, index title, action-nav,
# sorter, pagination), flashes the no-matches error when the query
# returned nothing, optionally renders the alternate-spellings alert
# (pattern-search-with-zero-results path), and renders the paginated
# `Components::Matrix::Table` grid of Observation thumbnails.
#
# `ObservationsController#render_index_view` overrides the
# `ApplicationController` default to render this class directly with
# explicit props.
module Views::Controllers::Observations
  class Index < Views::FullPageBase
    prop :query, ::Query::Observations
    prop :pagination_data, ::PaginationData
    prop :objects, _Array(::Observation)
    prop :user, _Nilable(::User), default: nil
    prop :project, _Nilable(::Project), default: nil
    # `[Name, Integer]` pairs from
    # `ObservationsController::Index#make_name_suggestions`. Only
    # populated on the pattern-search-with-zero-results path.
    prop :name_suggestions, _Nilable(_Array(_Tuple(::Name, Integer))),
         default: nil

    def view_template
      add_project_banner(@project) if @project
      add_project_observation_buttons if @project
      container_class(:full)
      add_index_title(@query)
      add_context_nav_when_results
      add_sorter(@query, controller.index_sort_options)
      add_pagination(@pagination_data)

      render_suggestions_alert if suggest_alternates?

      PaginatedResults { render_matrix }
    end

    private

    # Stash the Map / Images / Download / FieldSlips button row
    # into `content_for(:observation_buttons)` so the layout's project
    # chrome can place it under the banner.
    def add_project_observation_buttons
      content_for(:observation_buttons) do
        render(Views::Controllers::Projects::ObservationButtons.new(
                 project: @project, query: @query
               ))
      end
    end

    def add_context_nav_when_results
      return if @objects.empty?

      add_context_nav(
        Tab::Observation::IndexActions.new(
          query: @query, where: string_param(:where),
          q_param: q_param(@query), controller: controller
        )
      )
    end

    def suggest_alternates?
      @objects.empty? && @name_suggestions&.any?
    end

    def render_suggestions_alert
      render(
        Views::Controllers::Observations::Show::NameSuggestionsAlert.new(
          names: @name_suggestions
        )
      )
    end

    def render_matrix
      render(Components::Matrix::Table.new(
               objects: @objects,
               user: @user,
               cached: true,
               project: @project
             ))
    end
  end
end
