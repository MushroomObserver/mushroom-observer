# frozen_string_literal: true

xml.instruct!(:xml, version: "1.0")
xml.rss(version: "2.0") do
  xml.channel do
    xml.title(:rss_title.l)
    xml.link(MO.http_domain + "/observer/list_rss_logs")
    xml.description(:rss_description.l)
    xml.language(I18n.locale.to_s)
    @logs.each do |log|
      xml.item do
        xml.title(log.unique_text_name)
        xml.description(
          log.parse_log.map do |key, args, time|
            "#{time.rfc2822}: #{key.t(args).strip_html}<br></br>\n"
          end
        )
        xml.pubDate(log.updated_at.rfc2822)
        xml.link(MO.http_domain + log.url)
        xml.guid(MO.http_domain + log.url, isPermaLink: "false")
      end
    end
  end
end
