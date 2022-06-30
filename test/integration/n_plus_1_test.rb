# frozen_string_literal: true

require("test_helper")

# Discover potential n+1 issues by running some requests with bullet gem
class NPlusOneTest < IntegrationTestCase
  include BulletHelper

  def test_api2
    get("/api2/observations?detail=high&format=xml")
    get("/api2/locations?detail=high&format=xml")
    get("/api2/names?detail=high&format=xml")
    get("/api2/images?detail=high&format=xml")
  end

  def test_indexes
    login
    get("/articles")
    get("/comment/list_comments")
    get("/herbaria?flavor=all")
    get("/location/list_locations")
    get("/name/list_names")
    get("/image/list_images")
    get("/observations/list_observations")
    get("/activity_logs/index")
    get("/project/list_projects")
    get("/publications")
    get("/sequence/list_sequences")
    get("/species_list/list_species_lists")
  end

  def test_download_observations
    login
    get("/observations/download_observations")
  end

  def test_site_stats
    login
    get("/info/site_stats")
  end
end
