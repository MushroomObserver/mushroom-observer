# frozen_string_literal: true

module Views::Controllers::Projects::FieldSlips
  # Phlex view for the field slips form page.
  # Replaces field_slips/new.html.erb.
  class New < Views::Base
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
      render(Views::Controllers::Projects::FieldSlips::Form.new(
               FormObject::ProjectFieldSlip.new(
                 field_slips: default_count
               ),
               project: @project
             ))
    end

    # Each `<tr>` is a Stimulus root rendered by `TrackerRow` —
    # `data-controller="field-slip-job"` + per-tracker data attrs the
    # JS uses to mutate cells in place as job state changes. The
    # `tbody#field_slip_job_trackers` is also a Turbo Stream target
    # (`field_slips_controller#create` does
    # `turbo_stream.prepend(:field_slip_job_trackers) { ... }` to
    # append a newly-created tracker without a full page refresh).
    #
    # Uses `Components::Table`'s row mode: `column(header, …)`
    # defines just the `<th>` chrome; `row { |tracker| … }` renders
    # the entire `<tr>` per tracker via `TrackerRow`.
    def render_tracker_table
      render(Components::Table.new(
               @project.trackers.order(id: :desc),
               class: "mt-3", tbody_id: "field_slip_job_trackers"
             )) do |table|
        define_tracker_columns(table)
        table.row do |tracker|
          render(TrackerRow.new(tracker: tracker, user: @user))
        end
      end
    end

    def define_tracker_columns(table)
      table.column(:FILENAME.t, scope: "col")
      table.column(:USER.t, scope: "col", class: "text-center")
      table.column(:SECONDS.t, scope: "col", class: "text-center")
      table.column(:PAGES.t, scope: "col", class: "text-center")
      table.column(:STATUS.t, scope: "col", class: "text-right")
    end
  end
end
