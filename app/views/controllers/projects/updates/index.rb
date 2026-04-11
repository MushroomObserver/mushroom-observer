# frozen_string_literal: true

module Views
  module Controllers
    module Projects
      module Updates
        class Index < Views::Base
          register_output_helper :add_project_banner
          register_output_helper :add_page_title
          register_value_helper :container_class

          def initialize(project:, user:, results:)
            super()
            @project = project
            @user = user
            @observations = results[:observations]
            @pagination = results[:pagination]
            @member_ids = results[:member_ids]
            @base_url = results[:base_url]
            @new_count = results[:new_count]
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
                       "align-items-center mb-3") do
              span do
                :project_updates_count.t(count: @new_count)
              end
              div { render_bulk_buttons }
            end
          end

          def render_bulk_buttons
            button_to(
              :project_updates_add_all.t,
              add_all_project_updates_path(
                project_id: @project.id
              ),
              method: :post,
              class: "btn btn-default mr-2",
              form: { data: {
                turbo_confirm: :project_updates_confirm_add_all.t
              } }
            )
            button_to(
              :project_updates_clear.t,
              clear_project_updates_path(
                project_id: @project.id
              ),
              method: :delete,
              class: "btn btn-default",
              form: { data: {
                turbo_confirm: :project_updates_confirm_clear.t
              } }
            )
          end

          def render_pagination
            return unless @pagination.num_pages > 1

            render(Components::IndexPaginationNav.new(
                     pagination_data: @pagination,
                     request_url: @base_url,
                     form_action_url: @base_url,
                     q_params: nil,
                     letter_param: nil
                   ))
          end

          def render_matrix
            render(Components::MatrixTable.new) do
              @observations.each do |obs|
                render(Components::MatrixBox.new(
                         user: @user, object: obs
                       )) do
                  render(Components::Projects::ObsFooter.new(
                           project: @project, obs: obs,
                           in_project: @member_ids.include?(obs.id)
                         ))
                end
              end
            end
          end
        end
      end
    end
  end
end
