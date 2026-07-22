# frozen_string_literal: true

class Components::Matrix::Box
  # Footer rendering methods for Components::Matrix::Box.
  #
  # Included by Box to keep the footer slot logic in its own file.
  # Methods here call `panel.with_footer(classes:) { ... }` on the
  # Panel passed in from `render_object_layout`.
  module Footer
    private

    def render_log_footer(panel)
      return unless @data[:detail].present? || @data[:time].present?

      panel.with_footer(classes: "log-footer") do
        render_footer_detail(@data[:detail])
        render_footer_time(@data[:time])
      end
    end

    def render_footer_detail(detail)
      return if detail.blank?

      if detail.is_a?(User)
        render_user_detail(detail)
      else
        div(class: "rss-detail small") { detail }
      end
    end

    def render_footer_time(time)
      return unless time

      div(
        class: "rss-what rss-updated-at small",
        data: { controller: "local-time",
                local_time_utc_value: time.utc.iso8601 }
      ) do
        time.display_time
      end
    end

    def render_user_detail(user)
      div(class: "rss-detail small") do
        plain("#{:list_users_joined.l}: #{user.created_at.web_date}")
        br
        plain("#{:list_users_contribution.l}: #{user.contribution}")
        br
        link_to(:observations.ti, observations_path(by_user: user.id))
      end
    end

    def render_identify_footer(panel)
      return unless @observation_view

      panel.with_footer(
        classes: "panel-active text-center position-relative"
      ) do
        render(Components::Image::MarkAsReviewedToggle.new(
                 observation_view: @observation_view,
                 selector: "box_reviewed",
                 label_class: "stretched-link"
               ))
      end
    end

    def render_project_admin_footer(panel)
      return unless show_project_exclude_button?

      panel.with_footer(classes: "text-center") do
        Button(
          type: :post,
          name: :exclude.ti,
          target: exclude_observation_project_update_path(
            project_id: @project.id, id: @data[:what].id
          ),
          size: :sm
        )
      end
    end

    def render_custom_footer(panel, &block)
      panel.with_footer(classes: "text-center", &block)
    end

    def show_project_exclude_button?
      @project && @data && @data[:type] == :observation &&
        @project.is_admin?(@user)
    end
  end
end
