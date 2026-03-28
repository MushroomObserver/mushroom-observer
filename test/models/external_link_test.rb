# frozen_string_literal: true

require("test_helper")

class ExternalLinkTest < UnitTestCase
  def test_create_valid
    site = ExternalSite.first
    base_url = site.base_url

    link = ExternalLink.create!(
      user: mary,
      observation: Observation.first,
      external_site: site,
      url: "#{base_url}plus_id"
    )
    assert_not_nil(link, "ExternalLink should be created")
    assert_empty(link.errors, "ExternalLink should have no errors")
  end

  def test_create_missing_attributes
    link = ExternalLink.create
    assert_not_empty(link.errors[:user], "ExternalLink should require a user")
    assert_not_empty(link.errors[:observation],
                     "ExternalLink should require an observation")
    assert_not_empty(link.errors[:external_site],
                     "ExternalLink should require an external_site")
    assert_not_empty(link.errors[:url], "ExternalLink should require a url")
  end

  def test_create_validate_url
    site = ExternalSite.first
    base_url = site.base_url

    link = ExternalLink.create(url: "#{base_url}#{"toolong" * 100}",
                               external_site: site)
    assert_not_empty(link.errors[:url],
                     "URL that is too long should be invalid")

    link = ExternalLink.create(url: "#{base_url}invalid url",
                               external_site: site)
    assert_not_empty(link.errors[:url],
                     "URL with spaces should be invalid")

    link = ExternalLink.create(url: "#{base_url}url", external_site: site)
    assert_empty(link.errors[:url], "Valid URL should have no url errors")
  end

  # iNaturalist's Cloudflare CDN blocks automated HEAD requests with 403,
  # causing FormatURL#url_exists? to return false and silently drop the link.
  # For iNat URLs constructed from base_url, skip FormatURL entirely.
  def test_inaturalist_link_skips_format_url
    site = external_sites(:inaturalist)
    obs = observations(:minimal_unknown_obs)
    url = "#{site.base_url}253297232"

    FormatURL.stub(:new, ->(*) { raise("FormatURL should not be called") }) do
      link = ExternalLink.create!(
        user: dick, observation: obs, external_site: site, url: url
      )
      assert_empty(link.errors, "iNat link should be created without errors")
      assert_equal(url, link.url, "iNat link URL should be saved unchanged")
    end
  end

  # iNat URLs must be only the basse url plus an observation numberic id,
  # e.g. /observations/12345.
  # A URL like /observations/abc should be invalid.
  def test_inaturalist_link_requires_numeric_id
    site = external_sites(:inaturalist)
    obs = observations(:minimal_unknown_obs)
    url = "#{site.base_url}notanumber"

    link = ExternalLink.create(
      user: dick, observation: obs, external_site: site, url: url
    )
    assert_not_empty(
      link.errors[:url],
      "#{url} is not a valid iNat external link URL. " \
      "It should be just #{site.base_url} + a numeric ID"
    )
  end

  def test_uniqueness
    link1 = ExternalLink.first
    site = link1.external_site
    base_url = site.base_url

    another_obs = observations(:minimal_unknown_obs)
    assert_not_equal(link1.observation.id, another_obs.id,
                     "Fixture observations should be different")

    # same observation
    link2 = ExternalLink.create(
      user: mary,
      observation: link1.observation,
      external_site: site,
      url: "#{base_url}and_an_id"
    )
    assert_not_empty(link2.errors,
                     "Duplicate link for same observation should be invalid")

    # different observation
    link3 = ExternalLink.create(
      user: mary,
      observation: another_obs,
      external_site: site,
      url: "#{base_url}and_an_id"
    )
    assert_empty(link3.errors,
                 "Link for different observation should be valid")
  end
end
