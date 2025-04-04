# frozen_string_literal: true

require("test_helper")

class ExternalSiteTest < UnitTestCase
  def test_create_external_site_valid
    stub_request(:any, /genbank/)
    site = ExternalSite.create!(
      name: "GenBank",
      project: Project.first,
      base_url: "genbank.org"
    )
    assert_not_nil(site)
    assert_empty(site.errors)
    assert_equal("https://genbank.org", site.reload.base_url)

    stub_request(:any, /genbank/)
    assert_raises("Name has already been taken") do
      ExternalSite.create!(
        name: "genbank",
        project: Project.first,
        base_url: "genbank.org"
      )
    end
  end

  def test_create_external_site_missing_attributes
    site = ExternalSite.create
    assert_not_empty(site.errors[:name])
    assert_not_empty(site.errors[:base_url])
  end

  def test_create_external_site_name_too_long
    site = ExternalSite.create(name: "x" * 1000)
    assert_not_empty(site.errors[:name])
  end

  def test_external_sites_user
    marys_sites = ExternalSite.all.sort_by(&:id)
    assert_obj_arrays_equal([], rolf.external_sites)
    assert_obj_arrays_equal([], dick.external_sites)
    assert_obj_arrays_equal(marys_sites, mary.external_sites.sort_by(&:id))
  end

  def test_external_site_project_member
    site = external_sites(:mycoportal)
    assert_false(site.member?(rolf))
    assert_false(site.member?(dick))
    assert_true(site.member?(mary))
  end

  def test_external_site_uniqueness
    site1 = ExternalSite.first
    stub_request(:any, site1.base_url)
    site2 = ExternalSite.create(
      name: site1.name,
      project: site1.project,
      base_url: site1.base_url
    )
    assert_not_empty(site2.errors)

    stub_request(:any, site1.base_url)
    site3 = ExternalSite.create(
      name: "#{site1.name} two",
      project: site1.project,
      base_url: site1.base_url
    )
    assert_not_empty(site3.errors)

    stub_request(:any, "https://different.url")
    site4 = ExternalSite.create(
      name: "#{site1.name} two",
      project: site1.project,
      base_url: "https://different.url"
    )
    assert_empty(site4.errors)
  end
end
