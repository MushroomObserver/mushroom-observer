# frozen_string_literal: true

require("test_helper")

# Discover potential n+1 issues by running some requests with bullet gem
class NPlusOneTest < CapybaraIntegrationTestCase
  include BulletHelper

  def test_api2
    visit("/api2/observations?detail=high&format=xml")
    visit("/api2/locations?detail=high&format=xml")
    visit("/api2/names?detail=high&format=xml")
    visit("/api2/images?detail=high&format=xml")
  end

  def test_indexes
    login_user
    visit("/articles")
    visit("/comment/list_comments")
    visit("/herbaria?flavor=all")
    visit("/location/list_locations")
    visit("/name/list_names")
    visit("/image/list_images")
    visit("/observations/index")
    visit("/activity_logs/index")
    visit("/project/list_projects")
    visit("/publications")
    visit("/sequences?flavor=all")
    visit("/species_list/list_species_lists")
  end

  def test_download_observations
    login_user
    visit("/observations/download")
  end

  def test_site_stats
    login_user
    visit("/info/site_stats")
  end
end
