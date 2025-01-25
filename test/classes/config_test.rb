# frozen_string_literal: true

require("test_helper")

# A place to put tests related to the overall RoR configuration

class ConfigTest < UnitTestCase
  def test_secrets
    assert_equal("magic", Rails.application.credentials.test_secret)
  end
end
