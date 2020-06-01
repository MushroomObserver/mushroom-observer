# frozen_string_literal: true

require "test_helper"

class ExternalLinkTest < UnitTestCase
  def test_create_valid
    link = ExternalLink.create!(
      user: mary,
      observation: Observation.first,
      external_site: ExternalSite.first,
      url: "http://somewhere.com"
    )
    assert_not_nil(link)
    assert_empty(link.errors)
  end

  def test_create_missing_attributes
    link = ExternalLink.create
    assert_not_empty(link.errors[:user])
    assert_not_empty(link.errors[:observation])
    assert_not_empty(link.errors[:external_site])
    assert_not_empty(link.errors[:url])
  end

  def test_create_validate_url
    link = ExternalLink.create(url: "http://" + "too long" * 100)
    assert_not_empty(link.errors[:url])
    site = ExternalLink.create(url: "invalid url")
    assert_not_empty(site.errors[:url])
    site = ExternalLink.create(url: "http://valid.url")
    assert_empty(site.errors[:url])
  end

  def test_uniqueness
    link1 = ExternalLink.first
    another_obs = observations(:minimal_unknown_obs)
    assert_not_equal(link1.observation.id, another_obs.id)
    link2 = ExternalLink.create(
      user: mary,
      observation: link1.observation,
      external_site: link1.external_site,
      url: "http://another.com"
    )
    assert_not_empty(link2.errors)
    link3 = ExternalLink.create(
      user: mary,
      observation: another_obs,
      external_site: link1.external_site,
      url: "http://another.com"
    )
    assert_empty(link3.errors)
  end
end
