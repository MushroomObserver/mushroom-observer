# frozen_string_literal: true

require("test_helper")

class Inat::UserLookupTest < UnitTestCase
  include Inat::Constants

  def test_returns_the_public_profile
    stub_request(:get, "#{API_BASE}/users/someone").
      to_return(body: { results: [{ id: 7, login: "someone",
                                    name: "Some One", icon: "x" }] }.to_json)

    assert_equal({ "id" => 7, "login" => "someone", "name" => "Some One" },
                 Inat::UserLookup.call("someone"))
  end

  def test_nil_for_a_blank_login_or_an_unreachable_inat
    assert_nil(Inat::UserLookup.call(""))

    stub_request(:get, "#{API_BASE}/users/someone").to_return(status: 500)
    assert_nil(Inat::UserLookup.call("someone"))
  end
end
