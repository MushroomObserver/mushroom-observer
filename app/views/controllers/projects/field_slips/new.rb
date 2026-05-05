# frozen_string_literal: true

module Views
  module Controllers
    module Projects
      module FieldSlips
        # Phlex view for the field slips form page.
        # Replaces field_slips/new.html.erb.
        class New < Views::Base
          register_output_helper :add_page_title
          register_output_helper :link_to_object, mark_safe: true
          register_value_helper :container_class

          def initialize(project:, user:, field_slip_max:)
            super()
            @project = project
            @user = user
            @field_slip_max = field_slip_max
          end

          def view_template
            add_page_title(page_title)
            container_class(:text_image)

            div(class: "mt-3 pb-2") do
              render_max_info
              render_form
              render_tracker_table if member?
            end
          end

          private

          def page_title
            [
              :field_slips_for_project_title.t,
              link_to_object(@project),
              :PROJECT.t
            ].join(" ")
          end

          def default_count
            @field_slip_max.zero? ? 0 : 6
          end

          def member?
            @project.member?(User.current)
          end

          def render_max_info
            div do
              plain(
                :field_slips_max_for_project.t(
                  max: @field_slip_max
                )
              )
            end
          end

          def render_form
            render(Components::ProjectFieldSlipForm.new(
                     FormObject::ProjectFieldSlip.new(
                       field_slips: default_count
                     ),
                     project: @project
                   ))
          end

          def render_tracker_table
            table(class: "table mt-3") do
              render_tracker_header
              tbody(id: "field_slip_job_trackers") do
                render_tracker_rows
              end
            end
          end

          def render_tracker_header
            thead do
              tr do
                th(scope: "col") { plain(:FILENAME.t) }
                th(scope: "col", class: "text-center") do
                  plain(:USER.t)
                end
                th(scope: "col", class: "text-center") do
                  plain(:SECONDS.t)
                end
                th(scope: "col", class: "text-center") do
                  plain(:PAGES.t)
                end
                th(scope: "col", class: "text-right") do
                  plain(:STATUS.t)
                end
              end
            end
          end

          def render_tracker_rows
            @project.trackers.order(id: :desc).each do |t|
              render(
                Components::ProjectFieldSlipTrackerRow.new(
                  tracker: t, user: @user
                )
              )
            end
          end
        end
      end
    end
  end
end
