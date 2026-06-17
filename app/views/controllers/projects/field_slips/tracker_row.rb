# frozen_string_literal: true

# Renders a table row for a field slip job tracker. Rendered from
# `Projects::FieldSlipsController` (via `field_slips/new.rb`) and
# also referenced from the top-level
# `FieldSlipJobTrackersController` — that second controller will
# reference this view by its full namespace.
module Views::Controllers::Projects::FieldSlips
  class TrackerRow < Views::Base
    def initialize(tracker:, user:)
      super()
      @tracker = tracker
      @user = user
    end

    def view_template
      tr(id: dom_id(@tracker), **tracker_data) do
        render_link_cell { render_field_slip_link }
        render_link_cell { render_user_link }
        render_elapsed_time_cell
        render_pages_cell
        render_status_cell
      end
    end

    private

    def dom_id(record)
      "field_slip_job_tracker_#{record.id}"
    end

    def tracker_data
      {
        data: {
          controller: "field-slip-job",
          status: FieldSlipJobTracker.statuses[@tracker.status],
          endpoint: field_slip_job_tracker_path(@tracker.id)
        }
      }
    end

    def render_link_cell(&block)
      td(data: { field_slip_job_target: "link" }, &block)
    end

    def render_elapsed_time_cell
      td(class: "text-center",
         data: { field_slip_job_target: "seconds" }) do
        plain(number_with_precision(
                @tracker.elapsed_time, precision: 1
              ))
      end
    end

    def render_pages_cell
      td(class: "text-center",
         data: { field_slip_job_target: "pages" }) do
        plain(@tracker.pages.to_s)
      end
    end

    def render_status_cell
      td(class: "text-right",
         data: { field_slip_job_target: "status" }) do
        plain(@tracker.status)
      end
    end

    def render_user_link
      return unless @tracker.user

      render(Components::Link::Object::User.new(
               user: @tracker.user_id, name: @tracker.user.login
             ))
    end

    # Inlined from `ProjectsHelper#field_slip_link` — this was the
    # only caller, and the helper's body is small enough that a
    # private method keeps the rendering logic local.
    def render_field_slip_link
      if @tracker.status == "Done" && @user == @tracker.user
        link_to(@tracker.filename, @tracker.link)
      else
        plain(@tracker.filename)
      end
    end
  end
end
