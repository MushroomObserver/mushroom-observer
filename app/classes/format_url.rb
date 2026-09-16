# frozen_string_literal: true

# Validates a url's format -- an http/https scheme with a host -- and
# optionally that it matches the format of a provided base_url. Does not
# check that the url is reachable.
#
# Main accessors
#
# valid?::        True if the URL is well-formed (http/https, with a host),
#                 and if it matches any provided base_url. Does NOT check
#                 that the URL is reachable -- a persisted-record validation
#                 must not make a live network request on every save.
#
# formatted::     Returns formatted URL:
#                 - will automatically prepend scheme "https://"
#                   (or provided scheme) if it was not in the provided url.
#                 - will prepend "www." to host if the base_url has "www.",
#                   or remove it if not.
#
# Use:
#
# Without base_url:
#   fred = FormatURL.new("en.m.wikipedia.org/wiki/Citrus_indica")
#   fred.valid?
#     true
#   fred.formatted
#     "https://en.m.wikipedia.org/wiki/Citrus_indica"
#
# With base_url:
#   fred = FormatURL.new(
#     "http://mycoportal.org/portal/collections/list.php?catnum=AN%200432",
#     "https://www.mycoportal.org/portal/collections/"
#   )
#   fred.formatted
#     "https://www.mycoportal.org/portal/collections/list.php?catnum=AN%200432"
#
# Ruby URI class method reference:
# uri.scheme    #=> "https"
# uri.host      #=> "foo.com"
# uri.path      #=> "/posts"
# uri.query     #=> "id=30&limit=5"
# uri.fragment  #=> "time=1305298413"

# uri.to_s      #=> "http://foo.com/posts?id=30&limit=5#time=1305298413"
#
class FormatURL
  attr_reader :url, :base_url, :url_only, :errors

  def initialize(url = "", base_url = "", scheme: "https")
    @original_url = url
    url = add_enforced_scheme_if_missing(scheme)
    @url = URI.parse(url)
    @base_url = URI.parse(space_check(base_url))
    @scheme = scheme
    @url_only = @base_url.host.blank?
  end

  def valid?
    return false unless nothing_funny?(@original_url) &&
                        (@url.is_a?(URI::HTTPS) || @url.is_a?(URI::HTTP)) &&
                        @url.host.present?
    return true if @url_only

    # Check the URL pattern against the base_url provided.
    host_and_path_match?
  end

  # Call with path_only: true to strip any query segments,
  # e.g. when setting an ExternalSite's :base_url
  def formatted(path_only: false)
    if path_only
      @url.query = nil
      @url.fragment = nil
    end

    use_www_if_base_does unless @url_only
    @url.to_s
  end

  private

  def space_check(url)
    return url if nothing_funny?(url)

    ""
  end

  # Enforce scheme for incoming urls. Without a scheme, URI.parse yields a
  # URI::Generic (not HTTP/HTTPS), so valid? would reject it.
  def add_enforced_scheme_if_missing(scheme)
    return "" unless nothing_funny?(@original_url)

    url = @original_url.to_s.delete_prefix("http://").
          delete_prefix("https://").
          delete_prefix("ftp://")
    "#{scheme}://#{url}"
  end

  def nothing_funny?(url)
    url && !url.match?(/[[:space:]]+/)
  end

  def host_and_path_match?
    @url.host.delete_prefix("www.") == @base_url.host.delete_prefix("www.") &&
      @url.path.match?(@base_url.path)
  end

  def use_www_if_base_does
    return unless @base_url.host

    use_www = @base_url.host.match?("www.")
    has_www = @url.host.match?("www.")
    add_www if use_www && !has_www
    remove_www if !use_www && has_www
  end

  def add_www
    @url.host = "www.#{@url.host}"
  end

  def remove_www
    @url.host = @url.host.delete_prefix("www.")
  end
end
