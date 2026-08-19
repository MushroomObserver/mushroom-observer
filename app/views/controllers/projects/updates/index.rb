# frozen_string_literal: true

module Views::Controllers::Projects::Updates
  class Index < Views::FullPageBase
    prop :project, ::Project
    prop :user, ::User
    prop :observations, _Array(::Observation)
    prop :pagination, ::PaginationData
    prop :request_url, String
    prop :current_count, Integer
    prop :show_excluded, _Boolean

    # `results:` bundles four values the controller computes together
    # (see Projects::UpdatesController#build_index_results) -- split
    # them into individual props here so callers still pass one hash.
    def initialize(results:, **)
      super(observations: results[:observations],
            pagination: results[:pagination],
            request_url: results[:request_url],
            current_count: results[:current_count],
            **)
    end

    def view_template
      add_project_banner(@project)
      container_class(:full)
      add_page_title(:project_updates_title.t)

      render_toolbar
      render_pagination
      render_matrix
      render_pagination
    end

    private

    def render_toolbar
      div(class: "d-flex justify-content-between " \
                 "align-items-center mb-3 flex-wrap") do
        render_count_and_toggle
        div { render_add_all_button }
      end
    end

    def render_count_and_toggle
      div(class: "d-flex align-items-center") do
        span(id: "project_updates_count", class: "mr-3") do
          plain(count_label)
        end
        render(ExcludedToggleForm.new(
                 project: @project, show_excluded: @show_excluded
               ))
      end
    end

    def count_label
      count_label_key.t(count: @current_count)
    end

    def count_label_key
      return :project_updates_excluded_count if @show_excluded

      :project_updates_count
    end

    def render_add_all_button
      Button(
        type: :post,
        name: :project_updates_add_all.t,
        target: add_all_project_updates_path(
          project_id: @project.id,
          project_exclusions: { show: @show_excluded }
        ),
        confirm: :project_updates_confirm_add_all.t
      )
    end

    def render_pagination
      return unless @pagination.num_pages > 1

      render(Views::Layouts::Header::IndexPaginationNav.new(
               pagination_data: @pagination,
               request_url: @request_url
             ))
    end

    def render_matrix
      render(Components::Matrix::Table.new) do
        @observations.each do |obs|
          render(Components::Matrix::Box.new(
                   user: @user, object: obs
                 )) do
            render(Views::Controllers::Projects::Updates::ObsFooter.new(
                     project: @project, obs: obs,
                     show_excluded: @show_excluded
                   ))
          end
        end
      end
    end
  end
end
