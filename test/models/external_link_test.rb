# frozen_string_literal: true

require("test_helper")

class ExternalLinkTest < UnitTestCase
  def test_relationship_description
    # import link to iNaturalist
    assert_equal(
      "Imported from iNaturalist",
      external_links(:imported_inat_obs_inat_link).relationship_description
    )
    # default (manual) relationship, interpolates a non-iNat site name
    assert_equal(
      "Manual link to MycoPortal",
      external_links(:coprinus_comatus_obs_mycoportal_link).
        relationship_description
    )
    # every relationship has a phrase
    link = external_links(:coprinus_comatus_obs_inaturalist_link)
    link.relationship = :copy
    assert_equal("Copied by iNaturalist", link.relationship_description)
  end

  def test_normalize_external_id_and_url
    inat = external_sites(:inaturalist)
    obs = observations(:detailed_unknown_obs)

    # external_id present -> url is dropped (link identified by external_id)
    link = ExternalLink.create!(
      user: users(:rolf), target: obs, external_site: inat,
      external_id: "5550000", url: "#{inat.base_url}123"
    )
    assert_nil(link.url)
    assert_equal("5550000", link.external_id)

    # clearing external_id -> a url may be set again
    link.update!(external_id: "", url: "#{inat.base_url}777")
    assert_nil(link.external_id)
    assert_equal("#{inat.base_url}777", link.url)
  end

  def test_relationship_date
    link = external_links(:imported_inat_obs_inat_link)
    obs = link.observation

    # no external_created_on -> falls back to the link's own created_at
    link.update!(external_created_on: nil)
    assert_equal(link.created_at.to_date, link.relationship_date)

    # external record created AFTER the obs -> use the external date
    later = obs.created_at.to_date + 10
    link.update!(external_created_on: later)
    assert_equal(later, link.relationship_date)

    # external record created BEFORE the obs -> use the obs date (the later)
    link.update!(external_created_on: obs.created_at.to_date - 10)
    assert_equal(obs.created_at.to_date, link.relationship_date)
  end

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
    assert_not_empty(link.errors[:target],
                     "ExternalLink should require a target")
    assert_not_empty(link.errors[:external_site],
                     "ExternalLink should require an external_site")
    # url is optional now (derived from the site template); no presence error.
    assert_empty(link.errors[:url], "url is not required")
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

  # iNat URLs must be only the base url plus an observation numeric id,
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

  # An MO obs can correspond to several external records (e.g. iNat-side
  # duplicates of one collection), so a second non-import link to the same
  # site on the same obs is allowed (#4565). Only one import per target is
  # constrained — see test_only_one_import_per_target.
  def test_multiple_links_per_target_allowed
    link1 = external_links(:coprinus_comatus_obs_mycoportal_link)
    site = link1.external_site

    link2 = ExternalLink.create(
      user: mary,
      observation: link1.observation,
      external_site: site,
      url: "#{site.base_url}another_id"
    )
    assert_empty(link2.errors,
                 "A second link for the same observation+site should be valid")
  end

  def test_relationship_defaults_to_manual
    site = external_sites(:mycoportal)
    link = ExternalLink.create!(
      user: mary, observation: observations(:minimal_unknown_obs),
      external_site: site, url: "#{site.base_url}1"
    )
    assert(link.manual?,
           "New links default to manual (user-added cross-links)")
  end

  def test_only_one_import_per_target
    obs = observations(:imported_inat_obs) # already has an iNat import link
    site = external_sites(:mycoportal)
    link = ExternalLink.new(
      user: mary, observation: obs, external_site: site,
      relationship: :import, url: "#{site.base_url}999"
    )
    assert_not(link.valid?, "A second import link per target is invalid")
    assert_not_empty(link.errors[:relationship])
  end

  def test_manual_link_can_be_upgraded_to_import
    link = external_links(:coprinus_comatus_obs_inaturalist_link)
    assert(link.manual?, "Fixture link starts as manual")
    link.update!(relationship: :import, external_id: "234723")
    assert(link.reload.import?, "Link should upgrade to import in place")
  end
end
