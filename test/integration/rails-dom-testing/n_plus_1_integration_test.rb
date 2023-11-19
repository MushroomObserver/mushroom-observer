# frozen_string_literal: true

require("test_helper")

# Discover potential n+1 issues by running some requests with bullet gem
class NPlusOneIntegrationTest < IntegrationTestCase
  # include BulletHelper

  def test_api2
    get("/api2/observations?detail=high&format=xml")
    get("/api2/locations?detail=high&format=xml")
    get("/api2/names?detail=high&format=xml")
    get("/api2/images?detail=high&format=xml")
  end

  def test_indexes
    login
    get("/articles")
    get("/comments")
    get("/herbaria?flavor=all")
    get("/locations")
    get("/names")
    get("/images")
    get("/observations")
    get("/activity_logs")
    get("/projects")
    get("/publications")
    get("/sequences?flavor=all")
    get("/species_lists")
  end

  def test_download_observations
    login
    get("/observations/downloads/new")
  end

  def test_site_stats
    login
    get("/info/site_stats")
  end
end
