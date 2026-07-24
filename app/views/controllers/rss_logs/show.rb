# frozen_string_literal: true

module Views::Controllers::RssLogs
  # Single-RssLog detail page — formatted list of log events plus a
  # link back to the targeted object.
  class Show < Views::FullPageBase
    prop :rss_log, ::RssLog

    def view_template
      add_page_title(:show_rss_log_title.t(title: @rss_log.unique_format_name))
      add_pager_for(@rss_log)

      render_log_table if @rss_log.notes
      render_target_link
    end

    private

    def render_log_table
      table do
        @rss_log.parse_log.each do |key, args, time|
          next if key == :log_orphan

          render_log_row(key, args, time)
        end
      end
    end

    def render_log_row(key, args, time)
      tr do
        td(class: "text-nowrap align-text-top") { plain(time.web_time) }
        td(style: "width:10px") { ":" }
        td { trusted_html(key.t(args)) }
      end
    end

    def render_target_link
      target = @rss_log.target
      return unless target

      Link(type: :get, name: :show_object.l(type: target.type_tag),
           target: target.show_link_args)
    end
  end
end
