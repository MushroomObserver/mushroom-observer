# frozen_string_literal: true

module Views
  module Controllers
    module Projects
      module Updates
        class Index < Views::Base
          register_output_helper :add_project_banner
          register_output_helper :add_page_title
          register_value_helper :container_class

          def initialize(project:, user:, results:, show_excluded:)
            super()
            @project = project
            @user = user
            @observations = results[:observations]
            @pagination = results[:pagination]
            @base_url = results[:base_url]
            @current_count = results[:current_count]
            @show_excluded = show_excluded
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
              render_show_excluded_toggle
            end
          end

          def count_label
            count_label_key.t(count: @current_count)
          end

          def count_label_key
            return :project_updates_excluded_count if @show_excluded

            :project_updates_count
          end

          def render_show_excluded_toggle
            form(
              action: project_updates_path(project_id: @project.id),
              method: "get",
              class: "form-inline mb-0 show-excluded-form",
              data: { controller: "autosubmit",
                      autosubmit_delay_value: "0" }
            ) do
              label(class: "checkbox-inline") do
                input(type: "checkbox", name: "show_excluded", value: "1",
                      checked: @show_excluded,
                      data: { action: "change->autosubmit#submit" })
                plain(" #{:project_updates_show_excluded.t}")
              end
            end
          end

          def render_add_all_button
            button_to(
              :project_updates_add_all.t,
              add_all_project_updates_path(
                project_id: @project.id,
                show_excluded: @show_excluded
              ),
              method: :post,
              class: "btn btn-default",
              form: { data: {
                turbo_confirm: :project_updates_confirm_add_all.t
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
                           show_excluded: @show_excluded
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
