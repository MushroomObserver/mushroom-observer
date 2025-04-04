# frozen_string_literal: true

# Can simply validate one url as a working url,
# or check it conforms to a the format of a provided base_url.
#
# Main accessors
#
# valid?::        True if it works, and if it matches any provided base_url
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
#   fred.url_exists?
#     true
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
#   fred.url_exists?
#     true
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
  attr_reader :url, :base_url, :url_only, :url_exists, :errors

  def initialize(url = "", base_url = "", scheme: "https")
    @original_url = url
    url = add_enforced_scheme_if_missing(scheme)
    @url = URI.parse(url)
    @base_url = URI.parse(space_check(base_url))
    @scheme = scheme
    @url_only = @base_url.host.blank?
    @url_exists = url_exists?(@url.to_s)
  end

  def valid?
    unless nothing_funny?(@original_url) &&
           (@url.is_a?(URI::HTTPS) || @url.is_a?(URI::HTTP)) &&
           @url.host && @url_exists
      return false
    end
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

  # Enforce scheme for incoming urls. Guards against scheme missing, which
  # causes `url_exists?` to return false
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

  # Goes after any redirect and makes sure we can access the redirected URL
  # Returns false if http code starts with 4 - error on our side.
  # Calls URI.parse(url) again here because we may need to reparse a redirect
  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
  # rubocop:disable Metrics/PerceivedComplexity
  def url_exists?(url)
    return false if url.to_s == ""

    url = URI.parse(url)
    return false if url.host.blank?
    return true if ENV["RAILS_ENV"] == "test"

    request = format_request(url)
    path = url.path if url.path.present?
    response = request.request_head(path || "/")

    if response.is_a?(Net::HTTPRedirection)
      url_exists?(response["location"])
    else
      response.code[0] != "4"
    end
  # false if can't find the server
  rescue Errno::ECONNREFUSED, Errno::ENOENT, Socket::ResolutionError
    false
  end
  # https://stackoverflow.com/a/18582395/3357635'
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity
  # rubocop:enable Metrics/PerceivedComplexity

  def format_request(url)
    request = Net::HTTP.new(url.host, url.port)
    request.use_ssl = (url.scheme == "https")
    request
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
