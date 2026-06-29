#!/usr/bin/env ruby
# frozen_string_literal: true

# Set MyCoPortal's url_template so external_id derives the canonical
# individual-record URL, and convert links whose stored url encodes an occid
# (`.../individual/index.php?occid=<digits>`, with or without trailing junk
# like `&clid=0`) to external_id (#4565). Links without an occid (catnum list
# searches, etc.) keep their stored url. Idempotent; dry-run by default.
#
#   bin/rails runner script/normalize_mycoportal_links.rb
#   APPLY=1 bin/rails runner script/normalize_mycoportal_links.rb

apply = ENV["APPLY"] == "1"
site = ExternalSite.where("base_url LIKE ?", "%mycoportal.org%").first
abort("No MyCoPortal external site found") unless site

base = "https://mycoportal.org/portal/collections/"
template = "#{base}individual/index.php?occid={id}"
if site.base_url != base || site.url_template != template
  warn("config: base_url=#{site.base_url.inspect} " \
       "url_template=#{site.url_template.inspect} -> #{template.inspect}")
  site.update!(base_url: base, url_template: template) if apply
end

converted = 0
links = ExternalLink.where(external_site_id: site.id).where.not(url: [nil, ""])
links.find_each do |link|
  occid = link.url[/index\.php\?occid=(\d+)/, 1]
  next unless occid

  warn("##{link.id}: #{link.url} -> external_id=#{occid}")
  link.update!(external_id: occid) if apply # model drops the now-redundant url
  converted += 1
end

warn("converted #{converted} link(s); #{apply ? "APPLIED" : "dry run"}")
