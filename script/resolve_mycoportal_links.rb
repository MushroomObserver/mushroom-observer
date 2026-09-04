#!/usr/bin/env ruby
# frozen_string_literal: true

# Resolve MyCoPortal ExternalLinks whose stored `url` isn't a clean
# individual-record permalink (#4591). Every candidate ends in one of
# two terminal states: `external_id` gets set, or the link is
# converted to a Comment and deleted -- no link is left with a nil
# `external_id` after a full apply run except one still stuck on a
# fetch error, which needs manual resolution before `external_id` can
# be made NOT NULL and `url` dropped. Checked in order:
#
#   1. url already matches the individual/index.php?occid= shape -- set
#      external_id (same case normalize_mycoportal_links.rb handles;
#      kept here so this script alone is a complete pass over whatever
#      remains unresolved). Checked first, ahead of the sibling check
#      below, so a link's resolvable occid always wins over trusting a
#      sibling -- a sibling's external_id is not assumed to match
#      without this check (a target can legitimately carry more than
#      one distinct MyCoPortal correspondence).
#   2. the same target (observation/image) already has a different
#      MyCoPortal link with an external_id set -- a bulk export-
#      reconciliation import can resolve a target via a separate
#      `export`-relationship link, leaving this one untouched.
#      Confirmed on a fresh prod checkpoint: 1,491 of 1,695 unresolved
#      links fell into this case. Treated the same as an unresolvable
#      link (case 3's no-occids branch): convert to a Comment
#      preserving the url, then delete.
#   3. url is a MyCoPortal catalog-number search (list.php?catnum=...,
#      any db=) -- fetch the page and read the occid(s) out of the
#      results table's `onclick="return openIndPU(OCCID,...)"` links.
#        one occid  -> resolved: set external_id, drop url.
#        no occids  -> no matching record: convert the link to a Comment
#                      on the target (preserving the url verbatim) and
#                      delete the link.
#        2+ occids  -> ambiguous: convert to a Comment listing every
#                      candidate occid, then delete -- still logged
#                      separately under "Needs human review" so a
#                      human can pick the right occid and set it by
#                      hand on the target if it matters.
#        fetch error -> report only, no change -- a transient failure
#                      isn't grounds to delete a link.
#   4. url is "http://adolf" or points back at mushroomobserver.org --
#      junk (a stray paste, or the linked observation's MO url pasted
#      in by mistake -- every observed case's target_id matches the id
#      in the url). Delete without a comment: there's nothing worth
#      keeping.
#   5. url is a MyCoPortal taxon page (taxa/index.php) -- every
#      observation already shows an "About this Taxon" section linking
#      to the same MyCoPortal taxon page, so this link is redundant.
#      Delete without a comment.
#   6. url is on mycoportal.org but isn't a record search or taxon
#      page, or isn't on mycoportal.org: can't resolve to one record,
#      so convert to a Comment and delete.
#
# A converted Comment is authored by the link's original creator,
# falling back to the target's owner if that's somehow unavailable,
# and preserves the url verbatim in its body.
#
# Idempotent: only selects links with external_id nil and url present,
# so an already-resolved or already-converted row is skipped on re-run.
# Network calls are rate-limited (--delay, default 1s) to be a
# considerate crawler.
#
#   bin/rails runner script/resolve_mycoportal_links.rb            # dry run
#   bin/rails runner script/resolve_mycoportal_links.rb --apply    # write
#   bin/rails runner script/resolve_mycoportal_links.rb --apply --limit 20

require "net/http"
require "optparse"

