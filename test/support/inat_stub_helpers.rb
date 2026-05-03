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

  def stub_genus_lookup_timeout(ancestor_ids:)
    stub_request(:get, "#{API_BASE}/taxa?id=#{ancestor_ids}&rank=genus").
      to_raise(RestClient::Exceptions::ReadTimeout)
  end

  def stub_genus_lookup_empty_results(ancestor_ids:)
    stub_request(:get, "#{API_BASE}/taxa?id=#{ancestor_ids}&rank=genus").
      to_return(status: 200, body: { results: [] }.to_json, headers: {})
  end

  def stub_genus_lookup_invalid_json(ancestor_ids:)
    stub_request(:get, "#{API_BASE}/taxa?id=#{ancestor_ids}&rank=genus").
      to_return(status: 200, body: "not valid json", headers: {})
  end

  # NOTE: webmock is picky about the User-Agent string
  def user_agent
    "rest-client/#{RestClient::VERSION} " \
    "(#{RbConfig::CONFIG["host_os"]} #{RbConfig::CONFIG["host_cpu"]}) " \
    "ruby/#{RUBY_VERSION}p#{RUBY_PATCHLEVEL}"
  end
end
