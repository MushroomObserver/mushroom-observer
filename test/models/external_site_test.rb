# encoding: utf-8
require "test_helper"

class ExternalSiteTest < UnitTestCase
  def test_create_valid
    site = ExternalSite.create!(
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

  def test_user_external_sites
    site = external_sites(:mycoportal)
    assert_obj_list_equal([], rolf.external_sites)
    assert_obj_list_equal([], dick.external_sites)
    assert_obj_list_equal([site], mary.external_sites)
  end

  def test_member
    site = external_sites(:mycoportal)
    assert_false(site.member?(rolf))
    assert_false(site.member?(dick))
    assert_true(site.member?(mary))
  end
end
