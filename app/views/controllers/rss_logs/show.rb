# frozen_string_literal: true

module Views::Controllers::RssLogs
  # Single-RssLog detail page — formatted list of log events plus a
  # link back to the targeted object.
  class Show < Views::FullPageBase
    prop :rss_log, ::RssLog

    def view_template
      render_page_chrome

      render_log_table if @rss_log.notes
      render_target_link
    end

    private

    def render_page_chrome
      add_page_title(:show_rss_log_title.t(title: @rss_log.unique_format_name))
      add_pager_for(@rss_log)
      container_class(:text_image)
      content_padding(:no_panels)
    end

    def render_log_table
      Table(log_rows) do |t|
        t.column(:date.ti, class: "text-nowrap align-text-top") do |row|
          row[2].web_time
        end
        t.column(:change.ti) { |row| trusted_html(row[0].t(row[1])) }
      end
    end

    def log_rows
      @rss_log.parse_log.reject { |key, _args, _time| key == :log_orphan }
    end

    def render_target_link
      target = @rss_log.target
      return unless target

      Link(type: :get, name: :show_object.l(type: target.type_tag),
           target: target.show_link_args)
    end
  end
end
