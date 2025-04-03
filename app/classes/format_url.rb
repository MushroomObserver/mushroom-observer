# frozen_string_literal: true

# uri.scheme    #=> "https"
# uri.host      #=> "foo.com"
# uri.path      #=> "/posts"
# uri.query     #=> "id=30&limit=5"
# uri.fragment  #=> "time=1305298413"

# uri.to_s      #=> "http://foo.com/posts?id=30&limit=5#time=1305298413"
# Can simply validate one url as a working url,
# or check it conforms to a URL format against a provided base_url.
# Call `formatted` to get a URL adjusted to the base_url format.
class FormatURL
  attr_reader :url, :base_url, :url_only

  def initialize(url = "", base_url = "", scheme: "https")
    @url = URI.parse(url)
    @base_url = URI.parse(base_url)
    @scheme = scheme
    @url_only = @base_url.host.blank?
  end

  def valid?
    return false unless @url.host
    return true if (responds = url_exists?) && @url_only

    responds &&
      @url.host == @base_url.host &&
      @url.path == @base_url.path
  end

  # Call with base: true to strip the query
  def formatted(base: @url_only)
    @url.scheme = @base_url.scheme || @scheme
    if base
      @url.query = nil
      @url.fragment = nil
    end
    return @url.to_s if @url_only

    use_www_if_base_does
    @url.to_s
  end

  private

  def url_exists?
    request = Net::HTTP.new(@url.host, @url.port)
    request.use_ssl = true
    path = @url.path if @url.path.present?
    response = request.request_head(path || "/")
    # Go after any redirect and make sure you can access the redirected URL
    # Returns false if http code starts with 4 - error on your side.
    if response.is_a?(Net::HTTPRedirection)
      url_exists?(response["location"])
    else
      response.code[0] != "4"
    end
  # false if can't find the server
  rescue Errno::ENOENT
    false
  end
  # https://stackoverflow.com/a/18582395/3357635'

  def use_www_if_base_does
    return @url.host unless @base_url.host

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
