# frozen_string_literal: true

require("test_helper")
require("json")

# The backfill's iNat traffic: the search, the field-value write, and
# the short-lived JWT both sit behind.
class Inat::URLBackfillClientTest < UnitTestCase
  # Skips the inter-request pacing; the timing is the API's contract,
  # not this test's.
  class FastClient < Inat::URLBackfill::Client
    private

    def pause(_seconds) = nil
  end

  # Stands in for Inat::APIRequest, recording the calls it was given.
  class FakeAPI
    attr_reader :calls

    def initialize(body: '{"results":[]}', error: nil)
      @body = body
      @error = error
      @calls = []
    end

    def request(path:, method: :get, payload: nil, **)
      @calls << { path: path, method: method, payload: payload }
      raise(@error) if @error

      Struct.new(:body).new(@body)
    end
  end

  def setup
    @client = FastClient.new(access_token: "oauth-token")
  end

  def with_api(api, &block)
    Inat::APIRequest.stub(:new, ->(_token) { api }, &block)
  end

  def with_jwt(jwt, &block)
    token = Object.new
    token.define_singleton_method(:trade_access_token_for_jwt_api_token) do |_|
      jwt
    end
    Inat::APIToken.stub(:new, ->(**) { token }, &block)
  end

  def test_refuses_to_start_without_a_credential
    assert_raises(Inat::URLBackfill::Client::AuthError) do
      Inat::URLBackfill::Client.new(access_token: nil)
    end
  end

  def test_reports_whether_a_credential_is_configured
    Inat::URLBackfill::Client.stub(:configured_access_token, "x") do
      assert(Inat::URLBackfill::Client.configured?)
    end
    Inat::URLBackfill::Client.stub(:configured_access_token, nil) do
      assert_not(Inat::URLBackfill::Client.configured?)
    end
  end

  def test_prefers_the_environment_over_the_credentials
    ENV["INAT_BACKFILL_ACCESS_TOKEN"] = "from-env"

    assert_equal("from-env",
                 Inat::URLBackfill::Client.configured_access_token)
  ensure
    ENV.delete("INAT_BACKFILL_ACCESS_TOKEN")
  end

  def test_falls_back_to_the_credentials
    ENV.delete("INAT_BACKFILL_ACCESS_TOKEN")

    assert_nothing_raised do
      Inat::URLBackfill::Client.configured_access_token
    end
  end

  # Newest first, filtered to observations carrying the field, at iNat's
  # maximum page size.
  def test_searches_the_field_newest_first
    api = FakeAPI.new(body: '{"results":[{"id":7}]}')

    results = with_api(api) { @client.search }

    assert_equal([{ "id" => 7 }], results)
    path = api.calls.first[:path]
    assert_match(/order_by=id&order=desc/, path)
    assert_match(/per_page=200/, path)
    assert_match(/field%3A|field:/, path)
    assert_no_match(/id_below/, path, "no cursor means start at the newest")
  end

  def test_searches_below_the_cursor_when_given_one
    api = FakeAPI.new

    with_api(api) { @client.search(id_below: 500) }

    assert_match(/id_below=500/, api.calls.first[:path])
  end

  def test_writes_the_obs_form_value
    api = FakeAPI.new

    value = with_jwt("jwt") { with_api(api) { @client.write(99, "42") } }

    assert_equal("https://mushroomobserver.org/obs/42", value)
    call = api.calls.first
    assert_equal(:put, call[:method])
    assert_equal("observation_field_values/99", call[:path])
    assert_equal({ observation_field_value: { value: value } }, call[:payload])
  end

  # A pass spanning weeks outlives any one 24h JWT.
  def test_mints_a_fresh_jwt_and_retries_once_on_a_401
    attempts = 0
    api = Object.new
    api.define_singleton_method(:request) do |**|
      attempts += 1
      raise(RestClient::Unauthorized) if attempts == 1

      Struct.new(:body).new("{}")
    end

    with_jwt("jwt") { with_api(api) { @client.write(99, "42") } }

    assert_equal(2, attempts, "the write is retried behind a fresh JWT")
  end

  def test_gives_up_when_the_fresh_jwt_is_also_rejected
    api = FakeAPI.new(error: RestClient::Unauthorized)

    error = assert_raises(Inat::URLBackfill::Client::AuthError) do
      with_jwt("jwt") { with_api(api) { @client.write(99, "42") } }
    end

    assert_match(/freshly minted/, error.message)
  end

  def test_treats_a_refused_oauth_token_as_an_auth_error
    with_jwt(nil) do
      assert_raises(Inat::URLBackfill::Client::AuthError) { @client.token }
    end
  end

  def test_treats_a_failed_mint_as_an_auth_error
    token = Object.new
    token.define_singleton_method(:trade_access_token_for_jwt_api_token) do |_|
      raise(RestClient::BadRequest)
    end

    error = assert_raises(Inat::URLBackfill::Client::AuthError) do
      Inat::APIToken.stub(:new, ->(**) { token }) { @client.token }
    end

    assert_match(/minting an iNat JWT failed/, error.message)
  end
end