class ResolveMycoportalLinks
  USER_AGENT =
    "Mozilla/5.0 (compatible; MushroomObserverBot/1.0; " \
    "+https://mushroomobserver.org)"
  MAX_REDIRECTS = 3
  OCCID_RE = /openIndPU\((\d+)/
  COMMENT_SUMMARY = "MyCoPortal link converted to comment"
  # Matches on "://mushroomobserver.org" rather than the bare
  # substring, so a url that merely mentions the domain somewhere
  # (e.g. as a query value on a third-party site) isn't caught -- and
  # not on `uri.host`, since a malformed double-scheme url like
  # "http://https://mushroomobserver.org/N" parses with host "https",
  # not the intended host.
  SELF_REFERENTIAL_RE = %r{://(?:www\.)?mushroomobserver\.org(/|\z)}

  def initialize(opts)
    @apply = opts.fetch(:apply, false)
    @limit = opts[:limit]
    @delay = opts.fetch(:delay, 1.0)
    @site = ExternalSite.where("base_url LIKE ?", "%mycoportal.org%").first
    abort("No MyCoPortal external site found") unless @site
    @counts = Hash.new(0)
    @ambiguous = []
    @errors = []
  end

  def run
    candidates.each_with_index do |link, i|
      break if @limit && i >= @limit

      process_safely(link)
    end
    report_summary
  end

  private

  def candidates
    ExternalLink.where(external_site_id: @site.id, external_id: nil).
      where.not(url: [nil, ""]).order(:id)
  end

  # One bad row (an orphaned target, an unexpected DB constraint, ...)
  # shouldn't abort an unattended run over 1,000+ links -- log it as an
  # error to review and move on to the rest.
  def process_safely(link)
    process(link)
  rescue StandardError => e
    @errors << { id: link.id, url: link.url, error: e.message }
    warn("##{link.id}: unhandled error (#{e.class}: #{e.message}), skipping")
    @counts[:unhandled_error] += 1
  end

  def process(link)
    occid = @site.id_from_url(link.url)
    return resolve!(link, occid) if occid

    if resolved_sibling?(link)
      return convert_to_comment!(link, "already resolved via a separate " \
                                       "MyCoPortal link on this record")
    end

    return crawl_and_resolve(link) if list_search?(link.url)
    return delete_junk!(link) if delete_reason(link.url)

    convert_to_comment!(link, unresolvable_reason(link.url))
  end

  def delete_reason(url)
    return "self-referential junk" if self_referential?(url)
    if taxon_page?(url)
      return "MyCoPortal taxon page, already linked from About " \
             "this Taxon"
    end

    nil
  end

  def delete_junk!(link)
    delete_without_comment!(link, delete_reason(link.url))
  end

  def resolved_sibling?(link)
    ExternalLink.
      where(external_site_id: @site.id, target_type: link.target_type,
            target_id: link.target_id).
      where.not(id: link.id).where.not(external_id: nil).exists?
  end

  def resolve!(link, occid)
    warn("##{link.id}: #{link.url} -> external_id=#{occid}")
    link.update!(external_id: occid) if @apply # callback clears url
    @counts[:resolved] += 1
  end

  def crawl_and_resolve(link)
    body, error = fetch(link.url)
    sleep(@delay) if @delay.positive?
    return handle_fetch_error(link, error) if error

    occids = body.scan(OCCID_RE).flatten.uniq
    case occids.size
    when 1 then resolve!(link, occids.first)
    when 0 then convert_to_comment!(link, "no matching MyCoPortal record")
    else handle_ambiguous(link, occids)
    end
  end

  def handle_fetch_error(link, error)
    @errors << { id: link.id, url: link.url, error: error }
    warn("##{link.id}: fetch error (#{error}), skipping")
    @counts[:fetch_error] += 1
  end

  def handle_ambiguous(link, occids)
    @ambiguous << { id: link.id, url: link.url, occids: occids }
    convert_to_comment!(
      link, "#{occids.size} candidate MyCoPortal records: " \
            "#{occids.join(", ")}"
    )
  end

  # "http://adolf", and every mushroomobserver.org self-link in this
  # data set, has the linked observation's id right in the url -- not
  # a record worth preserving as a comment.
  def self_referential?(url)
    url == "http://adolf" || url.match?(SELF_REFERENTIAL_RE)
  end

  def delete_without_comment!(link, reason)
    warn("##{link.id}: #{reason} (#{link.url}) -> delete, no comment")
    link.destroy! if @apply
    @counts[:deleted_no_comment] += 1
  end

  def convert_to_comment!(link, reason)
    warn("##{link.id}: #{reason} (#{link.url}) -> comment + delete")
    if @apply
      Comment.create!(target: link.target, user: comment_user(link),
                      summary: COMMENT_SUMMARY,
                      comment: comment_body(link, reason))
      link.destroy!
    end
    @counts[:converted] += 1
  end

  def comment_user(link)
    link.user || link.target.user
  end

  def comment_body(link, reason)
    "This observation had an external link to MyCoPortal that could " \
      "not be resolved to a specific record (#{reason}). " \
      "Original link: #{link.url}"
  end

  # `end_with?("mycoportal.org")` alone would also match a host like
  # "evilmycoportal.org" -- no dot boundary. Require an exact match or
  # a proper subdomain.
  def mycoportal_host?(uri)
    uri.host == "mycoportal.org" || uri.host&.end_with?(".mycoportal.org")
  end

  def list_search?(url)
    uri = safe_parse(url)
    return false unless uri && mycoportal_host?(uri)

    uri.path.end_with?("/list.php") && uri.query.to_s.include?("catnum=")
  end

  def taxon_page?(url)
    uri = safe_parse(url)
    return false unless uri && mycoportal_host?(uri)

    uri.path.end_with?("/taxa/index.php")
  end

  def unresolvable_reason(url)
    uri = safe_parse(url)
    return "not a MyCoPortal URL" unless uri && mycoportal_host?(uri)

    "not a MyCoPortal record page (#{uri.path})"
  end

  def safe_parse(url)
    URI.parse(url)
  rescue URI::InvalidURIError
    nil
  end

  def fetch(url, redirects_left: MAX_REDIRECTS)
    uri = safe_parse(url)
    return [nil, "unparseable URL"] unless uri

    uri.scheme = "https"
    uri.port = 443
    uri.host = "mycoportal.org"
    opts = { use_ssl: true, open_timeout: 10, read_timeout: 20 }
    res = Net::HTTP.start(uri.host, uri.port, **opts) do |http|
      req = Net::HTTP::Get.new(uri)
      req["User-Agent"] = USER_AGENT
      http.request(req)
    end
    handle_response(res, redirects_left)
  rescue StandardError => e
    [nil, e.message]
  end

  def handle_response(res, redirects_left)
    case res
    when Net::HTTPRedirection
      return [nil, "too many redirects"] if redirects_left <= 0

      fetch(res["location"], redirects_left: redirects_left - 1)
    when Net::HTTPSuccess
      [res.body, nil]
    else
      [nil, "HTTP #{res.code}"]
    end
  end

  def report_summary
    warn("")
    warn("== Summary (#{@apply ? "APPLIED" : "dry run"}) ==")
    @counts.each { |k, v| warn("  #{k}: #{v}") }
    report_needs_review
  end

  def report_needs_review
    return if @ambiguous.empty? && @errors.empty?

    warn("")
    warn("Needs human review:")
    @ambiguous.each do |r|
      warn("  ##{r[:id]}: #{r[:occids].size} candidates -- #{r[:url]}")
    end
    @errors.each { |r| warn("  ##{r[:id]}: #{r[:error]} -- #{r[:url]}") }
  end
end

options = { apply: false, delay: 1.0 }
OptionParser.new do |opts|
  opts.banner =
    "Usage: bin/rails runner script/resolve_mycoportal_links.rb [options]"
  opts.on("--apply", "Write changes (default: dry run)") do
    options[:apply] = true
  end
  opts.on("--limit N", Integer, "Process at most N links (trial run)") do |n|
    options[:limit] = n
  end
  opts.on("--delay SECONDS", Float,
          "Delay between MyCoPortal requests (default: 1.0)") do |d|
    options[:delay] = d
  end
end.parse!(ARGV)

ResolveMycoportalLinks.new(options).run
