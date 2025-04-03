# frozen_string_literal: true

require("test_helper")

class ExternalLinkTest < UnitTestCase
  def test_create_valid
    site = ExternalSite.first
    base_url = site.base_url

    stub_request(:any, /#{base_url}/)
    link = ExternalLink.create!(
      user: mary,
      observation: Observation.first,
      external_site: site,
      url: "#{base_url}plus_id"
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
    site = ExternalSite.first
    base_url = site.base_url

    stub_request(:any, /#{base_url}/)
    link = ExternalLink.create(url: "#{base_url}#{"toolong" * 100}",
                               external_site: site)
    assert_not_empty(link.errors[:url])

    stub_request(:any, /#{base_url}/)
    link = ExternalLink.create(url: "#{base_url}invalid url",
                               external_site: site)
    assert_not_empty(link.errors[:url])

    stub_request(:any, /#{base_url}/)
    link = ExternalLink.create(url: "#{base_url}url", external_site: site)
    assert_empty(link.errors[:url])
  end

  def test_uniqueness
    link1 = ExternalLink.first
    site = link1.external_site
    base_url = site.base_url

    another_obs = observations(:minimal_unknown_obs)
    assert_not_equal(link1.observation.id, another_obs.id)

    # same observation
    stub_request(:any, /#{base_url}/)
    link2 = ExternalLink.create(
      user: mary,
      observation: link1.observation,
      external_site: site,
      url: "#{base_url}and_an_id"
    )
    assert_not_empty(link2.errors)

    # different observation
    stub_request(:any, /#{base_url}/)
    link3 = ExternalLink.create(
      user: mary,
      observation: another_obs,
      external_site: site,
      url: "#{base_url}and_an_id"
    )
    assert_empty(link3.errors)
  end
end
