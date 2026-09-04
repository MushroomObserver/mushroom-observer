# frozen_string_literal: true

require("test_helper")

class ExternalLinkTest < UnitTestCase
  def test_inaturalist_id
    assert_equal(
      "234723",
      external_links(:coprinus_comatus_obs_inaturalist_link).inaturalist_id
    )
    assert_equal(
      "12345",
      external_links(:imported_inat_obs_inat_link).inaturalist_id
    )
    # non-iNat site -- nil, regardless of what its external_id contains
    assert_nil(
      external_links(:coprinus_comatus_obs_mycoportal_link).inaturalist_id
    )
  end

  def test_mycoportal_id
    assert_equal(
      "1950183",
      external_links(:coprinus_comatus_obs_mycoportal_link).mycoportal_id
    )
    # non-MyCoPortal site -- nil, regardless of what its external_id contains
    assert_nil(
      external_links(:coprinus_comatus_obs_inaturalist_link).mycoportal_id
    )
  end

  def test_site_record_id
    assert_equal(
      "234723",
      external_links(:coprinus_comatus_obs_inaturalist_link).site_record_id
    )
    assert_equal(
      "1950183",
      external_links(:coprinus_comatus_obs_mycoportal_link).site_record_id
    )

    # A site with neither accessor -- nil, not an error.
    other_site = ExternalSite.new(name: "GenBank",
                                  base_url: "https://genbank.example/")
    link = ExternalLink.new(external_site: other_site, external_id: "123")
    assert_nil(link.site_record_id)
  end

  def test_resolve_submitted_external_id_from_url
    inat = external_sites(:inaturalist)
    obs = observations(:detailed_unknown_obs)

    # A pasted url resolves to the site's bare id before save.
    link = ExternalLink.create!(
      user: users(:rolf), target: obs, external_site: inat,
      external_id: "#{inat.base_url}123"
    )
    assert_equal("123", link.external_id)

    # A bare id passes through unchanged.
    link.update!(external_id: "456")
    assert_equal("456", link.external_id)
  end

  def test_resolve_submitted_external_id_rejects_unrecognized_url
    inat = external_sites(:inaturalist)
    obs = observations(:detailed_unknown_obs)

    link = ExternalLink.new(
      user: users(:rolf), target: obs, external_site: inat,
      external_id: "https://example.com/not-inaturalist"
    )
    assert_not(link.valid?)
    assert_not_empty(link.errors[:external_id])
  end

  def test_resolve_submitted_external_id_rejects_self_referential_url
    mycoportal = external_sites(:mycoportal)
    obs = observations(:detailed_unknown_obs)

    link = ExternalLink.new(
      user: users(:rolf), target: obs, external_site: mycoportal,
      external_id: "http://mushroomobserver.org/#{obs.id}"
    )
    assert_not(link.valid?)
    assert_not_empty(link.errors[:external_id])
  end

  def test_resolve_submitted_external_id_rejects_mycoportal_list_search_url
    mycoportal = external_sites(:mycoportal)
    obs = observations(:detailed_unknown_obs)

    link = ExternalLink.new(
      user: users(:rolf), target: obs, external_site: mycoportal,
      external_id: "https://mycoportal.org/portal/collections/list.php" \
                   "?catnum=AN+12345"
    )
    assert_not(link.valid?)
    assert_not_empty(link.errors[:external_id])
  end

  def test_relationship_date
    link = external_links(:imported_inat_obs_inat_link)
    obs = link.observation

    # no external_created_on -> falls back to created_at
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

    link = ExternalLink.create!(
      user: mary,
      observation: Observation.first,
      external_site: site,
      external_id: "plus_id"
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
    assert_not_empty(link.errors[:external_id],
                     "ExternalLink should require an external_id")
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
      external_id: "another_id"
    )
    assert_empty(link2.errors,
                 "A second link for the same observation+site should be valid")
  end

  def test_relationship_defaults_to_manual
    site = external_sites(:mycoportal)
    link = ExternalLink.create!(
      user: mary, observation: observations(:minimal_unknown_obs),
      external_site: site, external_id: "1"
    )
    assert(link.manual?,
           "New links default to manual (user-added cross-links)")
  end

  def test_only_one_import_per_target
    obs = observations(:imported_inat_obs) # already has an iNat import link
    site = external_sites(:mycoportal)
    link = ExternalLink.new(
      user: mary, observation: obs, external_site: site,
      relationship: :import, external_id: "999"
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

  def test_external_id_length_validation
    link = external_links(:coprinus_comatus_obs_mycoportal_link)
    link.external_id = "9" * 65
    assert_not(link.valid?, "external_id over 64 chars should be invalid")
    assert(link.errors[:external_id].any?)

    link.external_id = "9" * 64
    assert(link.valid?, "external_id of 64 chars should be valid")
  end
end
