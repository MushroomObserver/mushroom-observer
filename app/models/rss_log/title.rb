# frozen_string_literal: true

# RssLog's text_name/format_name family, split out of the model (#4901).
# Real non-Phlex consumers -- the RSS/Atom feed
# (app/views/controllers/rss_logs/rss.xml.builder) and the shared
# text_name/format_name polymorphic contract other models implement,
# reachable generically via ViewerAwareFormat from non-render controller
# code -- meant this couldn't just move into the view layer outright.
# RssLog delegates its public text_name/unique_text_name/format_name/
# unique_format_name/url methods here.
class RssLog::Title
  def initialize(rss_log)
    @rss_log = rss_log
  end

  # Returns plain text title of the associated object.
  def text_name
    if target
      if target.respond_to?(:real_text_name)
        target.real_text_name
      else
        target.text_name
      end
    else
      orphan_title.t.html_to_ascii.sub(/ (\d+)$/, "")
    end
  end

  # Returns plain text title of the associated object, with id tacked on.
  def unique_text_name
    if target
      target.unique_text_name
    else
      orphan_title.t.html_to_ascii
    end
  end

  # Returns formatted title of the associated object.
  def format_name(user = nil)
    if target
      target.format_name(user)
    else
      orphan_title.sub(/ (\d+)$/, "")
    end
  end

  # Returns formatted title of the associated object, with id tacked on.
  def unique_format_name(user = nil)
    if target
      target.unique_format_name(user)
    else
      orphan_title
    end
  end

  # Returns URL of <tt>show_#{object}</tt> action for the associated object.
  def url
    "#{(target || @rss_log).show_url}?time=#{@rss_log.updated_at.tv_sec}"
  end

  private

  def target
    @rss_log.target
  end

  # The top line of log should be the old object's name after it is
  # destroyed.
  def orphan_title
    name = @rss_log.notes.to_s.split("\n", 2).first
    if /^\d{14}/.match?(name)
      # This is an occasional error, when a log wasn't orphaned properly.
      _tag, args, _time = @rss_log.parse_log.first
      args[:this] || :rss_log_of_deleted_item.l
    else
      RssLog.unescape(name)
    end
  end
end
