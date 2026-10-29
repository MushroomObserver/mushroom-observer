# frozen_string_literal: true

require("test_helper")

# Every iNat API call goes through Inat::APIRequest, which makes it the
# one place that can count them against iNat's published daily limit
# (#5416, #2320).
class Inat::APIRequestTest < UnitTestCase
  def setup
    super
    @site = external_sites(:inaturalist)
  end

  def stub_execute(result = :ok, &block)
    RestClient::Request.stub(:execute, lambda { |**|
      raise(RestClient::BadRequest) if result == :error

      "body"
    }, &block)
  end

  def test_counts_a_request
    stub_execute do
      Inat::APIRequest.new(nil).request(path: "observations")
    end

    assert_equal(1, ExternalSiteUsage.requests_since(@site, 1.hour))
  end

  def test_counts_each_call_separately
    stub_execute do
      3.times { Inat::APIRequest.new(nil).request(path: "taxa") }
    end

    assert_equal(3, ExternalSiteUsage.requests_since(@site, 1.hour))
  end

  # The call reached iNat whether or not it succeeded, so it counts.
  def test_counts_a_request_that_errors
    assert_raises(RestClient::BadRequest) do
      stub_execute(:error) do
        Inat::APIRequest.new(nil).request(path: "observations")
      end
    end

    assert_equal(1, ExternalSiteUsage.requests_since(@site, 1.hour))
  end

  # Accounting is bookkeeping; it must not take an import down with it.
  def test_an_accounting_failure_does_not_break_the_request
    ExternalSiteUsage.stub(:record_request, ->(*) { raise("boom") }) do
      stub_execute do
        assert_equal("body",
                     Inat::APIRequest.new(nil).request(path: "observations"))
      end
    end
  end
end
