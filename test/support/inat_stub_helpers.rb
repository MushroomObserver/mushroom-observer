# frozen_string_literal: true

module InatStubHelpers
  include Inat::Constants

  # Stub iNat API genus lookup (based on ancestor ids)
  # Need to lookup the genus of infrageneric taxa because
  # the iNat API returns only epithet and rank, not the genus
  def stub_genus_lookup(ancestor_ids:, body:)
    stub_request(:get, "#{API_BASE}/taxa?id=#{ancestor_ids}&rank=genus").
      with(
        headers: {
          "Accept" => "application/json",
          "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
          "Host" => "api.inaturalist.org",
          # RestClient complains if User-Agent missing
          # Must be set dynamically because it differs per machine, including CI
          "User-Agent" => user_agent
        }
      ).
      to_return(
        status: 200,
        body: body.to_json,
        headers: {}
      )
  end

  # A WebMock URL matcher anchored at iNat's API base. Interpolating
  # the base into a regexp leaves its dots matching any character, so
  # a stub meant for api.inaturalist.org would answer for
  # apiXinaturalistXorg as well -- CodeQL's "incomplete regular
  # expression for hostnames". Escaping the base fixes that, and
  # anchoring it keeps the stub to the path it names.
  def inat_api_matcher(path)
    /\A#{Regexp.escape("#{API_BASE}/#{path}")}/
  end

  # NOTE: webmock is picky about the User-Agent string
  def user_agent
    "rest-client/#{RestClient::VERSION} " \
    "(#{RbConfig::CONFIG["host_os"]} #{RbConfig::CONFIG["host_cpu"]}) " \
    "ruby/#{RUBY_VERSION}p#{RUBY_PATCHLEVEL}"
  end
end
