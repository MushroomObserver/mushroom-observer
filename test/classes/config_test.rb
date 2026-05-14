# frozen_string_literal: true

require("test_helper")

# A place to put tests related to the overall RoR configuration

class ConfigTest < UnitTestCase
  # Sanity-checks that credentials.yml.enc decrypted and contains
  # the expected marker value. Skipped on CI runs that have no
  # RAILS_MASTER_KEY available — most commonly PRs from forked
  # repos, since GitHub Actions does not pass repo secrets to
  # workflows triggered by fork PRs. The credentials hash is
  # entirely empty in that case (decryption silently no-ops);
  # we use that as the unambiguous "no master key" signal so a
  # genuine credentials regression (e.g. test_secret renamed)
  # still fails the assertion when the key is present.
  def test_secrets
    if Rails.application.credentials.config.empty?
      skip("RAILS_MASTER_KEY missing; credentials cannot decrypt")
    end
    assert_equal("magic", Rails.application.credentials.test_secret)
  end
end
