# frozen_string_literal: true

module Views::Controllers::InatImports
  # Status panel for an iNat import. Rendered on the show page and
  # broadcast-replaced on every InatImport update via after_update_commit.
  # Inherits from Components::Base (not Views::FullPageBase) so it can be
  # rendered outside a request context via ApplicationController.renderer.
  class Status < Components::Base
    prop :inat_import, ::InatImport

    def view_template
      div(
        id: "inat_import_#{@inat_import.id}",
        data: { controller: "inat-import",
                inat_import_status_value: @inat_import.state,
                inat_import_elapsed_value: @inat_import.elapsed_time.to_i,
                inat_import_remaining_value:
                  @inat_import.estimated_remaining_time&.to_i,
                inat_import_status_url_value:
                  inat_import_path(@inat_import) }
      ) do
        render_content
        render_error_alert
        render_alert
      end
    end

    private

    def render_content
      render(::Components::ContentPadded.new do
        render_summary_paragraph
        render_actions
        render_timing_details
      end)
    end

    def render_actions
      div(class: "mt-2 mb-2") do
        render(Components::Button.new(
                 type: :get,
                 name: :results.l,
                 target: results_observations_path,
                 **results_disabled_attrs
               ))
        unless @inat_import.Done?
          whitespace
          render(::Components::Button.new(
                   type: :put,
                   name: :CANCEL.l,
                   target: inat_import_cancel_path(id: @inat_import)
                 ))
        end
      end
    end

    def results_disabled_attrs
      return {} if results_enabled?

      { class: "disabled", aria: { disabled: "true" }, tabindex: "-1" }
    end

    def results_enabled?
      @inat_import.Done? && @inat_import.imported_count.to_i.positive?
    end

    def results_observations_path
      observations_path(
        pattern: "user:#{@inat_import.user.id} created:" \
                 "#{Time.zone.today}-#{Time.zone.tomorrow}"
      )
    end

    def render_timing_details
      render_started_line
      render_elapsed_line
      render_remaining_line
      render_ended_line
      render_error_line
      render_ignored_section if show_ignored_section?
    end

    def render_summary_paragraph
      p do
        render_status_line
        br
        render_imported_line
      end
    end

    def render_status_line
      span(class: "font-weight-bold") { "#{:STATUS.l}: " }
      span { plain(@inat_import.state.to_s) }
    end

    def render_imported_line
      span(class: "font-weight-bold") { "#{:imported.l}: " }
      span { plain(@inat_import.imported_count.to_s) }
      render_importables_count if @inat_import.total_importables.to_i.positive?
    end

    def render_importables_count
      whitespace
      plain(:of.l)
      whitespace
      plain(@inat_import.total_importables.to_s)
      whitespace
      plain(:observations.l)
    end

    def render_started_line
      span(class: "font-weight-bold") do
        "#{:inat_import_tracker_started.l}: "
      end
      span do
        plain(@inat_import.started_at&.strftime("%Y-%m-%d %H:%M:%S %z").to_s)
      end
      br
    end

    def render_elapsed_line
      span(class: "font-weight-bold") do
        "#{:inat_import_tracker_elapsed_time.l}: "
      end
      span(data: { inat_import_target: "elapsed" }) do
        plain(format_seconds(@inat_import.elapsed_time))
      end
      br
    end

    def render_remaining_line
      span(class: "font-weight-bold") do
        "#{:inat_import_tracker_estimated_remaining_time.l}: "
      end
      span(data: { inat_import_target: "remaining" }) do
        plain(format_seconds(remaining_time))
      end
      br
    end

    def render_ended_line
      return unless (ended = @inat_import.ended_at)

      span(class: "font-weight-bold") do
        "#{:ended.l}: "
      end
      span { plain(ended.to_s) }
      br
    end

    def render_error_line
      return if @inat_import.response_errors.blank?

      span(class: "font-weight-bold") { plain("#{:ERRORS.l}: ") }
    end

    def show_ignored_section?
      @inat_import.Done? && @inat_import.ignored_total_count.positive?
    end

    def render_ignored_section
      render(::Components::Alert.new(level: :info, class: "mt-3")) do
        h5 { plain(:inat_import_tracker_ignored_heading.l) }
        render_ignored_row(:inat_import_tracker_ignored_not_importable,
                           @inat_import.ignored_not_importable_count)
        render_ignored_row(:inat_import_tracker_ignored_already_imported,
                           @inat_import.ignored_already_imported_count)
        render_ignored_row(:inat_import_tracker_ignored_date_missing,
                           @inat_import.ignored_date_missing_count)
      end
    end

    def render_ignored_row(caption_key, count)
      return unless count.to_i.positive?

      div(class: "mb-1") do
        b { plain("#{caption_key.l}: ") }
        plain(count.to_s)
      end
    end

    def render_error_alert
      errors = @inat_import.response_errors.to_s.split("\n")
      return unless errors.any?

      render(::Components::Alert.new(level: :warning) do
        errors.each_with_index do |error, i|
          br if i.positive?
          plain(error)
        end
      end)
    end

    def render_alert
      render(::Components::Alert.new(
               message: alert_message,
               level: alert_level,
               class: "mt-3"
             ))
    end

    def alert_message
      return :inat_import_tracker_leave_page.l unless @inat_import.Done?
      if @inat_import.imported_count.to_i.zero?
        return :inat_import_nothing_imported.l
      end
      return :inat_import_tracker_done_with_errors.l if errors?

      :inat_import_tracker_done.l
    end

    def alert_level
      return :info unless @inat_import.Done?
      return :warning if errors?
      return :success if @inat_import.imported_count.to_i.positive?

      :info
    end

    def errors?
      @inat_import.response_errors.present?
    end

    def remaining_time
      @inat_import.Done? ? 0 : @inat_import.estimated_remaining_time
    end

    def format_seconds(seconds)
      return :calculating.l if seconds.nil?

      hours = seconds / 3600
      minutes = (seconds % 3600) / 60
      secs = seconds % 60
      # Phlex's `format(...)` shadows Kernel#format — use sprintf instead.
      sprintf("%02d:%02d:%02d", hours, minutes, secs) # rubocop:disable Style/FormatString
    end
  end
end
