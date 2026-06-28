# frozen_string_literal: true

module Views::Controllers::InatImports::JobTrackers
  # Current-status block for an iNat import job.
  class Current < Views::Base
    prop :tracker, ::InatImportJobTracker

    def view_template
      div(id: "current_status_#{@tracker.id}",
          data: { inat_import_job_target: "current",
                  status: @tracker.status }) do
        render_summary_paragraph
        render_started_line
        render_elapsed_line
        render_remaining_line
        render_ended_line
        render_error_line
        render_ignored_section if show_ignored_section?
        render(::Components::Alert.new(
                 message: @tracker.help, level: :warning, class: "mt-3"
               ))
        br
      end
    end

    private

    def render_summary_paragraph
      p do
        render_status_line
        br
        render_imported_line
      end
    end

    def render_status_line
      span(class: "font-weight-bold") { "#{:STATUS.l}: " }
      span { plain(@tracker.status.to_s) }
    end

    def render_imported_line
      span(class: "font-weight-bold") { "#{:inat_import_imported.t}: " }
      span { plain(@tracker.imported_count.to_s) }
      span(class: "mr-2") { plain(" #{:of.t}") }
      span { plain(@tracker.importables.to_s) }
      span { plain(" #{:observations.t}") }
    end

    def render_started_line
      span(class: "font-weight-bold") do
        "#{:inat_import_tracker_started.l}: "
      end
      span do
        plain(@tracker.created_at&.strftime("%Y-%m-%d %H:%M:%S %z").to_s)
      end
      br
    end

    def render_elapsed_line
      span(class: "font-weight-bold") do
        "#{:inat_import_tracker_elapsed_time.l}: "
      end
      span { plain(time_in_hours_minutes_seconds(@tracker.elapsed_time)) }
      br
    end

    def render_remaining_line
      span(class: "font-weight-bold") do
        "#{:inat_import_tracker_estimated_remaining_time.l}: "
      end
      span { plain(remaining_time_in_hours_minutes_seconds(@tracker)) }
      br
    end

    def render_ended_line
      span(class: "font-weight-bold") do
        "#{:inat_import_tracker_ended.l}: "
      end
      span { plain(@tracker.ended_at.to_s) }
      br
    end

    def render_error_line
      span(class: "font-weight-bold") { plain(@tracker.error_caption.to_s) }
      span(class: "violation-highlight") do
        plain(@tracker.response_errors.to_s)
      end
      br
    end

    def show_ignored_section?
      @tracker.status == "Done" && @tracker.ignored_total_count.positive?
    end

    def render_ignored_section
      div(class: "mt-3") do
        h5 { plain(:inat_import_tracker_ignored_heading.l) }
        render_ignored_row(:inat_import_tracker_ignored_not_importable,
                           @tracker.ignored_not_importable_count)
        render_ignored_row(:inat_import_tracker_ignored_already_imported,
                           @tracker.ignored_already_imported_count)
        render_ignored_row(:inat_import_tracker_ignored_date_missing,
                           @tracker.ignored_date_missing_count)
      end
    end

    def render_ignored_row(caption_key, count)
      return unless count.positive?

      div(class: "mb-1") do
        b { plain("#{caption_key.l}: ") }
        plain(count.to_s)
      end
    end

    def remaining_time_in_hours_minutes_seconds(tracker)
      time = tracker.status == "Done" ? 0 : tracker.estimated_remaining_time
      time_in_hours_minutes_seconds(time)
    end

    def time_in_hours_minutes_seconds(seconds)
      return :inat_import_tracker_calculating_time.l if seconds.nil?

      hours = seconds / 3600
      minutes = (seconds % 3600) / 60
      seconds %= 60
      # Phlex's `format(...)` method shadows Kernel#format inside
      # view bodies, so use `sprintf` instead (Phlex doesn't have
      # one). Elapsed time can exceed 24 hours for a long import,
      # which is why `Time.at(s).strftime("%H:%M:%S")` doesn't
      # work here.
      sprintf("%02d:%02d:%02d", hours, minutes, seconds) # rubocop:disable Style/FormatString
    end
  end
end
