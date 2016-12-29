# encoding: utf-8
require "test_helper"

class ExternalLinkTest < UnitTestCase
  def test_create_valid
    link = ExternalLink.create!(
      user:          mary,
      observation:   Observation.first,
      external_site: ExternalSite.first,
      url:           "http://somewhere.com"
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
end
