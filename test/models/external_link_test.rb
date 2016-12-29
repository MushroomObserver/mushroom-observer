# encoding: utf-8
require "test_helper"

class ExternalLinkTest < UnitTestCase
  def test_create_valid
    site = ExternalLink.create!(
      name: "GenBank",
      project: Project.first
    )
    assert_not_nil(site)
    assert_empty(site.errors)
  end

  def test_create_missing_attributes
    site = ExternalSite.create
    assert_not_empty(site.errors[:name])
    assert_not_empty(site.errors[:project])
  end

  def test_create_name_too_long
    site = ExternalSite.create(name: "x" * 1000)
    assert_not_empty(site.errors[:name])
  end
end
