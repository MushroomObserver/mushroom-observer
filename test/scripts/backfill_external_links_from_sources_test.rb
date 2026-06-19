# frozen_string_literal: true

require("test_helper")

# Exercises script/backfill_external_links_from_sources.rb (#4299 phase-1
# data migration) by loading the script with APPLY=1 against fixtures.
class BackfillExternalLinksFromSourcesTest < UnitTestCase
  SCRIPT = Rails.root.join("script/backfill_external_links_from_sources.rb")

  def test_upgrades_cross_reference_to_import
    link = external_links(:coprinus_comatus_obs_inaturalist_link)
    link.observation.update_columns(source_id: Source.inaturalist.id,
                                    external_id: "234723")
    assert(link.cross_reference?, "Link should start as cross_reference")

    run_backfill

    assert(link.reload.import?, "Backfill should upgrade the link in place")
    assert_equal("234723", link.external_id)
  end

  def test_creates_import_link_for_obs_without_link
    obs = observations(:minimal_unknown_obs)
    obs.update_columns(source_id: Source.inaturalist.id, external_id: "555")
    assert_nil(obs.import_link, "Obs should start with no import link")

    run_backfill

    link = obs.reload.import_link
    assert_not_nil(link, "Backfill should create an import link")
    assert_equal("Observation", link.target_type)
    assert_equal(ExternalSite.inaturalist, link.external_site)
    assert_equal("555", link.external_id)
    assert_nil(link.url, "Import links store no url (derived)")
    assert_equal("#{ExternalSite.inaturalist.base_url}555", link.link_url)
  end

  def test_creates_import_link_for_image_with_external_id
    img = images(:in_situ_image)
    img.update_columns(source_id: Source.inaturalist.id, external_id: "p99")

    run_backfill

    link = img.reload.import_link
    assert_not_nil(link, "Backfill should create an image import link")
    assert_equal("Image", link.target_type)
    assert_equal("p99", link.external_id)
  end

  def test_skips_image_without_external_id
    img = images(:in_situ_image)
    img.update_columns(source_id: Source.inaturalist.id, external_id: nil)

    run_backfill

    assert_nil(img.reload.import_link,
               "No import link without an external_id (the photo id)")
  end

  private

  def run_backfill
    ENV["APPLY"] = "1"
    capture_io { load(SCRIPT.to_s) }
  ensure
    ENV.delete("APPLY")
  end
end
