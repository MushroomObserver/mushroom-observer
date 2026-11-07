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
      add_page_title(composed_page_title)
      add_pager_for(@rss_log)
      container_class(:text_image)
      content_padding(:panels)
    end

    def composed_page_title
      capture do
        trusted_html(append_colon(:log.ti))
        whitespace
        IDBadge(object: target, size: :sm) if target
        trusted_html(@rss_log.format_name.t.small_author)
      end
    end

    def target
      return @target if defined?(@target)

      @target = @rss_log.target
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
      return unless target

      ContentPadded do
        Button(type: :get, name: :show_object.l(type: target.type_tag),
               target: target.show_link_args, variant: :outline)
      end
    end
  end
end
